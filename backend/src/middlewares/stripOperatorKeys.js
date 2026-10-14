// Request data never carries MongoDB operators. Keys starting with "$" are
// removed from the query string and body, so input like ?status[$ne]=x or
// {"phone": {"$gt": ""}} can't change what a database query matches.
// (Mongoose's global sanitizeFilter would also wrap our own $in/$ne filters.)

const MAX_DEPTH = 20;

function stripOperatorKeys(value, depth = 0) {
  if (!value || typeof value !== 'object' || depth > MAX_DEPTH) return value;
  if (Buffer.isBuffer(value)) return value;
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i += 1) value[i] = stripOperatorKeys(value[i], depth + 1);
    return value;
  }
  for (const key of Object.keys(value)) {
    if (key.startsWith('$')) {
      delete value[key];
    } else {
      value[key] = stripOperatorKeys(value[key], depth + 1);
    }
  }
  return value;
}

function stripOperatorKeysMiddleware(req, res, next) {
  stripOperatorKeys(req.query);
  stripOperatorKeys(req.body);
  next();
}

module.exports = { stripOperatorKeys, stripOperatorKeysMiddleware };
