const { Settings } = require('../models');

const publicPlatformSettings = (platform) => ({
  enabled: platform.enabled,
  latestVersion: platform.latestVersion,
  latestBuildNumber: platform.latestBuildNumber,
  storeUrl: platform.storeUrl,
  title: platform.title,
  message: platform.message,
});

exports.getMobileAppSettings = async (req, res, next) => {
  try {
    const settings = await Settings.getSettings();

    res.set('Cache-Control', 'no-store');
    res.json({
      success: true,
      data: {
        android: publicPlatformSettings(settings.mobileApp.android),
        ios: publicPlatformSettings(settings.mobileApp.ios),
      },
    });
  } catch (error) {
    next(error);
  }
};
