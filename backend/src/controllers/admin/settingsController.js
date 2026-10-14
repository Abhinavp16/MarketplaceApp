const { Settings } = require('../../models');
const { mobilePlatformSettingsSchemas } = require('../../validations');
const { ValidationError } = require('../../utils/errors');
const logger = require('../../utils/logger');
const { withoutUnusedVideo } = require('../../utils/bannerMedia');
const {
  deleteReplacedBannerMedia,
  sweepUnusedBannerMedia,
} = require('../../services/bannerMediaCleanupService');

exports.getSettings = async (req, res, next) => {
  try {
    const settings = await Settings.getSettings();

    res.set('Cache-Control', 'no-store');
    res.json({
      success: true,
      data: settings,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateSettings = async (req, res, next) => {
  try {
    let settings = await Settings.findById('app_settings');

    if (!settings) {
      settings = new Settings({ _id: 'app_settings' });
    }

    // Banner media before the change, to delete files that stop being used.
    const bannersChanged = req.body.heroBanners !== undefined || req.body.promoBanners !== undefined;
    const bannersBefore = bannersChanged
      ? {
        heroBanners: (settings.heroBanners || []).map((banner) => banner.toObject?.() || banner),
        promoBanners: (settings.promoBanners || []).map((banner) => banner.toObject?.() || banner),
      }
      : null;
    if (Array.isArray(req.body.heroBanners)) {
      req.body.heroBanners = req.body.heroBanners.map(withoutUnusedVideo);
    }

    const allowedFields = [
      'businessName',
      'businessPhone',
      'businessEmail',
      'businessAddress',
      'upiId',
      'upiDisplayName',
      'minOrderAmount',
      'defaultBulkMinQuantity',
      'negotiationExpiryDays',
      'lowStockThreshold',
      'features',
      'mobileApp',
      'heroBanners',
      'promoBanners',
      'socialLinks',
      'checkout',
      'bankName',
      'bankAccountNumber',
      'bankIfscCode',
      'bankAccountHolderName',
      'bankTransferEnabled',
    ];

    for (const field of allowedFields) {
      if (field !== 'mobileApp' && req.body[field] !== undefined) {
        settings[field] = req.body[field];
      }
    }

    if (req.body.mobileApp) {
      const currentMobileApp = settings.mobileApp?.toObject?.() || settings.mobileApp || {};
      const mobileAppUpdates = {};

      for (const [platform, update] of Object.entries(req.body.mobileApp)) {
        const platformSchema = mobilePlatformSettingsSchemas[platform];
        if (!platformSchema) {
          throw new ValidationError(`Unsupported mobile platform: ${platform}`);
        }
        const mergedPlatform = {
          ...(currentMobileApp[platform] || {}),
          ...update,
        };
        const { error, value } = platformSchema.validate(mergedPlatform, {
          abortEarly: false,
        });

        if (error) {
          throw new ValidationError('Validation failed', error.details.map((detail) => ({
            field: `mobileApp.${platform}.${detail.path.join('.')}`,
            message: detail.message,
          })));
        }

        mobileAppUpdates[platform] = value;
      }

      settings.mobileApp = { ...currentMobileApp, ...mobileAppUpdates };
    }

    settings.checkout = {
      ...(settings.checkout?.toObject?.() || settings.checkout || {}),
      ...(req.body.checkout || {}),
      mode: 'whatsapp',
      requireLoginForCheckout: true,
      createOrderBeforeRedirect: true,
    };

    await settings.save();

    if (bannersBefore) {
      // Removed / replaced banner images and videos are deleted from storage,
      // then any old upload no banner uses (e.g. cancelled). Never fails the save.
      try {
        await deleteReplacedBannerMedia(bannersBefore, {
          heroBanners: settings.heroBanners,
          promoBanners: settings.promoBanners,
        });
        await sweepUnusedBannerMedia();
      } catch (error) {
        logger.warn(`[BannerMedia] cleanup after save failed: ${error.message}`);
      }
    }

    res.json({
      success: true,
      message: 'Settings updated successfully',
      data: settings,
    });
  } catch (error) {
    next(error);
  }
};
