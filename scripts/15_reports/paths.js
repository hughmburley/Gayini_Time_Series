// Path resolution for report_build.js — reads the same paths.json as config.py.
const fs = require('fs'), path = require('path');
const HERE = __dirname;
const cfg = JSON.parse(fs.readFileSync(path.join(HERE, 'paths.json')));
const ROOT = (process.env.GAYINI_ROOT || cfg.repo_root).replace(/[\/\\]+$/, '');
const p = k => path.normalize(cfg[k].replace('{repo_root}', ROOT));
module.exports = {
  ROOT,
  DB: p('db'),
  UNITS_DIR: p('units_dir'),
  FIGS_DIR: p('figs_dir'),
  DOCS_DIR: p('docs_dir'),
};
