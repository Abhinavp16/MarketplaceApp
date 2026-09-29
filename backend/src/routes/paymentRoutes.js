const express = require('express');
const router = express.Router();

const customerPaymentRetired = (req, res) => {
  res.status(410).json({
    success: false,
    code: 'CUSTOMER_PAYMENT_FLOW_RETIRED',
    message: 'Payments are confirmed directly by the shop after WhatsApp order submission.',
  });
};

// Kept as explicit retired endpoints for older app builds. Admin and staff
// payment-confirmation routes are separate and remain fully operational.
router.all('/upi-details', customerPaymentRetired);
router.all('/:orderId/upload', customerPaymentRetired);
router.all('/:orderId', customerPaymentRetired);

module.exports = router;
