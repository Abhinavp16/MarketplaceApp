const multer = require('multer');
const { deleteFile } = require('./storage');

// All file uploads use memory storage — Firebase Storage handles persistence
const memoryStorage = multer.memoryStorage();

const uploadProductImages = multer({
  storage: memoryStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'), false);
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
      cb(new Error('Only JPEG and PNG images are allowed'), false);
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
  deleteImage,
};
