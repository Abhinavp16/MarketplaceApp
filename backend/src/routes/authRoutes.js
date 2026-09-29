const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const authController = require('../controllers/authController');
const accountDeletionController = require('../controllers/accountDeletionController');
const { protect } = require('../middlewares/auth');
const { uploadAvatar, uploadProductImages } = require('../config/cloudinary');
const validate = require('../middlewares/validate');
const { authValidation } = require('../validations');

const magicLinkRequestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many magic-link requests. Please try again later.',
    error: { code: 'MAGIC_LINK_RATE_LIMITED' },
  },
});

router.post('/register', validate(authValidation.register), authController.register);
router.post('/register/wholesaler', validate(authValidation.registerWholesaler), authController.registerWholesaler);
router.post('/register-phone', validate(authValidation.registerPhone), authController.registerWithPhone);
router.post('/register-phone/wholesaler', validate(authValidation.registerPhoneWholesaler), authController.registerWholesalerWithPhone);
router.post('/login', validate(authValidation.login), authController.login);
router.post('/staff/login', validate(authValidation.staffLogin), authController.staffLogin);
router.post('/magic-link/request', magicLinkRequestLimiter, authController.requestMagicLink);
router.post('/magic-link/verify', validate(authValidation.magicLinkVerify), authController.verifyMagicLink);
router.post('/login-phone', validate(authValidation.loginPhone), authController.loginWithPhone);
router.post('/refresh-token', validate(authValidation.refreshToken), authController.refreshToken);
router.post('/logout', protect, authController.logout);
router.get('/me', protect, authController.getMe);
router.put('/profile', protect, validate(authValidation.updateProfile), authController.updateProfile);
router.put('/preferences', protect, validate(authValidation.updatePreferences), authController.updatePreferences);
router.post('/profile/avatar', protect, uploadAvatar.single('avatar'), authController.uploadProfileAvatar);
router.post('/fcm-token', protect, validate(authValidation.fcmToken), authController.registerFcmToken);
router.post('/convert-to-wholesaler', protect, uploadProductImages.array('proofImages', 3), validate(authValidation.convertWholesaler), authController.convertToWholesaler);
router.get('/account-deletion-request', protect, accountDeletionController.getMyRequest);
router.post('/account-deletion-request', protect, validate(authValidation.requestAccountDeletion), accountDeletionController.requestMyAccountDeletion);
router.post('/account-deletion-request/cancel', protect, accountDeletionController.cancelMyAccountDeletion);

module.exports = router;
