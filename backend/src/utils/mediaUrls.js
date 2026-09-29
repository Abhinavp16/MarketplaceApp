function getRequestBaseUrl(req) {
  const forwardedProto = req.headers['x-forwarded-proto'];
  const protocol = (Array.isArray(forwardedProto) ? forwardedProto[0] : forwardedProto) || req.protocol || 'http';
  const host = req.get('host');
  return host ? `${protocol}://${host}` : '';
}

function normalizeMediaUrl(rawUrl, req) {
  const value = String(rawUrl || '').trim();
  if (!value) return '';

  const requestBaseUrl = getRequestBaseUrl(req);
  if (!requestBaseUrl) return value;

  if (value.startsWith('/')) {
    return `${requestBaseUrl}${value}`;
  }

  let sourceUrl;
  let targetUrl;
  try {
    sourceUrl = new URL(value);
    targetUrl = new URL(requestBaseUrl);
  } catch (_) {
    return value;
  }

  const isLoopbackHost =
    sourceUrl.hostname === 'localhost' || sourceUrl.hostname === '127.0.0.1';

  if (!isLoopbackHost) {
    return value;
  }

  sourceUrl.protocol = targetUrl.protocol;
  sourceUrl.hostname = targetUrl.hostname;
  sourceUrl.port = targetUrl.port;
  return sourceUrl.toString();
}

function normalizeImageObject(image, req) {
  if (!image || typeof image !== 'object') return image;
  return {
    ...image,
    url: normalizeMediaUrl(image.url, req),
  };
}

function normalizeProductMedia(product, req) {
  if (!product || typeof product !== 'object') return product;
  return {
    ...product,
    primaryImage: normalizeMediaUrl(product.primaryImage, req),
    image: normalizeMediaUrl(product.image, req),
    imageUrl: normalizeMediaUrl(product.imageUrl, req),
    images: Array.isArray(product.images)
      ? product.images.map((image) => normalizeImageObject(image, req))
      : product.images,
  };
}

module.exports = {
  getRequestBaseUrl,
  normalizeMediaUrl,
  normalizeImageObject,
  normalizeProductMedia,
};
