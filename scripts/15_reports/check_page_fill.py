"""Render the report .docx files and report how far content reaches down each page.

Above 92% is an ERROR and fails the build — Word spills content to a phantom page.
Below 70% is a WARN and never fails the build — dead space is a design observation,
not a defect. Between the two, nothing is reported.

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
from docxset import built_docx

# --- R-1, 4 August 2026: the band conflated a functional failure with an aesthetic one ---
# It was stated three ways — 70-90 in the handoff and template spec, 80-92 here, and 68-93 in
# the design seat's in-session QA, which is what produced "0 of 32 outside tolerance". One
# instrument measured, another was documented, a third asserted the pass; the claim that all
# 32 documents sat inside the band was not true under any of them.
#
# Only the upper bound has a failure mode behind it: above SPILL, Word pushes content to a
# phantom page. Below DEAD is dead space — a design observation, not a defect. Failing a build
# on 42 of 83 pages for whitespace produces a permanently-red check, and I-11 applies to
# permanently-red exactly as it does to permanently-green.
SPILL = .92     # ERROR — real failure mode, fails the build
DEAD  = .70     # WARN  — reported, never fails the build
# Nothing between DEAD and SPILL is reported at all.


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

    docs = sys.argv[1:] or built_docx(DOCS_DIR)
    if not docs:
        sys.exit(f'STOP: no .docx to check in {DOCS_DIR}. A check that scans nothing '
                 f'must not report success.')

    n_pages = 0
    errors, warns = [], []
    with tempfile.TemporaryDirectory() as tmp:
        for d in docs:
            stem = os.path.splitext(os.path.basename(d))[0]
            pdf = os.path.join(tmp, f'{stem}.pdf')
            # Retry once. Over an 89-document batch soffice failed on exactly one file
            # ("Could not find platform independent libraries") and converted it cleanly on
            # its own — a transient in LibreOffice's startup, not a defect in the document.
            # Reporting that as an ERROR would fail a build for something no one can fix.
            # Two attempts, and only then an error, so a genuinely broken document still fails.
            for attempt in (1, 2):
                r = subprocess.run([soffice, '--headless', '--convert-to', 'pdf',
                                    '--outdir', tmp, d], capture_output=True, text=True)
                if os.path.exists(pdf):
                    if attempt == 2:
                        print(f'  {stem}: converted on retry')
                    break
            if not os.path.exists(pdf):
                errors.append((stem, '-', 0.0, 'PDF CONVERSION FAILED (2 attempts)'))
                print(f'\n{stem}\n  conversion failed twice: {r.stderr.strip()[:200]}')
                continue
            subprocess.run([pdftoppm, '-png', '-r', '100', pdf,
                            os.path.join(tmp, stem)], check=True)
            for f in sorted(glob.glob(os.path.join(tmp, f'{stem}-*.png'))):
                im = np.array(Image.open(f).convert('RGB')).astype(int)
                nonwhite = im.sum(axis=2) < 750
                rows = np.where(nonwhite.sum(axis=1) > 10)[0]
                frac = rows.max() / im.shape[0] if len(rows) else 0
                n_pages += 1
                page = os.path.basename(f)
                if frac > SPILL:
                    errors.append((stem, page, frac, 'may spill in Word'))
                elif frac < DEAD:
                    warns.append((stem, page, frac, 'dead space'))

    print(f'{n_pages} pages across {len(docs)} documents')
    print(f'  {len(errors)} above {SPILL*100:.0f}% (ERROR — Word spills to a phantom page)')
    print(f'  {len(warns)} below {DEAD*100:.0f}% (warn — dead space, not a defect)')
    if warns:
        print('\ndead space (advisory):')
        for stem, page, frac, _ in warns:
            print(f'   {stem:44s} {page:24s} {frac*100:5.0f}%')
    if errors:
        print('\nFAIL — these pages will spill in Word:')
        for stem, page, frac, verdict in errors:
            print(f'   {stem:44s} {page:24s} {frac*100:5.0f}%  {verdict}')
    else:
        print('\nno page at spill risk')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
