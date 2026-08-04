"""Render the report .docx files and report how far content reaches down each page.

Targets: 82-90% is right. >92% will probably spill in Word. <80% is dead space.
Measures NON-WHITE (the figure canvas is warm cream and a dark-ink threshold
reads it as an empty page).

This is the check that catches the load-bearing image-height trap: a `spacing.line` on
an image paragraph renders the picture at ~1/3 height while the XML extent stays
correct, so pages read two-thirds empty. Nothing else in the toolchain sees that.

--- v1.3: the check could not run, could not scan, and could not fail ---
It hardcoded SOFFICE = "/mnt/skills/public/docx/scripts/office/soffice.py", a path from
the design seat's own sandbox, while PLACEMENT.md promised nothing outside paths.json
hardcodes a path. With no arguments it globbed "*_DRAFT.docx" in the CWD, which matches
nothing this batch produces, so it printed nothing and exited 0 — a pass that had
scanned zero pages. It now resolves soffice, defaults to DOCS_DIR, writes intermediates
to a temp directory, and EXITS NON-ZERO when a page is outside the band.

Run:  python check_page_fill.py                 (all documents in DOCS_DIR)
      python check_page_fill.py path/to.docx    (specific files)
"""
import glob, os, shutil, subprocess, sys, tempfile
import numpy as np
from PIL import Image
from config import DOCS_DIR

DEAD, SPILL = .80, .92          # unchanged from the delivered thresholds

# NOTE for the design seat: the handoff §7 states the band as "70-90%, above ~93% Word
# spills". This script has always used 80/92. The two do not agree. Preserved as-is
# rather than silently retuned — the band is a QA judgement, not a build decision.


def find_soffice():
    """PATH first, then the usual Windows/macOS/Linux install locations."""
    exe = shutil.which('soffice') or shutil.which('soffice.exe')
    if exe:
        return exe
    for p in (r'C:\Program Files\LibreOffice\program\soffice.exe',
              r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
              '/Applications/LibreOffice.app/Contents/MacOS/soffice',
              '/usr/bin/soffice', '/usr/local/bin/soffice'):
        if os.path.exists(p):
            return p
    return None


def find_pdftoppm():
    exe = shutil.which('pdftoppm') or shutil.which('pdftoppm.exe')
    if exe:
        return exe
    hits = glob.glob(os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Microsoft',
                                  'WinGet', 'Packages', '*Poppler*', '**', 'pdftoppm.exe'),
                     recursive=True)
    return hits[0] if hits else None


def main():
    soffice, pdftoppm = find_soffice(), find_pdftoppm()
    if not soffice:
        sys.exit('STOP: LibreOffice (soffice) not found. The page-fill band cannot be '
                 'measured without it, and it is the only check that sees the image-height '
                 'trap. Install LibreOffice or put soffice on PATH.')
    if not pdftoppm:
        sys.exit('STOP: pdftoppm (Poppler) not found. Install Poppler or put it on PATH.')

    docs = sys.argv[1:] or sorted(glob.glob(os.path.join(DOCS_DIR, '*.docx')))
    if not docs:
        sys.exit(f'STOP: no .docx to check in {DOCS_DIR}. A check that scans nothing '
                 f'must not report success.')

    n_pages = 0
    bad = []
    with tempfile.TemporaryDirectory() as tmp:
        for d in docs:
            stem = os.path.splitext(os.path.basename(d))[0]
            r = subprocess.run([soffice, '--headless', '--convert-to', 'pdf',
                                '--outdir', tmp, d], capture_output=True, text=True)
            pdf = os.path.join(tmp, f'{stem}.pdf')
            if not os.path.exists(pdf):
                bad.append((stem, '-', 0.0, 'PDF CONVERSION FAILED'))
                print(f'\n{stem}\n  conversion failed: {r.stderr.strip()[:200]}')
                continue
            subprocess.run([pdftoppm, '-png', '-r', '100', pdf,
                            os.path.join(tmp, stem)], check=True)
            print(f'\n{stem}')
            for f in sorted(glob.glob(os.path.join(tmp, f'{stem}-*.png'))):
                im = np.array(Image.open(f).convert('RGB')).astype(int)
                nonwhite = im.sum(axis=2) < 750
                rows = np.where(nonwhite.sum(axis=1) > 10)[0]
                frac = rows.max() / im.shape[0] if len(rows) else 0
                verdict = ('dead space' if frac < DEAD else
                           'may spill in Word' if frac > SPILL else 'ok')
                n_pages += 1
                if verdict != 'ok':
                    bad.append((stem, os.path.basename(f), frac, verdict))
                print(f'  {os.path.basename(f):40s} {frac*100:5.0f}%   {verdict}')

    print(f'\n{n_pages} pages across {len(docs)} documents · '
          f'{len(bad)} outside the {DEAD*100:.0f}-{SPILL*100:.0f}% band')
    if bad:
        print('\noutside the band:')
        for stem, page, frac, verdict in bad:
            print(f'   {stem:44s} {page:24s} {frac*100:5.0f}%  {verdict}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
