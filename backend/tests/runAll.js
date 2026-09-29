// Runs every tests/*.test.js file sequentially. Two of them (inventory,
// orderApproval) are integration tests that need the local demo MongoDB
// (npm run demo:mongo) and refuse to run against anything that is not a local
// "*demo*" database. Use SKIP_DB_TESTS=1 to run only the pure unit tests.
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DB_TESTS = new Set(['inventory.test.js', 'orderApproval.test.js']);
const files = fs.readdirSync(__dirname).filter((name) => name.endsWith('.test.js')).sort();

let failed = 0;
for (const file of files) {
  if (process.env.SKIP_DB_TESTS && DB_TESTS.has(file)) {
    console.log(`- skipping ${file} (SKIP_DB_TESTS)`);
    continue;
  }
  console.log(`\n=== ${file}`);
  const result = spawnSync(process.execPath, [path.join(__dirname, file)], { stdio: 'inherit' });
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
