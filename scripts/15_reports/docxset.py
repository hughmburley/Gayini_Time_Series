"""Shared: enumerate built documents without tripping over Word lock files."""
import glob, os


def built_docx(directory, pattern='*.docx'):
    """Every built .docx, EXCLUDING Word's ~$ lock files.

    A lock file appears the moment someone opens a report in Word, is 162 bytes, is not a zip,
    and matches *.docx. It crashed three checkers with BadZipFile while Hugh had Bala 1 open.
    These tools run against a directory a human reads from, so tolerating that is part of the
    job — a check must not fail because someone is looking at the output.
    """
    return sorted(p for p in glob.glob(os.path.join(directory, pattern))
                  if not os.path.basename(p).startswith('~$'))
