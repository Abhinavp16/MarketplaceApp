require('dotenv').config();

// Safety guard: in DEMO_MODE refuse to start unless the environment is a
// local, credential-free demo setup. Must run before anything connects.
const { enforceDemoGuard, isDemoMode } = require('./config/demoGuard');
enforceDemoGuard();

const http = require('http');
const { Server: SocketIOServer } = require('socket.io');
const app = require('./app');
const connectDB = require('./config/database');
const { initializeFirebase } = require('./config/firebase');
const { startPriceChangeScheduler } = require('./services/productPriceSchedulerService');
const { startHindiNameScheduler } = require('./services/hindiNameSchedulerService');
const { startBannerMediaSweepScheduler } = require('./services/bannerMediaCleanupService');
const { startProductLaunchScheduler } = require('./services/productLaunchService');
const { startDeclinedNegotiationCleanupScheduler } = require('./services/declinedNegotiationCleanupService');
const { startAccountDeletionReminderScheduler } = require('./services/accountDeletionReminderService');
const { startPriceUpdateNotifier } = require('./services/priceChangeNotificationService');
const NegotiationSocketService = require('./services/negotiationSocketService');
const logger = require('./utils/logger');
const { assertJwtConfig } = require('./utils/jwtTokens');
const { isAllowedOrigin } = require('./config/corsOrigins');

const PORT = process.env.PORT || (isDemoMode() ? 5050 : 5000);

const startServer = async () => {
  try {
    // In production, refuse to run with a missing, short or leaked JWT secret.
    assertJwtConfig();
    await connectDB();

    // Create HTTP server
    const server = http.createServer(app);

    // Initialize Socket.io
    const io = new SocketIOServer(server, {
      cors: {
        // Same websites as the API (the app sends no Origin).
        origin: (origin, callback) => callback(null, !origin || isAllowedOrigin(origin)),
        credentials: true,
      },
      transports: ['websocket', 'polling'],
    });

    // Initialize negotiation socket events
    NegotiationSocketService.initializeSocket(io);

    // Make io accessible to routes/controllers
    app.locals.io = io;

    // Initialize Firebase (optional - will warn if not configured)
    initializeFirebase();
    startPriceChangeScheduler();
    // Demo mode is offline: the Hindi-name sweep calls external services and
    // the banner-media sweep deletes files, so neither runs.
    if (!isDemoMode()) {
      startHindiNameScheduler();
      startBannerMediaSweepScheduler();
    }
    startProductLaunchScheduler();
    startDeclinedNegotiationCleanupScheduler();
    startAccountDeletionReminderScheduler();
    startPriceUpdateNotifier();

    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`🚀 Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
      logger.info(`📚 API Docs: http://${process.env.HOST || 'localhost'}:${PORT}/api/v1`);
      logger.info(`🔌 WebSocket: ws://${process.env.HOST || 'localhost'}:${PORT}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

process.on('unhandledRejection', (err) => {
  logger.error('Unhandled Rejection:', err);
  process.exit(1);
});

process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception:', err);
  process.exit(1);
});

startServer();
