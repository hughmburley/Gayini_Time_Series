"""Combination matrix over the built paddock set (R-7 step 2).

Scaling to 64 makes the least-exercised degradation paths the majority, so the question is not
"did it run" but "which branch did each unit actually take, and can every unit be placed".

Three binary axes, 8 cells:
    communities  single | multi        (multi drops nothing; single drops page 3)
    sites        none   | some
    map          c1     | locator      (and 'composition' if the locator is degenerate)

A UNIT THAT CANNOT BE PLACED IS A FINDING, NOT A ROUNDING. Any map_kind outside {c1, locator}
opens a ninth cell and is reported as such rather than folded into the nearest one.

Run:  python report_matrix.py            (from scripts/15_reports)
      python report_matrix.py --csv out.csv
"""
import argparse, collections, csv, glob, json, os, re, sys, zipfile
from config import DOCS_DIR, FIGS_DIR, UNITS_DIR

AXES = ('communities', 'sites', 'map')


def load():
    meta_path = os.path.join(FIGS_DIR, 'figs_meta.json')
    meta = json.load(open(meta_path, encoding='utf8')) if os.path.exists(meta_path) else {}
    rows = []
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        g = r['unit'].replace(' ', '_').replace('/', '-')
        m = meta.get(g, {})
        docx = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{g}.docx')
        rows.append({
            'unit': r['unit'], 'slug': g,
            'n_parts': r['n_parts'], 'n_sites': r['n_sites'],
            'area_ha': r['area_ha'],
            'communities': 'single' if r['n_parts'] == 1 else 'multi',
            'sites': 'none' if r['n_sites'] == 0 else 'some',
            'map': m.get('map_kind', 'MISSING'),
            'sites_drawn': m.get('sites_drawn'),
            'sites_expected': m.get('sites_expected'),
            'gap_source': r.get('gap_source', ''),
            'docx': docx if os.path.exists(docx) else None,
            'pages': page_count(docx) if os.path.exists(docx) else None,
        })
    return rows


def page_count(docx):
    """Explicit page breaks + 1. The builder paginates deliberately, so this is its intent."""
    x = zipfile.ZipFile(docx).read('word/document.xml').decode('utf8', 'replace')
    return x.count('w:br w:type="page"') + 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--csv', default=None)
    a = ap.parse_args()
    rows = load()
    print(f'{len(rows)} paddock reports\n')

    cells = collections.Counter((r['communities'], r['sites'], r['map']) for r in rows)
    expected_maps = {'c1', 'locator'}
    print(f'{"communities":12s} {"sites":6s} {"map":11s} {"n":>3s}   units')
    print('-' * 96)
    known = 0
    for comm in ('single', 'multi'):
        for st in ('none', 'some'):
            for mp in ('c1', 'locator'):
                k = (comm, st, mp)
                n = cells.get(k, 0)
                known += n
                names = [r['unit'] for r in rows if (r['communities'], r['sites'], r['map']) == k]
                shown = ', '.join(names[:6]) + (f' … +{len(names)-6}' if len(names) > 6 else '')
                flag = '   <-- NEVER BUILT BEFORE' if n and k in NEW_CELLS else ''
                print(f'{comm:12s} {st:6s} {mp:11s} {n:3d}   {shown}{flag}')
    print('-' * 96)
    print(f'{"":31s} {known:3d}   placed in the 8 cells')

    # a ninth cell is a finding
    extra = {k: v for k, v in cells.items() if k[2] not in expected_maps}
    if extra:
        print('\nNINTH CELL — units the 8-cell matrix cannot place:')
        for k, v in extra.items():
            names = [r['unit'] for r in rows if (r['communities'], r['sites'], r['map']) == k]
            print(f'   {k}  n={v}  {names}')
    else:
        print('\nno ninth cell: every unit placed, all map_kind values in {c1, locator}')

    # page model
    print('\npage counts by branch (spec: 4 single-community, 5 multi):')
    pc = collections.Counter((r['communities'], r['pages']) for r in rows)
    for (comm, pg), n in sorted(pc.items()):
        ok = (comm == 'single' and pg == 4) or (comm == 'multi' and pg == 5)
        print(f'   {comm:7s} {pg} pages  n={n:3d}   {"ok" if ok else "<-- OFF SPEC"}')

    if a.csv:
        with open(a.csv, 'w', newline='', encoding='utf8') as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            for r in sorted(rows, key=lambda r: r['unit']):
                w.writerow(r)
        print(f'\nwrote {a.csv}')


NEW_CELLS = {('single', 'none', 'c1'), ('multi', 'none', 'c1')}   # no-sites WITH a C1 render

if __name__ == '__main__':
    main()
