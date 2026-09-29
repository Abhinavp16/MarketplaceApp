const express = require('express');
const router = express.Router();
const { protect, staffOnly } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const { adminValidation } = require('../validations');
const adminOrderController = require('../controllers/admin/orderController');
const adminPaymentController = require('../controllers/admin/paymentController');
const staffOperationsController = require('../controllers/staffOperationsController');

router.use(protect, staffOnly);

router.get('/products', staffOperationsController.getProducts);

router.get('/orders', adminOrderController.getOrders);
router.get('/orders/:id', adminOrderController.getOrderById);
router.put('/orders/:id/accept', adminOrderController.acceptOrder);
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

module.exports = router;
