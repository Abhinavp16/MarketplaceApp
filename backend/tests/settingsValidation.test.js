const assert = require('assert');
const { adminValidation } = require('../src/validations');

// PUT /admin/settings validates strictly (stripUnknown: false, see adminRoutes).
const validate = (body) => adminValidation.updateSettings.validate(body, { abortEarly: false, stripUnknown: false });

// The admin Banners page sends helper fields with each banner; saving must
// still work and those fields must not be stored.
const heroBanner = {
  _id: '6aa7f76e4bc7302f0b670c00',
  title: 'BRIGHTGUARD',
  subtitle: '',
  tag: 'Most popular',
  imageUrl: 'https://example.invalid/banner.webp',
  mediaType: 'image',
  videoUrl: '',
  linkUrl: '/product/abc',
  linkType: 'product',
  linkedProductId: 'abc',
  linkedBrandId: '',
  linkedCategoryId: '',
  buttonText: 'Shop Now',
  buttonIcon: 'ArrowRight',
  isActive: true,
  order: 2,
};
let result = validate({ heroBanners: [heroBanner], promoBanners: [{ ...heroBanner, title: 'Promo' }] });
assert.strictEqual(result.error, undefined, result.error && result.error.message);
for (const key of ['_id', 'linkType', 'linkedProductId', 'linkedBrandId', 'linkedCategoryId']) {
  assert.ok(!(key in result.value.heroBanners[0]), `hero ${key} dropped`);
  assert.ok(!(key in result.value.promoBanners[0]), `promo ${key} dropped`);
}
assert.deepStrictEqual([result.value.heroBanners[0].title, result.value.heroBanners[0].order], ['BRIGHTGUARD', 2]);

// Real problems are still refused.
result = validate({ heroBanners: [{ ...heroBanner, mediaType: 'video_upload', videoUrl: '' }] });
assert.ok(result.error, 'video banner without a video is refused');
result = validate({ heroBanners: [{ ...heroBanner, order: 1.5 }] });
assert.ok(result.error, 'non-integer order is refused');
// Unknown top-level settings are still refused.
assert.ok(validate({ somethingElse: true }).error);

console.log('settingsValidation tests passed');
