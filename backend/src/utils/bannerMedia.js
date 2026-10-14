// Which uploaded banner files (images / videos under "banners/") are still
// used by the app and website banners. Anything else in that folder can be
// deleted from storage. YouTube and other outside links are never ours.

const BANNER_FOLDER = 'banners';

// Storage path ("banners/<file>") of one of our uploaded files, or null.
//   https://storage.googleapis.com/<bucket>/banners/x.mp4
//   https://firebasestorage.googleapis.com/v0/b/<bucket>/o/banners%2Fx.mp4?alt=media
//   http(s)://<api>/uploads/banners/x.webp  (local storage)
function bannerStoragePath(url) {
  const text = String(url ?? '').trim();
  if (!text) return null;
  let storagePath = null;
  let match = /^https?:\/\/storage\.googleapis\.com\/[^/]+\/([^?#]+)/i.exec(text);
  if (match) storagePath = match[1];
  if (!storagePath) {
    match = /^https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/([^?#]+)/i.exec(text);
    if (match) storagePath = match[1];
  }
  if (!storagePath) {
    match = /(?:^|\/)uploads\/([^?#]+)/i.exec(text);
    if (match) storagePath = match[1];
  }
  if (!storagePath) return null;
  try {
    storagePath = decodeURIComponent(storagePath);
  } catch {
    return null;
  }
  const parts = storagePath.split('/');
  if (parts[0] !== BANNER_FOLDER || parts.length < 2 || parts.some((part) => !part || part === '.' || part === '..')) {
    return null;
  }
  return storagePath;
}

// Media links a banner uses. An image banner has no video.
function bannerMediaUrls(banner = {}) {
  const urls = [banner.imageUrl];
  if ((banner.mediaType || 'image') === 'video_upload') urls.push(banner.videoUrl);
  return urls;
}

// Storage paths of every uploaded file used by the settings' banners.
function usedBannerPaths(settings = {}) {
  const paths = new Set();
  for (const banner of [...(settings.heroBanners || []), ...(settings.promoBanners || [])]) {
    for (const url of bannerMediaUrls(banner)) {
      const storagePath = bannerStoragePath(url);
      if (storagePath) paths.add(storagePath);
    }
  }
  return paths;
}

// Files used before a save but not after it (removed / replaced media).
function replacedBannerPaths(before = {}, after = {}) {
  const stillUsed = usedBannerPaths(after);
  return [...usedBannerPaths(before)].filter((storagePath) => !stillUsed.has(storagePath));
}

// Image banners keep no stale video link.
function withoutUnusedVideo(banner) {
  if (!banner || (banner.mediaType || 'image') !== 'image' || !banner.videoUrl) return banner;
  return { ...banner, videoUrl: '' };
}

module.exports = {
  BANNER_FOLDER,
  bannerStoragePath,
  usedBannerPaths,
  replacedBannerPaths,
  withoutUnusedVideo,
};
