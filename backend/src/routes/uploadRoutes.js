const express = require('express');
const router = express.Router();
const multer = require('multer');
const uploadController = require('../controllers/uploadController');
const { protect, authorize } = require('../middlewares/auth');

// Configure multer for memory storage (files stored in buffer)
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed.'), false);
    }
  },
});

// Single image upload - for brand logos, etc.
// POST /api/v1/upload/image?folder=brands
router.post(
  '/image',
  protect,
  authorize('admin'),
  upload.single('image'),
  uploadController.uploadImage
);

// Multiple images upload - for product images
// POST /api/v1/upload/images?folder=products
router.post(
  '/images',
  protect,
  authorize('admin'),
  upload.array('images', 10), // Max 10 images
  uploadController.uploadMultipleImages
);

// Single video upload - for hero banners (MP4/WebM/MOV, 25MB)
// POST /api/v1/upload/video?folder=banners
const videoUpload = multer({
  storage,
  limits: {
    fileSize: 25 * 1024 * 1024, // 25MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['video/mp4', 'video/webm', 'video/quicktime'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only MP4, WebM, and MOV are allowed.'), false);
    }
  },
});

router.post(
  '/video',
  protect,
  authorize('admin'),
  videoUpload.single('video'),
  uploadController.uploadVideo
);

// Delete image
// DELETE /api/v1/upload/image
router.delete(
  '/image',
  protect,
  authorize('admin'),
  uploadController.deleteImage
);

module.exports = router;
