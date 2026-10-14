const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const routes = require('./routes');
const connectDB = require('./config/database');
const { initializeFirebase } = require('./config/firebase');
const errorHandler = require('./middlewares/errorHandler');
const { NotFoundError, ForbiddenError } = require('./utils/errors');
const { isAllowedOrigin } = require('./config/corsOrigins');
const { jwtConfigProblems } = require('./utils/jwtTokens');
const { apiLimiter } = require('./middlewares/rateLimits');
const { stripOperatorKeysMiddleware } = require('./middlewares/stripOperatorKeys');
const { priceUpdateNotifierMiddleware } = require('./services/priceChangeNotificationService');
const logger = require('./utils/logger');
const BRAND = require('./config/brand');
const { isDemoMode } = require('./config/demoGuard');

const app = express();

// server.js refuses to start with an unsafe JWT secret in production. When the
// API runs without it (serverless hosting imports this file directly), say so
// loudly instead of taking the API down.
const jwtProblems = jwtConfigProblems();
if (jwtProblems.length) {
  logger.error(`[Security] Unsafe JWT configuration: ${jwtProblems.join('; ')}`);
}

// Proxies in front of the API (e.g. 1 for Caddy on the VPS). TRUST_PROXY_HOPS
// wins when set; otherwise production trusts one proxy.
const trustProxyHops = String(process.env.TRUST_PROXY_HOPS ?? '').trim();
app.set('trust proxy', trustProxyHops !== ''
  ? Number(trustProxyHops)
  : (process.env.NODE_ENV === 'production' ? 1 : false));

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

// CORS: only our own sites (and exact origins from env) may call the API from
// a browser; see config/corsOrigins.
const corsOptions = {
  origin(origin, callback) {
    // Allow server-to-server and curl requests without Origin header.
    if (!origin) return callback(null, true);
    if (isAllowedOrigin(origin)) return callback(null, true);
    return callback(new ForbiddenError('This website is not allowed to use the API', 'CORS_ORIGIN_NOT_ALLOWED'));
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  // Lets the admin panel name downloaded receipts.
  exposedHeaders: ["Content-Disposition", "X-Receipt-Filename"],
};

app.use(cors(corsOptions));
app.options("*", cors(corsOptions));

// Rate limiting: per signed-in user (verified token) or per IP; stricter
// limits on sign-in and other sensitive routes live in middlewares/rateLimits.
app.use('/api', apiLimiter);

// Body parsing. JSON bodies are small; files go through the upload routes
// (multer), which have their own limits. Admin screens (website settings with
// every product's details) may send more.
app.use('/api/v1/admin', express.json({ limit: '5mb' }));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(stripOperatorKeysMiddleware);
// Demo catalogue images ship with the repo (assets/demo-images) and are served
// at /uploads/demo/* so the regular local-storage URL scheme keeps working.
if (isDemoMode()) {
  app.use('/uploads/demo', express.static(path.resolve(__dirname, '..', 'assets', 'demo-images')));
}
app.use('/uploads', express.static(path.resolve(process.cwd(), process.env.LOCAL_UPLOADS_DIR || 'uploads')));

// Logging
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: `${BRAND.name} API is running`,
    timestamp: new Date().toISOString(),
  });
});

// Root landing route for hosted environments that probe "/"
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: `${BRAND.name} API is running`,
    docs: '/api/v1',
    health: '/health',
    apiHealth: '/api/v1/health',
  });
});

// Ensure dependencies are initialized for API routes in hosted/serverless environments.
app.use('/api/v1', async (req, res, next) => {
  try {
    // Keep the public health checks lightweight and self-diagnosing (the
    // admin-only details need the database for sign-in).
    if (req.path === '/health' || req.path === '/health/live') {
      return next();
    }

    await connectDB();
    initializeFirebase();
    return next();
  } catch (error) {
    return next(error);
  }
});

// Immediate price changes waiting to be announced go out with the next request
// once their wait is over (no background timers on serverless hosting).
app.use('/api/v1', (req, res, next) => (
  req.path === '/health' || req.path === '/health/live' ? next() : priceUpdateNotifierMiddleware(req, res, next)
));

// API routes
app.use('/api/v1', routes);

// 404 handler
app.use((req, res, next) => {
  next(new NotFoundError(`Route ${req.originalUrl} not found`));
});

// Global error handler
app.use(errorHandler);

module.exports = app;
