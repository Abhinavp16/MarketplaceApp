const assert = require('assert');
const {
  bannerStoragePath,
  usedBannerPaths,
  replacedBannerPaths,
  withoutUnusedVideo,
} = require('../src/utils/bannerMedia');

// Our uploaded files, in every URL form storage produces.
assert.strictEqual(bannerStoragePath('https://storage.googleapis.com/demo-bucket.appspot.com/banners/a.mp4'), 'banners/a.mp4');
assert.strictEqual(bannerStoragePath('https://firebasestorage.googleapis.com/v0/b/demo-bucket.appspot.com/o/banners%2Fb.webp?alt=media&token=x'), 'banners/b.webp');
assert.strictEqual(bannerStoragePath('https://api.example.com/uploads/banners/c.webp'), 'banners/c.webp');
assert.strictEqual(bannerStoragePath('/uploads/banners/d.webp'), 'banners/d.webp');

// Never ours / never outside banners/.
assert.strictEqual(bannerStoragePath('https://www.youtube.com/watch?v=abc'), null);
assert.strictEqual(bannerStoragePath('https://storage.googleapis.com/demo-bucket.appspot.com/products/p.webp'), null);
assert.strictEqual(bannerStoragePath('https://api.example.com/uploads/banners/../products/p.webp'), null);
assert.strictEqual(bannerStoragePath('https://storage.googleapis.com/demo-bucket.appspot.com/banners/'), null);
assert.strictEqual(bannerStoragePath(''), null);
assert.strictEqual(bannerStoragePath(null), null);

const url = (name) => `https://storage.googleapis.com/bucket/banners/${name}`;

// Used files: images of all banners, videos only of uploaded-video banners.
{
  const used = usedBannerPaths({
    heroBanners: [
      { mediaType: 'image', imageUrl: url('hero.webp'), videoUrl: url('stale.mp4') },
      { mediaType: 'video_upload', videoUrl: url('clip.mp4') },
      { mediaType: 'youtube', videoUrl: 'https://youtu.be/abc' },
    ],
    promoBanners: [{ imageUrl: url('promo.webp') }],
  });
  assert.deepStrictEqual([...used].sort(), ['banners/clip.mp4', 'banners/hero.webp', 'banners/promo.webp']);
}

// Removing a banner, replacing a video, switching video -> YouTube.
{
  const before = {
    heroBanners: [
      { mediaType: 'video_upload', videoUrl: url('old.mp4') },
      { mediaType: 'video_upload', videoUrl: url('gone.mp4') },
      { mediaType: 'video_upload', videoUrl: url('switched.mp4') },
      { mediaType: 'image', imageUrl: url('kept.webp') },
    ],
    promoBanners: [{ imageUrl: url('promo.webp') }],
  };
  const after = {
    heroBanners: [
      { mediaType: 'video_upload', videoUrl: url('new.mp4') },
      { mediaType: 'youtube', videoUrl: 'https://youtu.be/abc' },
      { mediaType: 'image', imageUrl: url('kept.webp') },
    ],
    promoBanners: [],
  };
  assert.deepStrictEqual(replacedBannerPaths(before, after).sort(), [
    'banners/gone.mp4', 'banners/old.mp4', 'banners/promo.webp', 'banners/switched.mp4',
  ]);
  // Moving a file to another banner keeps it.
  assert.deepStrictEqual(replacedBannerPaths(
    { heroBanners: [{ mediaType: 'video_upload', videoUrl: url('x.mp4') }] },
    { heroBanners: [{ mediaType: 'image', imageUrl: 'y' }, { mediaType: 'video_upload', videoUrl: url('x.mp4') }] },
  ), []);
}

// Image banners drop a leftover video link; others are unchanged.
assert.deepStrictEqual(withoutUnusedVideo({ mediaType: 'image', videoUrl: url('v.mp4'), imageUrl: 'i' }), { mediaType: 'image', videoUrl: '', imageUrl: 'i' });
assert.deepStrictEqual(withoutUnusedVideo({ mediaType: 'youtube', videoUrl: 'https://youtu.be/abc' }), { mediaType: 'youtube', videoUrl: 'https://youtu.be/abc' });
assert.deepStrictEqual(withoutUnusedVideo({ imageUrl: 'i' }), { imageUrl: 'i' });

console.log('bannerMedia tests passed');
