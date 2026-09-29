const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');
const { protect, optionalAuth } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const { orderValidation } = require('../validations');

router.post('/preview-coupon', optionalAuth, validate(orderValidation.previewCoupon), orderController.previewCouponForCart);
router.post('/', optionalAuth, validate(orderValidation.createFromCart), orderController.createOrderFromCart);
router.post('/from-negotiation', protect, validate(orderValidation.createFromNegotiation), orderController.createOrderFromNegotiation);

router.use(protect);
router.get('/', orderController.getMyOrders);
router.get('/:id/export', orderController.exportOrderDocument);
router.get('/:id', orderController.getOrderById);

module.exports = router;
