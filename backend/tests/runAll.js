// Runs every tests/*.test.js file sequentially. Many of them also have a
// database-backed part. That part runs only when a local MongoDB is given and
// its database name contains "test" (see tests/helpers/testDb.js):
//
//   TEST_MONGODB_URI=mongodb://127.0.0.1:27019/demomart_test?replicaSet=rs0 npm test
//
// Without it those parts are skipped (each test says so). SKIP_DB_TESTS=1
// forces the pure unit tests only, even if a URI is set.
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DB_TESTS = new Set(['inventory.test.js', 'orderApproval.test.js']);
const childEnv = { ...process.env };
if (process.env.SKIP_DB_TESTS) {
  for (const key of Object.keys(childEnv)) {
    if (key === 'TEST_MONGODB_URI' || key.endsWith('_TEST_MONGODB_URI')) delete childEnv[key];
  }
}
const files = fs.readdirSync(__dirname).filter((name) => name.endsWith('.test.js')).sort();

let failed = 0;
for (const file of files) {
  if (process.env.SKIP_DB_TESTS && DB_TESTS.has(file)) {
    console.log(`- skipping ${file} (SKIP_DB_TESTS)`);
    continue;
  }
  console.log(`\n=== ${file}`);
  const result = spawnSync(process.execPath, [path.join(__dirname, file)], { stdio: 'inherit', env: childEnv });
  if (result.status !== 0) {
    failed += 1;
    console.error(`FAILED: ${file}`);
  }
}

if (failed > 0) {
  console.error(`\n${failed} test file(s) failed`);
  process.exit(1);
}
console.log('\nAll test files passed');
