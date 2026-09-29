const express = require('express');
const router = express.Router();
const negotiationController = require('../controllers/negotiationController');
const { protect, authorize } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const { negotiationValidation } = require('../validations');

router.use(protect);
router.use(authorize('wholesaler'));

router.get('/', negotiationController.getMyNegotiations);
router.post('/', validate(negotiationValidation.create), negotiationController.createNegotiation);
router.get('/:id', negotiationController.getNegotiationById);
// NOTE: wholesalers negotiate via chat messages only. Accept / counter /
// reject are admin & staff actions performed from the admin panel.
router.post('/:id/message', negotiationController.sendMessage);

module.exports = router;
