#!/usr/bin/env node
/**
 * Catalog import from an Excel (.xlsx) or CSV file.
 *
 *   npm run catalog:import -- path/to/file.xlsx [--dry-run] [--create-missing]
 *                             [--price-change-mode immediate|schedule_24h]
 *                             [--actor admin@example.com] [--json]
 *
 *   --dry-run          check the file and print the report; write nothing
 *   --create-missing   create brands and categories that do not exist yet
 *   --price-change-mode  how price changes on existing products apply
 *                      (default immediate; schedule_24h applies them in 24 hours)
 *   --actor <email>    admin user recorded in the price history / audit log
 *   --json             print the report as JSON instead of text
 *
 * Reads .env like the other scripts and connects through src/config/database.
 * In DEMO_MODE it refuses to run unless assertDemoDatabase() passes (local
 * database whose name contains "demo"). Exit code: 0 = ok, 1 = the file has
 * errors (nothing was written), 2 = could not run.
 *
 * Columns, rules and the template: see "Catalog import" in README.md.
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const HELP = `Usage: npm run catalog:import -- <file.xlsx|file.csv> [--dry-run] [--create-missing]
       [--price-change-mode immediate|schedule_24h] [--actor <admin email>] [--json]`;

function parseArgs(argv) {
  const options = { file: null, dryRun: false, createMissing: false, priceChangeMode: 'immediate', actor: null, json: false, help: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const value = () => {
      if (arg.includes('=')) return arg.slice(arg.indexOf('=') + 1);
      i += 1;
      return argv[i];
    };
    if (arg === '--dry-run') options.dryRun = true;
    else if (arg === '--create-missing') options.createMissing = true;
    else if (arg === '--json') options.json = true;
    else if (arg === '--help' || arg === '-h') options.help = true;
    else if (arg.startsWith('--price-change-mode')) options.priceChangeMode = value();
    else if (arg.startsWith('--actor')) options.actor = value();
    else if (arg.startsWith('-')) throw new Error(`Unknown option ${arg}`);
    else if (!options.file) options.file = arg;
    else throw new Error(`Unexpected extra argument ${arg}`);
  }
  return options;
}

const pad = (text, width) => String(text).padEnd(width);
const shorten = (value, max = 70) => {
  const text = String(value ?? '');
  return text.length > max ? `${text.slice(0, max - 3)}...` : text;
};

function printReport(report, { dryRun }) {
  const { summary } = report;
  console.log('');
  console.log(`${dryRun ? 'DRY RUN - nothing was written' : (report.committed ? 'IMPORT COMMITTED' : 'IMPORT REFUSED - nothing was written')}`);
  if (report.ignoredColumns?.length) console.log(`Ignored columns: ${report.ignoredColumns.join(', ')}`);
  console.log('');
  console.log(`${pad('Row', 5)} ${pad('SKU', 18)} ${pad('Action', 7)} ${pad('Result', 8)} Details`);
  console.log('-'.repeat(100));
  for (const row of report.rows) {
    const result = row.status === 'error' ? 'ERROR' : (row.status === 'warning' ? 'warning' : 'ok');
    const detail = row.note || (row.action === 'update' && row.changes.length
      ? `changes: ${row.changes.map((change) => change.column).join(', ')}`
      : (row.normalized.name ? shorten(row.normalized.name, 50) : ''));
    console.log(`${pad(row.row, 5)} ${pad(shorten(row.sku, 18), 18)} ${pad(row.action, 7)} ${pad(result, 8)} ${detail}`);
    for (const error of row.errors) console.log(`        ERROR   ${error.column}: ${error.message}`);
    for (const warning of row.warnings) console.log(`        warning ${warning.column}: ${warning.message}`);
  }
  console.log('-'.repeat(100));
  if (report.newBrands?.length) console.log(`${report.committed ? 'Created' : 'Would create'} brands: ${report.newBrands.join(', ')}`);
  if (report.newCategories?.length) console.log(`${report.committed ? 'Created' : 'Would create'} categories: ${report.newCategories.join('; ')}`);
  const verb = report.committed ? '' : 'would be ';
  console.log(`${summary.totalRows} row(s): ${summary.created} ${verb}created, ${summary.updated} ${verb}updated, ${summary.skipped} unchanged, `
    + `${summary.errors} with errors, ${summary.warnings} with warnings.`);
  if (summary.errors > 0) console.log('The file has errors, so nothing is imported. Fix the rows above and run again.');
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help || !options.file) {
    console.log(HELP);
    return options.help ? 0 : 2;
  }

  const { isDemoMode, assertDemoDatabase } = require('../src/config/demoGuard');
  if (isDemoMode()) assertDemoDatabase();

  const mongoose = require('mongoose');
  const connectDB = require('../src/config/database');
  await connectDB();
  if (isDemoMode()) assertDemoDatabase({ actualDbName: mongoose.connection.name });

  try {
    const { User } = require('../src/models');
    let actorId = null;
    if (options.actor) {
      const actor = await User.findOne({ email: String(options.actor).trim().toLowerCase(), role: 'admin' }).select('_id').lean();
      if (!actor) throw new Error(`No admin user with email ${options.actor}`);
      actorId = actor._id;
    }

    const { importWorkbook } = require('../src/services/catalogImportService');
    const report = await importWorkbook(path.resolve(options.file), {
      dryRun: options.dryRun,
      createMissing: options.createMissing,
      priceChangeMode: options.priceChangeMode,
      actorId,
      awaitFollowUps: true,
    });

    if (options.json) console.log(JSON.stringify(report, null, 2));
    else printReport(report, { dryRun: options.dryRun });
    return report.summary.errors > 0 ? 1 : 0;
  } finally {
    await mongoose.connection.close().catch(() => {});
  }
}

main()
  .then((code) => process.exit(code))
  .catch((error) => {
    console.error(`\ncatalog:import failed: ${error.message}`);
    process.exit(2);
  });
