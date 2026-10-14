const { randomUUID: uuidv4 } = require('crypto');
const sharp = require('sharp');
const { User, RefreshToken, MagicLinkToken } = require('../models');
const { saveBuffer } = require('../config/storage');
const { assertSmtpConfigured } = require('../services/emailService');
const { consumeMagicLink, issueMagicLink } = require('../services/magicLinkService');
const { UnauthorizedError, ConflictError, BadRequestError, ForbiddenError } = require('../utils/errors');
const { USER_ROLES, AUTH_PROVIDERS } = require('../utils/constants');
const { sanitizeUser } = require('../utils/helpers');
const { recordAudit } = require('../services/auditService');
const { currentLegalAcceptance } = require('../config/legalAcceptance');
const { notifyAdmins } = require('../services/adminNotificationService');
const { signAccessToken, signRefreshToken, verifyRefreshToken } = require('../utils/jwtTokens');
const { INDIAN_MOBILE_PATTERN } = require('../utils/phoneValidation');
const { isDemoMode } = require('../config/demoGuard');

// Admin magic-link recipients come from ADMIN_EMAILS only (no built-in defaults).
const DEFAULT_ADMIN_EMAILS = '';
const STAFF_SESSION_MS = 6 * 60 * 60 * 1000;
// Admins sign in with an email link; their session ends after 12 hours
// however often the refresh token is rotated.
const ADMIN_SESSION_MS = 12 * 60 * 60 * 1000;

function getMagicLinkPanelUrl() {
  const configuredUrl = String(process.env.ADMIN_PANEL_URL || process.env.FRONTEND_URL || '').trim();

  if (configuredUrl) {
    return configuredUrl.replace(/\/+$/, '');
  }

  if (process.env.NODE_ENV === 'production') {
    throw new Error('ADMIN_PANEL_URL must be set to the hosted Admin Panel URL in production');
  }

  return 'http://localhost:3001';
}

const generateTokens = async (userId, deviceInfo, sessionExpiresAt = null) => {
  const sessionExpiry = sessionExpiresAt ? new Date(sessionExpiresAt) : null;
  const tokenPayload = {
    userId,
    ...(sessionExpiry ? { sessionExpiresAt: sessionExpiry.toISOString() } : {}),
  };

  const accessToken = signAccessToken(
    tokenPayload,
    process.env.JWT_ACCESS_EXPIRY || '15m',
  );

  const refreshToken = signRefreshToken(
    tokenPayload,
    sessionExpiry
      ? Math.max(1, Math.floor((sessionExpiry.getTime() - Date.now()) / 1000))
      : (process.env.JWT_REFRESH_EXPIRY || '7d'),
  );

  const expiresAt = sessionExpiry || new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  await RefreshToken.create({
    userId,
    token: refreshToken,
    deviceInfo,
    expiresAt,
    sessionExpiresAt: sessionExpiry,
  });

  return {
    accessToken,
    refreshToken,
    ...(sessionExpiry ? { sessionExpiresAt: sessionExpiry.toISOString() } : {}),
  };
};

exports.register = async (req, res, next) => {
  try {
    const { name, email, password, phone, marketingConsent } = req.body;

    const existingUser = await User.findOne({ $or: [{ email }, { phone }] });
    if (existingUser) {
      throw new ConflictError(
        existingUser.phone === phone ? 'Phone number already registered' : 'Email already registered',
        'USER_ALREADY_EXISTS'
      );
    }

    const user = await User.create({
      name,
      email,
      phone,
      passwordHash: password,
      authProvider: AUTH_PROVIDERS.EMAIL,
      role: USER_ROLES.BUYER,
      marketingConsent,
      consentTimestamp: marketingConsent ? new Date() : null,
      ...currentLegalAcceptance(),
    });

    const tokens = await generateTokens(user._id, req.headers['user-agent']);

    res.status(201).json({
      success: true,
      message: 'Registration successful.',
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.registerWholesaler = async (req, res, next) => {
  try {
    const { name, email, password, phone, businessName, gstNumber, marketingConsent } = req.body;

    const existingUser = await User.findOne({ $or: [{ email }, { phone }] });
    if (existingUser) {
      throw new ConflictError(
        existingUser.phone === phone ? 'Phone number already registered' : 'Email already registered',
        'USER_ALREADY_EXISTS'
      );
    }

    const user = await User.create({
      name,
      email,
      phone,
      passwordHash: password,
      authProvider: AUTH_PROVIDERS.EMAIL,
      role: USER_ROLES.WHOLESALER,
      businessInfo: {
        businessName,
        gstNumber,
        verified: false,
      },
      marketingConsent,
      consentTimestamp: marketingConsent ? new Date() : null,
      ...currentLegalAcceptance(),
    });

    const tokens = await generateTokens(user._id, req.headers['user-agent']);

    notifyAdmins({
      type: 'wholesaler_application',
      title: 'New wholesaler registration',
      body: `${name} (${businessName || phone}) registered as a wholesaler.`,
      link: '/account-upgrades',
      actor: { id: user._id, name, role: user.role },
      metadata: { userId: String(user._id), businessName, phone },
    });

    res.status(201).json({
      success: true,
      message: 'Wholesaler registration successful.',
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email }).select('+passwordHash');
    // Admins sign in only with the email link; a password never opens an
    // admin account (same answer as a wrong password, so nothing is revealed).
    // DEMO ONLY: the demo has no SMTP, so the demo admin may use a password.
    if (!user || (user.role === USER_ROLES.ADMIN && !isDemoMode())) {
      throw new UnauthorizedError('Invalid credentials', 'AUTH_INVALID_CREDENTIALS');
    }

    if (user.role === USER_ROLES.STAFF) {
      throw new UnauthorizedError('Please use member login', 'AUTH_ROLE_MISMATCH');
    }

    if (user.authProvider !== AUTH_PROVIDERS.EMAIL) {
      throw new BadRequestError(`Please login with ${user.authProvider}`, 'AUTH_WRONG_PROVIDER');
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      throw new UnauthorizedError('Invalid credentials', 'AUTH_INVALID_CREDENTIALS');
    }

    if (!user.isActive) {
      throw new UnauthorizedError('Account is deactivated', 'ACCOUNT_DEACTIVATED');
    }

    user.lastLoginAt = new Date();
    await user.save();

    const tokens = await generateTokens(user._id, req.headers['user-agent']);

    res.json({
      success: true,
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.staffLogin = async (req, res, next) => {
  try {
    const { username, password } = req.body;
    const user = await User.findOne({ username: username.toLowerCase() }).select('+passwordHash');

    if (!user || user.role !== USER_ROLES.STAFF || user.authProvider !== AUTH_PROVIDERS.EMAIL) {
      throw new UnauthorizedError('Invalid credentials', 'AUTH_INVALID_CREDENTIALS');
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      throw new UnauthorizedError('Invalid credentials', 'AUTH_INVALID_CREDENTIALS');
    }
    if (!user.isActive) {
      throw new UnauthorizedError('Account is deactivated', 'ACCOUNT_DEACTIVATED');
    }

    const sessionExpiresAt = new Date(Date.now() + STAFF_SESSION_MS);
    user.lastLoginAt = new Date();
    await user.save();
    await recordAudit({
      actorId: user._id,
      action: 'staff.logged_in',
      entityType: 'user',
      entityId: user._id,
    });
    const tokens = await generateTokens(user._id, req.headers['user-agent'], sessionExpiresAt);

    res.json({
      success: true,
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.loginWithPhone = async (req, res, next) => {
  try {
    const { phone, password, expectedRole } = req.body;

    const user = await User.findOne({ phone }).select('+passwordHash');
    // Phone login is for customers and wholesalers. Admins use the email link
    // and members the member login (which keeps their 6-hour session limit).
    if (!user || ![USER_ROLES.BUYER, USER_ROLES.WHOLESALER].includes(user.role)) {
      throw new UnauthorizedError('Invalid credentials', 'AUTH_INVALID_CREDENTIALS');
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      throw new UnauthorizedError('Invalid credentials', 'AUTH_INVALID_CREDENTIALS');
    }

    if (!user.isActive) {
      throw new UnauthorizedError('Account is deactivated', 'ACCOUNT_DEACTIVATED');
    }

    // Validate role if expectedRole is provided
    if (expectedRole) {
      const isWholesaler = user.role === USER_ROLES.WHOLESALER;
      const expectsWholesaler = expectedRole === 'wholesaler';

      if (isWholesaler && !expectsWholesaler) {
        throw new UnauthorizedError('This is a wholesaler account. Please use the Wholesaler login.', 'AUTH_ROLE_MISMATCH');
      }
      if (!isWholesaler && expectsWholesaler) {
        throw new UnauthorizedError('This is a customer account. Please use the Customer login.', 'AUTH_ROLE_MISMATCH');
      }
    }

    user.lastLoginAt = new Date();
    await user.save();

    const tokens = await generateTokens(user._id, req.headers['user-agent']);

    res.json({
      success: true,
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.registerWithPhone = async (req, res, next) => {
  try {
    const { name, phone, password } = req.body;

    const existingUser = await User.findOne({ phone });
    if (existingUser) {
      throw new ConflictError('Phone number already registered', 'USER_ALREADY_EXISTS');
    }

    const user = await User.create({
      name,
      phone,
      passwordHash: password,
      authProvider: AUTH_PROVIDERS.EMAIL,
      role: USER_ROLES.BUYER,
      ...currentLegalAcceptance(),
    });

    const tokens = await generateTokens(user._id, req.headers['user-agent']);

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.registerWholesalerWithPhone = async (req, res, next) => {
  try {
    const { name, phone, password, businessName } = req.body;

    const existingUser = await User.findOne({ phone });
    if (existingUser) {
      throw new ConflictError('Phone number already registered', 'USER_ALREADY_EXISTS');
    }

    const user = await User.create({
      name,
      phone,
      passwordHash: password,
      authProvider: AUTH_PROVIDERS.EMAIL,
      role: USER_ROLES.WHOLESALER,
      businessInfo: {
        businessName: businessName || null,
        verified: false,
      },
      ...currentLegalAcceptance(),
    });

    const tokens = await generateTokens(user._id, req.headers['user-agent']);

    res.status(201).json({
      success: true,
      message: 'Wholesaler registration successful',
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    const decoded = verifyRefreshToken(refreshToken);

    const storedToken = await RefreshToken.findOne({
      token: refreshToken,
      userId: decoded.userId,
      isRevoked: false,
    });

    if (!storedToken) {
      throw new UnauthorizedError('Invalid refresh token', 'INVALID_REFRESH_TOKEN');
    }

    if (storedToken.expiresAt <= new Date() || (storedToken.sessionExpiresAt && storedToken.sessionExpiresAt <= new Date())) {
      storedToken.isRevoked = true;
      await storedToken.save();
      throw new UnauthorizedError('Session expired', 'SESSION_EXPIRED');
    }

    storedToken.isRevoked = true;
    await storedToken.save();

    const tokens = await generateTokens(decoded.userId, req.headers['user-agent'], storedToken.sessionExpiresAt);

    res.json({
      success: true,
      data: tokens,
    });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      next(new UnauthorizedError('Refresh token expired', 'REFRESH_TOKEN_EXPIRED'));
    } else if (error.name === 'JsonWebTokenError') {
      next(new UnauthorizedError('Invalid refresh token', 'INVALID_REFRESH_TOKEN'));
    } else {
      next(error);
    }
  }
};

// Ends a session: its refresh token stops working. Works with just the
// refresh token, so signing out still ends the session after the short-lived
// access token has expired.
exports.logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    let ownerId = req.user?._id || null;
    if (!ownerId && typeof refreshToken === 'string' && refreshToken) {
      try {
        ownerId = verifyRefreshToken(refreshToken).userId;
      } catch {
        ownerId = null; // Not a valid refresh token: nothing to end.
      }
    }

    if (ownerId && typeof refreshToken === 'string' && refreshToken) {
      await RefreshToken.updateOne(
        { token: refreshToken, userId: ownerId },
        { isRevoked: true }
      );
    }

    res.json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    next(error);
  }
};

exports.getMe = async (req, res, next) => {
  try {
    res.json({
      success: true,
      data: sanitizeUser(req.user),
    });
  } catch (error) {
    next(error);
  }
};

// Saves the app language so notifications reach the customer in it.
exports.updatePreferences = async (req, res, next) => {
  try {
    const { language } = req.body;
    await User.updateOne({ _id: req.user._id }, { $set: { preferredLanguage: language } });
    res.json({ success: true, data: { preferredLanguage: language } });
  } catch (error) {
    next(error);
  }
};

exports.updateProfile = async (req, res, next) => {
  try {
    const { name, avatar, phone, address } = req.body;
    const user = req.user;

    if (name) user.name = name;
    if (avatar !== undefined) user.avatar = avatar;
    if (phone && phone !== user.phone) {
      // A new number must be a 10-digit Indian mobile, like at registration.
      // (Saving the profile with the number already on file always works.)
      if (!INDIAN_MOBILE_PATTERN.test(phone)) {
        throw new BadRequestError('Enter a valid 10-digit mobile number', 'INVALID_PHONE');
      }
      user.phone = phone;
    }
    if (address !== undefined) user.address = address;

    await user.save();

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: sanitizeUser(user),
    });
  } catch (error) {
    next(error);
  }
};

exports.uploadProfileAvatar = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file uploaded',
      });
    }

    const webpBuffer = await sharp(req.file.buffer).webp({ quality: 80 }).toBuffer();
    const saved = await saveBuffer({
      buffer: webpBuffer,
      folder: `avatars/${req.user._id}`,
      filename: `${uuidv4()}.webp`,
      contentType: 'image/webp',
      metadata: {
        originalName: req.file.originalname,
        uploadedBy: req.user._id.toString(),
        uploadedAt: new Date().toISOString(),
      },
    });
    const avatarUrl = saved.url;

    const user = req.user;
    user.avatar = avatarUrl;
    await user.save();

    res.json({
      success: true,
      message: 'Avatar updated successfully',
      data: {
        avatarUrl,
        user: sanitizeUser(user),
      },
    });
  } catch (error) {
    next(error);
  }
};

const MAX_FCM_TOKENS_PER_USER = 10;
const MAX_FCM_TOKEN_LENGTH = 4096;

exports.registerFcmToken = async (req, res, next) => {
  try {
    const { fcmToken } = req.body;
    const user = req.user;

    if (typeof fcmToken !== 'string' || !fcmToken || fcmToken.length > MAX_FCM_TOKEN_LENGTH) {
      throw new BadRequestError('A valid FCM token is required', 'INVALID_FCM_TOKEN');
    }

    if (!user.fcmTokens.includes(fcmToken)) {
      // Keep the newest few devices only.
      user.fcmTokens = [...user.fcmTokens, fcmToken].slice(-MAX_FCM_TOKENS_PER_USER);
      await user.save();
    }

    res.json({
      success: true,
      message: 'FCM token registered',
    });
  } catch (error) {
    next(error);
  }
};

exports.convertToWholesaler = async (req, res, next) => {
  try {
    const {
      businessName,
      gstNumber,
      businessAddress,
      contactPerson,
      phone,
      shopLocationLat,
      shopLocationLng,
      shopLocationLabel,
    } = req.body;
    const user = req.user;

    let proofImageKeys = [];
    if (req.files && req.files.length > 0) {
      proofImageKeys = await Promise.all(
        req.files.map(async (file) => {
          const webpBuffer = await sharp(file.buffer).webp({ quality: 80 }).toBuffer();
          const saved = await saveBuffer({
            buffer: webpBuffer,
            folder: `private/proofs/${user._id}`,
            filename: `${uuidv4()}.webp`,
            contentType: 'image/webp',
            metadata: {
              originalName: file.originalname,
              uploadedBy: user._id.toString(),
              uploadedAt: new Date().toISOString(),
              mediaPurpose: 'business-proof',
            },
            visibility: 'private',
          });
          return saved.publicId;
        })
      );
    }

    const existingBusinessInfo = user.businessInfo?.toObject?.() || user.businessInfo || {};

    // Admin verifies before role update. New proof submissions are private and replace
    // prior proof references, matching the previous re-application behavior.
    user.businessInfo = {
      ...existingBusinessInfo,
      businessName,
      gstNumber,
      businessAddress,
      contactPerson,
      shopLocation: {
        lat: Number(shopLocationLat),
        lng: Number(shopLocationLng),
        placeLabel: shopLocationLabel || null,
        capturedAt: new Date(),
      },
      status: 'pending',
      verified: false,
      proofImageKeys: proofImageKeys.length > 0
        ? proofImageKeys
        : (existingBusinessInfo.proofImageKeys || []),
      proofImages: proofImageKeys.length > 0
        ? []
        : (existingBusinessInfo.proofImages || []),
    };

    // Also update phone/name if changed? Usually contact person is just name
    user.name = contactPerson || user.name;
    user.phone = phone || user.phone;

    await user.save();

    notifyAdmins({
      type: 'wholesaler_application',
      severity: 'warning',
      title: 'Wholesaler verification pending',
      body: `${user.name} (${businessName || user.phone}) submitted business proofs for verification.`,
      link: '/account-upgrades',
      actor: { id: user._id, name: user.name, role: user.role },
      metadata: { userId: String(user._id), businessName },
    });

    res.json({
      success: true,
      message: 'Account converted to wholesaler successfully. Please wait for verification.',
      data: sanitizeUser(user),
    });
  } catch (error) {
    next(error);
  }
};

exports.requestMagicLink = async (req, res, next) => {
  try {
    assertSmtpConfigured();

    const adminEmails = (process.env.ADMIN_EMAILS || DEFAULT_ADMIN_EMAILS)
      .split(',')
      .map((email) => email.trim().toLowerCase())
      .filter(Boolean);

    const expiryMinutes = Number(process.env.MAGIC_LINK_EXPIRY_MINUTES) || 5;
    const panelUrl = getMagicLinkPanelUrl();

    for (const email of adminEmails) {
      const user = await User.findOne({ email, role: USER_ROLES.ADMIN, isActive: true });
      if (!user) continue; // silently skip unseeded/inactive admins

      await issueMagicLink({
        email,
        panelUrl,
        expiryMinutes,
      });
    }

    // Generic response - no account enumeration
    res.json({
      success: true,
      message: 'Magic link sent to the admin inboxes.',
    });
  } catch (error) {
    next(error);
  }
};

exports.verifyMagicLink = async (req, res, next) => {
  try {
    const { token } = req.body;

    const record = await consumeMagicLink(token);

    if (!record) {
      throw new ForbiddenError('Magic link is invalid or has expired', 'MAGIC_LINK_INVALID');
    }

    const user = await User.findOne({
      email: record.email,
      role: USER_ROLES.ADMIN,
      isActive: true,
    });

    if (!user) {
      throw new ForbiddenError('Magic link is invalid or has expired', 'MAGIC_LINK_INVALID');
    }

    user.lastLoginAt = new Date();
    await user.save();

    const tokens = await generateTokens(
      user._id,
      req.headers['user-agent'],
      new Date(Date.now() + ADMIN_SESSION_MS),
    );
    await MagicLinkToken.deleteMany({ email: record.email, used: false });

    res.json({
      success: true,
      data: {
        user: sanitizeUser(user),
        ...tokens,
      },
    });
  } catch (error) {
    next(error);
  }
};
