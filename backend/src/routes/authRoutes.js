const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const accountDeletionController = require('../controllers/accountDeletionController');
const { protect, optionalAuth } = require('../middlewares/auth');
const { uploadAvatar, uploadProductImages } = require('../config/uploads');
const validate = require('../middlewares/validate');
const { authValidation } = require('../validations');
const {
  loginIpLimiter,
  loginAccountLimiter,
  registerLimiter,
  refreshLimiter,
  magicLinkLimiter,
} = require('../middlewares/rateLimits');

// Sign-in routes: per-IP attempts plus failed attempts per account.
const loginLimits = [loginIpLimiter, loginAccountLimiter];

router.post('/register', registerLimiter, validate(authValidation.register), authController.register);
router.post('/register/wholesaler', registerLimiter, validate(authValidation.registerWholesaler), authController.registerWholesaler);
router.post('/register-phone', registerLimiter, validate(authValidation.registerPhone), authController.registerWithPhone);
router.post('/register-phone/wholesaler', registerLimiter, validate(authValidation.registerPhoneWholesaler), authController.registerWholesalerWithPhone);
router.post('/login', ...loginLimits, validate(authValidation.login), authController.login);
router.post('/staff/login', ...loginLimits, validate(authValidation.staffLogin), authController.staffLogin);
router.post('/magic-link/request', magicLinkLimiter, authController.requestMagicLink);
router.post('/magic-link/verify', magicLinkLimiter, validate(authValidation.magicLinkVerify), authController.verifyMagicLink);
router.post('/login-phone', ...loginLimits, validate(authValidation.loginPhone), authController.loginWithPhone);
router.post('/refresh-token', refreshLimiter, validate(authValidation.refreshToken), authController.refreshToken);
router.post('/logout', refreshLimiter, optionalAuth, authController.logout);
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
