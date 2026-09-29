const express = require('express');
const router = express.Router();
const {
  getCategories,
  getCategory,
  createCategory,
  updateCategory,
  deleteCategory,
  generateMissingHindiNames,
  reorderCategories,
  getCategoriesWithSubcategories,
  getSubcategories,
  reorderSubcategories,
} = require('../controllers/categoryController');
const { protect, optionalAuth, authorize } = require('../middlewares/auth');

// Public routes
router.get('/', optionalAuth, getCategories);

// Specific routes (must come before /:id)
router.get('/with-subcategories', optionalAuth, getCategoriesWithSubcategories);
router.get('/:id/subcategories', optionalAuth, getSubcategories);

// Admin routes
router.post('/hindi-names/generate-missing', protect, authorize('admin'), generateMissingHindiNames);
router.post('/reorder', protect, authorize('admin'), reorderCategories);
router.post('/reorder-subcategories', protect, authorize('admin'), reorderSubcategories);
router.post('/', protect, authorize('admin'), createCategory);
router.put('/:id', protect, authorize('admin'), updateCategory);
router.delete('/:id', protect, authorize('admin'), deleteCategory);

// Generic ID route (must come last)
router.get('/:id', optionalAuth, getCategory);

module.exports = router;
