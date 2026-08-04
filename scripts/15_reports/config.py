"""Path resolution for the report builder. Every script reads this; nothing hardcodes a path.

Override the repo root at run time with the GAYINI_ROOT environment variable:
    GAYINI_ROOT=/mnt/d/Github_repos/Gayini python report_data.py --paddocks "Bala 29ca"
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
_cfg = json.load(open(os.path.join(HERE, 'paths.json')))
ROOT = os.environ.get('GAYINI_ROOT', _cfg['repo_root']).rstrip('/\\')


def _p(key):
    return os.path.normpath(_cfg[key].replace('{repo_root}', ROOT))


DB        = _p('db')
GPKG      = _p('gpkg')
FIGSRC_C1 = _p('figure_source_c1')
FIGSRC_D2 = _p('figure_source_d2')
UNITS_DIR = _p('units_dir')
FIGS_DIR  = _p('figs_dir')
DOCS_DIR  = _p('docs_dir')

for d in (UNITS_DIR, FIGS_DIR, DOCS_DIR):
    os.makedirs(d, exist_ok=True)


def require(path, what):
    if not os.path.exists(path):
        sys.exit(f'STOP: {what} not found at {path}\n'
                 f'      Set GAYINI_ROOT or edit paths.json. Current root: {ROOT}')
    return path
