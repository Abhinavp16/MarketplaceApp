const logger = require('../utils/logger');
const { AppError } = require('../utils/errors');
const { isDemoMode } = require('../config/demoGuard');

// Stack traces and the raw message of unexpected errors stay in the server
// log. Set EXPOSE_ERROR_STACK=true on a local machine to see them in responses.
// Always off in demo mode.
const exposeErrorDetails = () => process.env.EXPOSE_ERROR_STACK === 'true' && !isDemoMode();

const GENERIC_SERVER_ERROR = 'Something went wrong. Please try again.';

const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  logger.error('Error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // Mongoose bad ObjectId
  if (err.name === 'CastError') {
    error = new AppError('Resource not found', 404, 'INVALID_ID');
  }

  // Mongoose duplicate key
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    error = field === 'phone'
      ? new AppError('Phone number already registered', 409, 'USER_ALREADY_EXISTS')
      : new AppError(`${field} already exists`, 409, 'DUPLICATE_FIELD');
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map((val) => val.message);
    error = new AppError(messages.join(', '), 400, 'VALIDATION_ERROR');
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    error = new AppError('Invalid token', 401, 'INVALID_TOKEN');
  }

  if (err.name === 'TokenExpiredError') {
    error = new AppError('Token expired', 401, 'TOKEN_EXPIRED');
  }

  // Multer errors
  if (err.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      error = new AppError('File too large', 400, 'FILE_TOO_LARGE');
    } else {
      error = new AppError(err.message, 400, 'FILE_UPLOAD_ERROR');
    }
  }

  // Request body errors from express.json (too large, not valid JSON).
  if (err.type === 'entity.too.large') {
    error = new AppError('Request is too large', 413, 'PAYLOAD_TOO_LARGE');
  } else if (err.type === 'entity.parse.failed') {
    error = new AppError('Request body is not valid JSON', 400, 'INVALID_JSON');
  }

  const statusCode = error.statusCode || 500;
  // Our own errors (AppError) carry messages meant for users; anything
  // unexpected could reveal internals (database, file paths, services).
  const isExpected = Boolean(error.isOperational) || statusCode < 500;
  const response = {
    success: false,
    message: isExpected || exposeErrorDetails()
      ? (error.message || GENERIC_SERVER_ERROR)
      : GENERIC_SERVER_ERROR,
    error: {
      code: (isExpected || exposeErrorDetails()) && error.code ? error.code : 'SERVER_ERROR',
    },
  };

  if (error.details) {
    response.error.details = error.details;
  }

  if (exposeErrorDetails()) {
    response.error.stack = err.stack;
  }

  res.status(statusCode).json(response);
};

module.exports = errorHandler;
