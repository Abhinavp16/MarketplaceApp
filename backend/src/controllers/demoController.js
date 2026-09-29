const { Settings } = require('../models');
const BRAND = require('../config/brand');
const { BadRequestError } = require('../utils/errors');
const { assertDemoDatabase } = require('../config/demoGuard');
const pkg = require('../../package.json');

const RESET_CONFIRMATION = 'RESET DEMO';

// GET /api/v1/demo/info  (public, demo mode only)
exports.getInfo = async (req, res, next) => {
  try {
    const settings = await Settings.findById('app_settings').select('demo').lean();
    res.json({
      success: true,
      demoMode: true,
      brand: BRAND.name,
      version: settings?.demo?.fixtureVersion || null,
      seededAt: settings?.demo?.seededAt || null,
      apiVersion: pkg.version,
      business: {
        name: BRAND.name,
        legalName: BRAND.legalName,
        tagline: BRAND.tagline,
        email: BRAND.email,
        phone: BRAND.phone,
        address: BRAND.address,
        website: BRAND.website,
      },
    });
  } catch (error) {
    next(error);
  }
};

let resetInProgress = false;

// POST /api/v1/admin/demo/reset  (admin only, demo mode only)
exports.resetDemo = async (req, res, next) => {
  try {
    if (!req.body || req.body.confirm !== RESET_CONFIRMATION) {
      throw new BadRequestError(`Send {"confirm":"${RESET_CONFIRMATION}"} to reset the demo data`, 'DEMO_RESET_CONFIRMATION_REQUIRED');
    }
    if (resetInProgress) {
      throw new BadRequestError('A demo reset is already running', 'DEMO_RESET_IN_PROGRESS');
    }
    assertDemoDatabase({ actualDbName: require('mongoose').connection.name });

    resetInProgress = true;
    try {
      // Lazy require: the seed module lives under scripts/ and is only needed here.
      const { seedDemo } = require('../../scripts/demo/seed');
      const result = await seedDemo({ wipe: true, log: () => {} });
      res.json({
        success: true,
        message: 'Demo data has been reset to its baseline',
        data: { ...result.counts, seededAt: result.seededAt, version: result.version },
      });
    } finally {
      resetInProgress = false;
    }
  } catch (error) {
    next(error);
  }
};
