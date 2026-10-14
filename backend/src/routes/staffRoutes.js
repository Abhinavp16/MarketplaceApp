const express = require('express');
const router = express.Router();
const { protect, staffOnly } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const { adminValidation } = require('../validations');
const adminOrderController = require('../controllers/admin/orderController');
const adminNegotiationController = require('../controllers/admin/negotiationController');
const adminPaymentController = require('../controllers/admin/paymentController');
const staffOperationsController = require('../controllers/staffOperationsController');
const adminAnalyticsController = require('../controllers/admin/analyticsController');

router.use(protect, staffOnly);

router.get('/products', staffOperationsController.getProducts);

router.get('/orders', adminOrderController.getOrders);
router.get('/orders/:id', adminOrderController.getOrderById);
router.get('/orders/:id/receipt', adminOrderController.getOrderReceipt);
router.put('/orders/:id/accept', validate(adminValidation.acceptOrder), adminOrderController.acceptOrder);
router.put('/orders/:id/reject', validate(adminValidation.rejectOrder), adminOrderController.rejectOrder);
router.put('/orders/:id/mark-payment-complete', adminOrderController.markPaymentCompleted);
router.put('/orders/:id/ship', validate(adminValidation.shipOrder), adminOrderController.shipOrder);

router.get('/payments', adminPaymentController.getPayments);
router.put('/payments/:id/approve', staffOperationsController.ensurePendingUploadedPayment, adminPaymentController.verifyPayment);
router.put('/payments/:id/hold', validate(adminValidation.holdPayment), staffOperationsController.holdPayment);

router.get('/negotiations', staffOperationsController.getNegotiations);
router.get('/negotiations/:id', staffOperationsController.getNegotiationById);
router.put('/negotiations/:id/accept', validate(adminValidation.acceptNegotiation), staffOperationsController.acceptNegotiation);
router.put('/negotiations/:id/counter', validate(adminValidation.counterNegotiation), staffOperationsController.counterNegotiation);
router.put('/negotiations/:id/reject', staffOperationsController.demoOwnerOnly, validate(adminValidation.rejectNegotiation), adminNegotiationController.rejectNegotiation);
router.put('/negotiations/groups/:groupId/reject', staffOperationsController.demoOwnerOnly, validate(adminValidation.rejectNegotiation), adminNegotiationController.rejectRequirementGroup);

// Leads (same list as the admin panel)
router.get('/analytics/potential-customers', adminAnalyticsController.getPotentialCustomers);

module.exports = router;
