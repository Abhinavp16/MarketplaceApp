const express = require('express');
const router = express.Router();
const { protect, adminOnly } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const { uploadProductImages } = require('../config/cloudinary');

const adminProductController = require('../controllers/admin/productController');

// Middleware that conditionally applies multer only for multipart/form-data requests
const optionalUpload = (multerMiddleware) => {
  return (req, res, next) => {
    const contentType = req.headers['content-type'] || '';
    if (contentType.includes('multipart/form-data')) {
      return multerMiddleware(req, res, next);
    }
    next();
  };
};
const adminNegotiationController = require('../controllers/admin/negotiationController');
const adminOrderController = require('../controllers/admin/orderController');
const adminPaymentController = require('../controllers/admin/paymentController');
const adminAnalyticsController = require('../controllers/admin/analyticsController');
const adminSettingsController = require('../controllers/admin/settingsController');
const websiteSettingsController = require('../controllers/admin/websiteSettingsController');
const websiteCatalogController = require('../controllers/admin/websiteCatalogController');
const adminCustomerController = require('../controllers/admin/customerController');
const adminOfferController = require('../controllers/admin/offerController');
const adminAffiliateController = require('../controllers/admin/affiliateCodeController');
const adminReviewController = require('../controllers/admin/reviewController');
const adminAccountDeletionController = require('../controllers/admin/accountDeletionController');
const adminStaffController = require('../controllers/admin/staffController');
const adminNotificationController = require('../controllers/admin/notificationController');

const { adminValidation } = require('../validations');

router.use(protect);
router.use(adminOnly);

// Staff accounts
router.get('/staff', adminStaffController.getStaff);
router.post('/staff', validate(adminValidation.createStaff), adminStaffController.createStaff);
router.put('/staff/:id/password', validate(adminValidation.resetStaffPassword), adminStaffController.resetStaffPassword);
router.put('/staff/:id/status', validate(adminValidation.updateStaffStatus), adminStaffController.updateStaffStatus);

// Products
router.get('/products/price-snapshot.xlsx', adminProductController.getPriceSnapshot);
router.get('/products', adminProductController.getProducts);
router.get('/price-changes', adminProductController.getPriceChanges);
router.get('/price-change-history', adminProductController.getPriceChangeHistory);
router.post(
  '/products',
  optionalUpload(uploadProductImages.array('images', 10)),
  validate(adminValidation.createProduct),
  adminProductController.createProduct
);
router.get('/products/:id', adminProductController.getProductById);
router.put('/products/:id/price-change', validate(adminValidation.priceChange), adminProductController.changeProductPrice);
router.put(
  '/products/:id',
  optionalUpload(uploadProductImages.array('images', 10)),
  validate(adminValidation.updateProduct),
  adminProductController.updateProduct
);
router.delete('/products/:id', adminProductController.deleteProduct);
router.put('/products/:id/stock', validate(adminValidation.updateStock), adminProductController.updateStock);
router.get('/products/:id/stock-logs', adminProductController.getStockLogs);
router.delete('/products/:id/images/:imageId', adminProductController.deleteProductImage);
router.post('/products/hindi-names/generate-missing', adminProductController.generateMissingHindiNames);
router.post('/hindi-name/suggest', adminProductController.suggestHindiName);

// Negotiations
router.get('/negotiations', adminNegotiationController.getNegotiations);
router.get('/negotiations/:id', adminNegotiationController.getNegotiationById);
router.post('/negotiations/:id/message', validate(adminValidation.negotiationMessage), adminNegotiationController.sendMessage);
router.put('/negotiations/:id/accept', validate(adminValidation.acceptNegotiation), adminNegotiationController.acceptNegotiation);
router.put('/negotiations/:id/reject', validate(adminValidation.rejectNegotiation), adminNegotiationController.rejectNegotiation);
router.put('/negotiations/:id/counter', validate(adminValidation.counterNegotiation), adminNegotiationController.counterNegotiation);

// Orders
router.get('/orders', adminOrderController.getOrders);
router.get('/orders/:id', adminOrderController.getOrderById);
router.delete('/orders/:id', adminOrderController.deleteOrder);
router.put('/orders/:id/accept', adminOrderController.acceptOrder);
router.put('/orders/:id/reject', validate(adminValidation.rejectOrder), adminOrderController.rejectOrder);
router.put('/orders/:id/mark-payment-complete', adminOrderController.markPaymentCompleted);
router.put('/orders/:id/status', validate(adminValidation.updateOrderStatus), adminOrderController.updateOrderStatus);
router.put('/orders/:id/ship', validate(adminValidation.shipOrder), adminOrderController.shipOrder);

// Payments
router.get('/payments', adminPaymentController.getPayments);
router.put('/payments/:id/verify', adminPaymentController.verifyPayment);
router.put('/payments/:id/reject', validate(adminValidation.rejectPayment), adminPaymentController.rejectPayment);

// Customers
router.get('/customers', adminCustomerController.getCustomers);
router.get('/customers/:id', adminCustomerController.getCustomerById);
router.put('/customers/:id/upgrade', adminCustomerController.upgradeCustomer);
router.put('/customers/:id/category-access', validate(adminValidation.updateWholesalerCategoryAccess), adminCustomerController.updateWholesalerCategoryAccess);
router.get('/wholesaler-locations', adminCustomerController.getWholesalerLocations);
router.post('/customers/notifications', validate(adminValidation.sendNotification), adminCustomerController.sendNotification);

// Account deletion requests
router.get('/account-deletion-requests', adminAccountDeletionController.getRequests);
router.put('/account-deletion-requests/:id', validate(adminValidation.updateAccountDeletionRequest), adminAccountDeletionController.updateRequestStatus);
router.post('/account-deletion-requests/:id/complete', validate(adminValidation.completeAccountDeletionRequest), adminAccountDeletionController.completeRequest);

// Analytics
router.get('/analytics/dashboard', adminAnalyticsController.getDashboardStats);
router.get('/analytics/products', adminAnalyticsController.getProductAnalytics);
router.get('/analytics/sales', adminAnalyticsController.getSalesAnalytics);
router.get('/analytics/demand', adminAnalyticsController.getDemandInsights);
router.get('/analytics/potential-customers', adminAnalyticsController.getPotentialCustomers);

// Settings
router.get('/settings', adminSettingsController.getSettings);
router.put(
  '/settings',
  validate(adminValidation.updateSettings, 'body', { stripUnknown: false }),
  adminSettingsController.updateSettings
);
router.get('/website-settings', websiteSettingsController.getWebsiteSettings);
router.put('/website-settings', validate(adminValidation.updateWebsiteSettings), websiteSettingsController.updateWebsiteSettings);
router.get('/website-catalog/brands', websiteCatalogController.getBrands);
router.get('/website-catalog/categories', websiteCatalogController.getCategories);
router.get('/website-catalog/products', websiteCatalogController.getProducts);
router.patch('/website-catalog/visibility', websiteCatalogController.updateVisibility);

// Offers
router.get('/offers', adminOfferController.getOffers);
router.post('/offers', validate(adminValidation.createOffer), adminOfferController.createOffer);
router.get('/offers/:id', adminOfferController.getOfferById);
router.put('/offers/:id', validate(adminValidation.updateOffer), adminOfferController.updateOffer);
router.delete('/offers/:id', adminOfferController.deleteOffer);
router.patch('/offers/:id/toggle', adminOfferController.toggleOfferStatus);

// Affiliate Codes
router.get('/affiliate-codes', adminAffiliateController.getAffiliateCodes);
router.post('/affiliate-codes', validate(adminValidation.createAffiliateCode), adminAffiliateController.createAffiliateCode);
router.get('/affiliate-codes/:id', adminAffiliateController.getAffiliateCodeById);
router.put('/affiliate-codes/:id', validate(adminValidation.updateAffiliateCode), adminAffiliateController.updateAffiliateCode);
router.delete('/affiliate-codes/:id', adminAffiliateController.deleteAffiliateCode);
router.patch('/affiliate-codes/:id/toggle', adminAffiliateController.toggleAffiliateCodeStatus);
router.get('/affiliate-codes/:id/usage', adminAffiliateController.getAffiliateCodeUsage);
router.get('/affiliate-codes/:id/commissions', adminAffiliateController.getAffiliateCodeCommissions);
router.get('/affiliate-commissions', adminAffiliateController.getAffiliateCommissions);

// Admin notification inbox
router.get('/notifications', adminNotificationController.getNotifications);
router.post('/notifications/read-all', adminNotificationController.markAllAsRead);
router.post('/notifications/:id/read', adminNotificationController.markAsRead);

// Reviews
router.get('/reviews', adminReviewController.getAllReviews);
router.post('/reviews', adminReviewController.createReview);
router.get('/reviews/:id', adminReviewController.getReview);
router.put('/reviews/:id', adminReviewController.updateReview);
router.delete('/reviews/:id', adminReviewController.deleteReview);

module.exports = router;
