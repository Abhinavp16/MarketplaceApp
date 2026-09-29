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
const NegotiationSocketService = require('./services/negotiationSocketService');
const logger = require('./utils/logger');

const PORT = process.env.PORT || (isDemoMode() ? 5050 : 5000);

const startServer = async () => {
  try {
    await connectDB();

    // Create HTTP server
    const server = http.createServer(app);

    // Initialize Socket.io
    const io = new SocketIOServer(server, {
      cors: {
        origin: [
          'http://localhost:3000',
          'http://127.0.0.1:3000',
          'http://localhost:3001',
          'http://127.0.0.1:3001',
          process.env.ADMIN_PANEL_URL || '',
          process.env.FRONTEND_URL || '',
        ].filter(Boolean),
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
    // Demo mode is offline: the Hindi-name sweep calls external services.
    if (!isDemoMode()) startHindiNameScheduler();

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
