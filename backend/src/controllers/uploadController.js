const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const { saveBuffer, deleteFile, getStorageDriver } = require('../config/storage');

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

const ALLOWED_VIDEO_MIME_TYPES = ['video/mp4', 'video/webm', 'video/quicktime'];
const MAX_VIDEO_FILE_SIZE = 25 * 1024 * 1024; // 25MB
const VIDEO_EXTENSION_BY_MIME = {
  'video/mp4': 'mp4',
  'video/webm': 'webm',
  'video/quicktime': 'mov',
};

// Convert image buffer to WebP using sharp
async function convertToWebP(buffer, quality = 80) {
  return sharp(buffer)
    .webp({ quality })
    .toBuffer();
}

exports.uploadImage = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }

    const file = req.file;

    // Validate file type
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid file type. Allowed: JPEG, PNG, GIF, WebP',
      });
    }

    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
      return res.status(400).json({
        success: false,
        message: 'File too large. Maximum size: 5MB',
      });
    }

    // Convert to WebP
    const webpBuffer = await convertToWebP(file.buffer);

    // Generate unique filename with .webp extension
    const folder = String(req.query.folder || 'uploads');
    const filename = `${uuidv4()}.webp`;
    const saved = await saveBuffer({
      buffer: webpBuffer,
      folder,
      filename,
      contentType: 'image/webp',
      metadata: {
        originalName: file.originalname,
        uploadedBy: req.user?.id || 'anonymous',
        uploadedAt: new Date().toISOString(),
        originalSize: file.size,
        convertedSize: webpBuffer.length,
      },
    });

    res.json({
      success: true,
      data: {
        url: saved.url,
        publicId: saved.publicId,
        storageDriver: saved.driver,
        originalName: file.originalname,
        originalSize: file.size,
        convertedSize: webpBuffer.length,
        mimeType: 'image/webp',
        savings: Math.round((1 - webpBuffer.length / file.size) * 100) + '%',
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.uploadMultipleImages = async (req, res, next) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No files uploaded',
      });
    }

    const uploadPromises = req.files.map(async (file, index) => {
      // Validate file type
      if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
        throw new Error(`Invalid file type for ${file.originalname}`);
      }

      // Validate file size
      if (file.size > MAX_FILE_SIZE) {
        throw new Error(`File ${file.originalname} is too large`);
      }

      // Convert to WebP
      const webpBuffer = await convertToWebP(file.buffer);

      // Generate unique filename with .webp extension
      const saved = await saveBuffer({
        buffer: webpBuffer,
        folder: String(req.query.folder || 'uploads'),
        filename: `${uuidv4()}.webp`,
        contentType: 'image/webp',
        metadata: {
          originalName: file.originalname,
          uploadedBy: req.user?.id || 'anonymous',
          uploadedAt: new Date().toISOString(),
          originalSize: file.size,
          convertedSize: webpBuffer.length,
        },
      });

      return {
        url: saved.url,
        publicId: saved.publicId,
        storageDriver: saved.driver,
        originalName: file.originalname,
        originalSize: file.size,
        convertedSize: webpBuffer.length,
        mimeType: 'image/webp',
        savings: Math.round((1 - webpBuffer.length / file.size) * 100) + '%',
        isPrimary: index === 0,
        order: index,
      };
    });

    const uploadedFiles = await Promise.all(uploadPromises);

    res.json({
      success: true,
      data: uploadedFiles,
    });
  } catch (error) {
    next(error);
  }
};

exports.uploadVideo = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }

    const file = req.file;

    // Validate file type
    if (!ALLOWED_VIDEO_MIME_TYPES.includes(file.mimetype)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid file type. Allowed: MP4, WebM, MOV',
      });
    }

    // Validate file size
    if (file.size > MAX_VIDEO_FILE_SIZE) {
      return res.status(400).json({
        success: false,
        message: 'File too large. Maximum size: 25MB',
      });
    }

    // Store original buffer (no transcoding)
    const extension = VIDEO_EXTENSION_BY_MIME[file.mimetype] || 'mp4';
    const folder = String(req.query.folder || 'uploads');
    const filename = `${uuidv4()}.${extension}`;
    const saved = await saveBuffer({
      buffer: file.buffer,
      folder,
      filename,
      contentType: file.mimetype,
      metadata: {
        originalName: file.originalname,
        uploadedBy: req.user?.id || 'anonymous',
        uploadedAt: new Date().toISOString(),
        originalSize: file.size,
      },
    });

    res.json({
      success: true,
      data: {
        url: saved.url,
        publicId: saved.publicId,
        storageDriver: saved.driver,
        originalName: file.originalname,
        originalSize: file.size,
        mimeType: file.mimetype,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.deleteImage = async (req, res, next) => {  try {
    const { publicId } = req.body;

    if (!publicId) {
      return res.status(400).json({
        success: false,
        message: 'publicId is required',
      });
    }

    const deleted = await deleteFile(publicId);
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'File not found',
      });
    }

    res.json({
      success: true,
      message: 'File deleted successfully',
      data: {
        storageDriver: getStorageDriver(),
      },
    });
  } catch (error) {
    next(error);
  }
};
