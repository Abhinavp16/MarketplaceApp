const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const { getStorage } = require('./firebase');

const LOCAL_STORAGE_DRIVER = 'local';
const FIREBASE_STORAGE_DRIVER = 'firebase';
const PUBLIC_VISIBILITY = 'public';
const PRIVATE_VISIBILITY = 'private';

function getStorageDriver() {
  const configured = (process.env.FILE_STORAGE_DRIVER || 'auto').trim().toLowerCase();
  const bucket = getStorage();

  if (configured === FIREBASE_STORAGE_DRIVER) {
    return bucket ? FIREBASE_STORAGE_DRIVER : LOCAL_STORAGE_DRIVER;
  }

  if (configured === LOCAL_STORAGE_DRIVER) {
    return LOCAL_STORAGE_DRIVER;
  }

  return bucket ? FIREBASE_STORAGE_DRIVER : LOCAL_STORAGE_DRIVER;
}

function getUploadsRoot() {
  return path.resolve(
    process.cwd(),
    process.env.LOCAL_UPLOADS_DIR || 'uploads'
  );
}

// Private (non-public) media for the local driver lives OUTSIDE the statically
// served uploads directory and is only reachable through short-lived signed
// URLs (GET /api/v1/media/private), mirroring Firebase signed URLs.
function getPrivateRoot() {
  return path.resolve(
    process.cwd(),
    process.env.LOCAL_PRIVATE_DIR || '.data/private-media'
  );
}

function resolveLocalPath(relativePath, visibility) {
  const root = visibility === PRIVATE_VISIBILITY ? getPrivateRoot() : getUploadsRoot();
  const absolute = path.resolve(root, relativePath);
  if (absolute !== root && !absolute.startsWith(root + path.sep)) {
    throw new Error('Invalid storage path.');
  }
  return absolute;
}

const isPrivateKey = (relativePath) => relativePath.startsWith('private/');

function signPrivateRead(relativePath, expiresAtMs) {
  return crypto
    .createHmac('sha256', String(process.env.JWT_SECRET || ''))
    .update(`${relativePath}:${expiresAtMs}`)
    .digest('hex');
}

function verifyPrivateRead(relativePath, expiresAtMs, signature) {
  const expires = Number(expiresAtMs);
  if (!relativePath || !Number.isFinite(expires) || expires < Date.now()) return false;
  if (!/^[0-9a-f]{64}$/i.test(String(signature || ''))) return false;
  const expected = Buffer.from(signPrivateRead(relativePath, expires), 'hex');
  const provided = Buffer.from(String(signature), 'hex');
  return expected.length === provided.length && crypto.timingSafeEqual(expected, provided);
}

function sanitizeSegment(segment) {
  return String(segment || '')
    .replace(/\\/g, '/')
    .split('/')
    .map((part) => part.trim())
    .filter(Boolean)
    .join('/');
}

function getPublicBaseUrl() {
  const configured = (process.env.PUBLIC_BASE_URL || '').trim().replace(/\/+$/, '');
  if (configured) return configured;
  return `http://localhost:${process.env.PORT || (String(process.env.DEMO_MODE).toLowerCase() === 'true' ? 5050 : 5000)}`;
}

function normalizeVisibility(visibility) {
  if (visibility === PUBLIC_VISIBILITY || visibility === PRIVATE_VISIBILITY) {
    return visibility;
  }

  throw new Error(`Unsupported storage visibility: ${visibility}`);
}

function resolveSignedReadTtl(expiresSeconds) {
  const configuredDefault = Number(process.env.PRIVATE_MEDIA_SIGNED_URL_TTL_SECONDS || 900);
  const requested = Number(expiresSeconds ?? configuredDefault);

  if (!Number.isFinite(requested) || requested <= 0) {
    throw new Error('Signed media URL expiry must be a positive number of seconds.');
  }

  // Limit accidental long-lived document links even if an endpoint passes a bad value.
  return Math.min(Math.floor(requested), 24 * 60 * 60);
}

async function saveBuffer({
  buffer,
  folder = 'uploads',
  filename,
  contentType = 'application/octet-stream',
  metadata = {},
  visibility = PUBLIC_VISIBILITY,
}) {
  const driver = getStorageDriver();
  const normalizedVisibility = normalizeVisibility(visibility);
  const normalizedFolder = sanitizeSegment(folder);
  const normalizedFilename = sanitizeSegment(filename);
  const relativePath = sanitizeSegment(
    normalizedFolder ? `${normalizedFolder}/${normalizedFilename}` : normalizedFilename
  );

  if (!relativePath) {
    throw new Error('A storage filename is required.');
  }

  if (driver === FIREBASE_STORAGE_DRIVER) {
    const bucket = getStorage();
    if (!bucket) {
      throw new Error('Firebase Storage is not initialized.');
    }

    const fileUpload = bucket.file(relativePath);

    await new Promise((resolve, reject) => {
      const stream = fileUpload.createWriteStream({
        metadata: {
          contentType,
          metadata,
        },
      });
      stream.on('error', reject);
      stream.on('finish', resolve);
      stream.end(buffer);
    });

    if (normalizedVisibility === PUBLIC_VISIBILITY) {
      await fileUpload.makePublic();
    }

    return {
      driver,
      visibility: normalizedVisibility,
      publicId: relativePath,
      url: normalizedVisibility === PUBLIC_VISIBILITY
        ? `https://storage.googleapis.com/${bucket.name}/${relativePath}`
        : null,
    };
  }

  if (normalizedVisibility === PRIVATE_VISIBILITY) {
    const privatePath = resolveLocalPath(relativePath, PRIVATE_VISIBILITY);
    await fs.mkdir(path.dirname(privatePath), { recursive: true });
    await fs.writeFile(privatePath, buffer);
    return {
      driver,
      visibility: normalizedVisibility,
      publicId: relativePath,
      url: null,
    };
  }

  const absolutePath = resolveLocalPath(relativePath, PUBLIC_VISIBILITY);
  await fs.mkdir(path.dirname(absolutePath), { recursive: true });
  await fs.writeFile(absolutePath, buffer);

  return {
    driver,
    visibility: normalizedVisibility,
    publicId: relativePath,
    url: `${getPublicBaseUrl()}/uploads/${relativePath.replace(/\\/g, '/')}`,
  };
}

async function getSignedReadUrl(publicId, expiresSeconds) {
  const relativePath = sanitizeSegment(publicId);
  if (!relativePath) return null;

  if (getStorageDriver() !== FIREBASE_STORAGE_DRIVER) {
    // Local driver: HMAC-signed, expiring URL served by GET /api/v1/media/private.
    try {
      await fs.access(resolveLocalPath(relativePath, PRIVATE_VISIBILITY));
    } catch (_) {
      return null;
    }
    const expiresAtMs = Date.now() + (resolveSignedReadTtl(expiresSeconds) * 1000);
    const signature = signPrivateRead(relativePath, expiresAtMs);
    return `${getPublicBaseUrl()}/api/v1/media/private?key=${encodeURIComponent(relativePath)}&expires=${expiresAtMs}&sig=${signature}`;
  }

  const bucket = getStorage();
  if (!bucket) {
    throw new Error('Firebase Storage is not initialized.');
  }

  const file = bucket.file(relativePath);
  const [exists] = await file.exists();
  if (!exists) return null;

  const expiresAt = Date.now() + (resolveSignedReadTtl(expiresSeconds) * 1000);
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: expiresAt,
    version: 'v4',
  });

  return url;
}

async function deleteFile(publicId) {
  if (!publicId) return false;

  const driver = getStorageDriver();
  const relativePath = sanitizeSegment(publicId);

  if (driver === FIREBASE_STORAGE_DRIVER) {
    const bucket = getStorage();
    if (!bucket) return false;

    const file = bucket.file(relativePath);
    const [exists] = await file.exists();
    if (!exists) return false;
    await file.delete();
    return true;
  }

  const absolutePath = resolveLocalPath(relativePath, isPrivateKey(relativePath) ? PRIVATE_VISIBILITY : PUBLIC_VISIBILITY);
  try {
    await fs.unlink(absolutePath);
    return true;
  } catch (error) {
    if (error.code === 'ENOENT') return false;
    throw error;
  }
}

async function deleteDirectory(publicIdPrefix) {
  if (!publicIdPrefix) return false;

  const relativePath = sanitizeSegment(publicIdPrefix);
  if (!relativePath) return false;

  if (getStorageDriver() === FIREBASE_STORAGE_DRIVER) {
    const bucket = getStorage();
    if (!bucket) return false;
    await bucket.deleteFiles({ prefix: `${relativePath}/` });
    return true;
  }

  const absolutePath = resolveLocalPath(relativePath, isPrivateKey(relativePath) ? PRIVATE_VISIBILITY : PUBLIC_VISIBILITY);
  try {
    await fs.rm(absolutePath, { recursive: true, force: true });
    return true;
  } catch (error) {
    if (error.code === 'ENOENT') return false;
    throw error;
  }
}

module.exports = {
  saveBuffer,
  getSignedReadUrl,
  deleteFile,
  deleteDirectory,
  getStorageDriver,
  getUploadsRoot,
  getPrivateRoot,
  resolveLocalPath,
  verifyPrivateRead,
};
