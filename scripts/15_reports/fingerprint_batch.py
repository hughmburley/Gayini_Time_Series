"""Re-fingerprint EXPECTED_OUTPUT.json against the CURRENT build.

Deliberately a separate script from verify_batch.py, and deliberately requiring
--confirm. Regenerating the manifest to make a failing verify pass is the one move the
handoff forbids outright, so it must never be something you can do by reflex.

Run it only after you have:
  1. read the verify_batch.py output,
  2. diffed every CHANGED document and confirmed the change is explained,
  3. written that explanation into the change report.

The render inventory is recorded in built_with, because the fingerprints depend on it:
a unit with a C1 render produces a different map caption from one without, and a site
with a D2 render produces a different page-1 caption. A manifest without its inventory
cannot tell drift from a different input.

Run:  python fingerprint_batch.py --confirm --version 1.3 --note "..."
"""
import argparse, hashlib, json, os, re, sys, zipfile
from config import DOCS_DIR, FIGS_DIR
from docxset import built_docx

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, 'EXPECTED_OUTPUT.json')


def fingerprint(path):
    """Whitespace-normalised visible text. Zip bytes differ run to run; text must not."""
    x = zipfile.ZipFile(path).read('word/document.xml')
    t = re.sub(rb'<[^>]+>', b' ', x)
    return hashlib.sha256(re.sub(rb'\s+', b' ', t).strip()).hexdigest(), len(t)


def inventory():
    """What the figure layer actually resolved — read off disk, never typed.
    built_with.d2_renders_present was 11 in the shipped manifest against 10 delivered
    *_smap.png; a counted inventory cannot drift from the build it describes."""
    c1 = sorted(f[:-len('_mapc1.png')] for f in os.listdir(FIGS_DIR)
                if f.endswith('_mapc1.png'))
    d2 = sorted(f[:-len('_smap.png')] for f in os.listdir(FIGS_DIR)
                if f.endswith('_smap.png'))
    return {
        'c1_renders_present': c1,
        'c1_renders_count': len(c1),
        'd2_renders_present': len(d2),
        'd2_renders_units': d2,
        'note': ('Fingerprints depend on which C1/D2 renders resolve. A different render '
                 'inventory changes the map caption and the site page-1 caption, so '
                 'verify_batch will report CHANGED for affected units. That is an '
                 'explained input difference, not drift — confirm the diff is confined '
                 'to those strings, then re-fingerprint with the new inventory here.'),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--confirm', action='store_true',
                    help='required — regenerating the manifest is never automatic')
    ap.add_argument('--version', required=True, help='builder_version to record, e.g. 1.3')
    ap.add_argument('--built', default='', help='date to record (default: keep existing)')
    ap.add_argument('--note', default='', help='one line on why the fingerprints moved')
    a = ap.parse_args()

    if not a.confirm:
        sys.exit('STOP: --confirm required. Read verify_batch.py output and diff every\n'
                 '      CHANGED document before regenerating. Never re-fingerprint to\n'
                 '      make a failing check pass.')

    prev = json.load(open(MANIFEST, encoding='utf8')) if os.path.exists(MANIFEST) else {}

    docs = [os.path.basename(p) for p in built_docx(DOCS_DIR)]
    if not docs:
        sys.exit(f'STOP: no .docx under {DOCS_DIR}')

    entries, moved, new = [], 0, 0
    old = {d['document']: d['text_sha256'] for d in prev.get('documents', [])}
    for d in docs:
        h, n = fingerprint(os.path.join(DOCS_DIR, d))
        entries.append({'document': d, 'text_sha256': h, 'chars': n})
        if d not in old:
            new += 1
        elif old[d] != h:
            moved += 1

    out = {
        'built': a.built or prev.get('built', ''),
        'builder_version': a.version,
        'builder': 'scripts/15_reports',
        'n': len(entries),
        'built_with': inventory(),
        'note': ('text_sha256 is over the whitespace-normalised visible text of '
                 'word/document.xml. Zip bytes differ run to run (timestamps); visible '
                 'text must not.'),
        'documents': entries,
    }
    if a.note:
        out['supersedes'] = {'version': prev.get('builder_version', 'unknown'),
                             'reason': a.note,
                             'fingerprints_moved': moved, 'documents_added': new}

    json.dump(out, open(MANIFEST, 'w', encoding='utf8'), indent=1, ensure_ascii=False)
    print(f'  re-fingerprinted {len(entries)} documents at version {a.version}')
    print(f'  {moved} fingerprint(s) moved · {new} document(s) new')
    print(f'  inventory: {len(out["built_with"]["c1_renders_present"])} C1 · '
          f'{out["built_with"]["d2_renders_present"]} D2')


if __name__ == '__main__':
    main()
