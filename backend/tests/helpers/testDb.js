// Safety rails for the database-backed tests. They create and delete data (a
// couple of them drop the whole database), so they only ever run against a
// MongoDB on this machine whose database name contains "test" (never the demo database itself).
//
// Run the whole suite against a throwaway mongod, e.g.:
//   TEST_MONGODB_URI=mongodb://127.0.0.1:27019/demomart_test npm test
// A test's own variable (e.g. INVENTORY_TEST_MONGODB_URI) wins over
// TEST_MONGODB_URI when both are set.

const LOCAL_URI = /^mongodb:\/\/(?:[^@/]*@)?(localhost|127\.0\.0\.1|\[::1\])(:\d+)?\/([^/?]+)/i;

function isSafeTestDatabase(uri) {
  const match = LOCAL_URI.exec(String(uri || '').trim());
  if (!match) return false;
  let name = match[3];
  try { name = decodeURIComponent(name); } catch { /* keep raw */ }
  return /test/i.test(name);
}

function testDatabaseUri(specificVariable) {
  const uri = (specificVariable && process.env[specificVariable]) || process.env.TEST_MONGODB_URI || '';
  return uri;
}

// Call right after connecting and before any wipe: the connected database must
// be a local "test" one, whatever the URI said.
function assertSafeToWipe(mongoose) {
  const { host, name } = mongoose.connection;
  const local = ['localhost', '127.0.0.1', '::1', '[::1]'].includes(String(host || '').toLowerCase());
  if (!local || !/test/i.test(String(name || ''))) {
    throw new Error(`Refusing to run: tests only use a local database whose name contains "test" (connected to ${host}/${name}).`);
  }
}

module.exports = { isSafeTestDatabase, testDatabaseUri, assertSafeToWipe };
