const logger = require('../../utils/logger');
const { BadRequestError } = require('../../utils/errors');
const { importWorkbook, MAX_ROWS } = require('../../services/catalogImportService');
const { createCatalogWorkbookBuffer } = require('../../utils/catalogImportWorkbook');

const XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

// @desc    Check (dryRun=true, the default) or run a catalog import from .xlsx/.csv
// @route   POST /api/v1/admin/products/import?dryRun=true|false&createMissing=true|false
// @access  Private/Admin
exports.importProducts = async (req, res, next) => {
  try {
    if (!req.file) {
      throw new BadRequestError('Attach an .xlsx or .csv file in the "file" field.', 'FILE_REQUIRED');
    }
    const { dryRun, createMissing, priceChangeMode } = req.query;

    const report = await importWorkbook(req.file.buffer, {
      filename: req.file.originalname,
      dryRun,
      createMissing,
      priceChangeMode,
      actorId: req.user?._id,
    });

    const { summary } = report;
    logger.info(
      `[CatalogImport] ${dryRun ? 'dry run' : 'import'} of "${req.file.originalname}" by ${req.user?._id}: `
      + `${summary.created} create, ${summary.updated} update, ${summary.skipped} unchanged, `
      + `${summary.errors} row(s) with errors, ${summary.warnings} with warnings, committed=${report.committed} (max ${MAX_ROWS} rows)`,
    );

    res.json({ success: true, data: report });
  } catch (error) {
    next(error);
  }
};

// @desc    Download the import template (Products + Notes sheets)
// @route   GET /api/v1/admin/products/import/template
// @access  Private/Admin
exports.downloadTemplate = async (req, res, next) => {
  try {
    const buffer = Buffer.from(await createCatalogWorkbookBuffer());
    res.setHeader('Content-Type', XLSX_CONTENT_TYPE);
    res.setHeader('Content-Disposition', 'attachment; filename="catalog-import-template.xlsx"');
    res.setHeader('Content-Length', buffer.length);
    res.send(buffer);
  } catch (error) {
    next(error);
  }
};
