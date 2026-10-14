const multer = require('multer');
const { deleteFile } = require('./storage');
const { BadRequestError } = require('../utils/errors');

// All file uploads use memory storage — Firebase Storage handles persistence
const memoryStorage = multer.memoryStorage();

const uploadProductImages = multer({
  storage: memoryStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new BadRequestError('Only JPEG, PNG, and WebP images are allowed', 'INVALID_FILE_TYPE'), false);
    }
  },
});

const uploadAvatar = multer({
  storage: memoryStorage,
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (['image/jpeg', 'image/png'].includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new BadRequestError('Only JPEG and PNG images are allowed', 'INVALID_FILE_TYPE'), false);
    }
  },
});

// Catalog import sheets (.xlsx / .csv, 5 MB). The service checks the content too.
const CATALOG_FILE_EXTENSIONS = /\.(xlsx|csv)$/i;
const CATALOG_FILE_TYPES = new Set([
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/csv',
  'application/csv',
  'application/vnd.ms-excel', // browsers (and Windows) often label .csv this way
  'application/octet-stream',
  'text/plain',
]);
const uploadCatalogFile = multer({
  storage: memoryStorage,
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
  fileFilter: (req, file, cb) => {
    if (CATALOG_FILE_EXTENSIONS.test(file.originalname || '') && CATALOG_FILE_TYPES.has(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new BadRequestError('Only Excel (.xlsx) and CSV (.csv) files are allowed', 'INVALID_FILE_TYPE'), false);
    }
  },
});

const deleteImage = async (publicId) => {
  try {
    return await deleteFile(publicId);
  } catch (error) {
    console.error('Error deleting image from storage:', error);
    return false;
  }
};

module.exports = {
  uploadProductImages,
  uploadAvatar,
  uploadCatalogFile,
  deleteImage,
};
