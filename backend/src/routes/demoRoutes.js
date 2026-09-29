const express = require('express');
const { isDemoMode } = require('../config/demoGuard');
const { NotFoundError } = require('../utils/errors');
const { protect, adminOnly } = require('../middlewares/auth');
const demoController = require('../controllers/demoController');

// Both routers answer 404 unless DEMO_MODE=true (checked per request).
const requireDemoMode = (req, res, next) => (
  isDemoMode() ? next() : next(new NotFoundError(`Route ${req.originalUrl} not found`))
);

// Public: GET /api/v1/demo/info
const publicRouter = express.Router();
publicRouter.use(requireDemoMode);
publicRouter.get('/info', demoController.getInfo);

// Admin only: POST /api/v1/admin/demo/reset  (mounted before /admin)
const adminRouter = express.Router();
adminRouter.use(requireDemoMode);
adminRouter.use(protect, adminOnly);
adminRouter.post('/reset', demoController.resetDemo);

module.exports = { publicRouter, adminRouter };
