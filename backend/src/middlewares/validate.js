const Joi = require('joi');
const { ValidationError } = require('../utils/errors');

const validate = (schema, property = 'body', options = {}) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,
      stripUnknown: true,
      ...options,
    });

    if (error) {
      const details = error.details.map((detail) => ({
        field: detail.path.join('.'),
        message: detail.message,
      }));

      return next(new ValidationError('Validation failed', details));
    }

    req[property] = value;
    next();
  };
};

module.exports = validate;
