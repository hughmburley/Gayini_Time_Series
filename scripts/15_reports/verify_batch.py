"""Verify a rebuild reproduces the delivered documents.

Compares the whitespace-normalised visible text of each generated .docx against
EXPECTED_OUTPUT.json. Zip bytes differ run to run (timestamps); visible text must not.
A mismatch means a number, a caption or a degradation branch changed — investigate before
shipping, do not update the manifest to match.
"""
import hashlib, json, os, re, sys, zipfile
from config import DOCS_DIR

HERE = os.path.dirname(os.path.abspath(__file__))
exp = json.load(open(os.path.join(HERE, 'EXPECTED_OUTPUT.json')))


def fingerprint(path):
    x = zipfile.ZipFile(path).read('word/document.xml')
    t = re.sub(rb'<[^>]+>', b' ', x)
    return hashlib.sha256(re.sub(rb'\s+', b' ', t).strip()).hexdigest()


miss = diff = ok = 0
for d in exp['documents']:
    p = os.path.join(DOCS_DIR, d['document'])
    if not os.path.exists(p):
        print(f'  MISSING  {d["document"]}'); miss += 1; continue
    got = fingerprint(p)
    if got != d['text_sha256']:
        print(f'  CHANGED  {d["document"]}'); diff += 1
    else:
        ok += 1
print(f'\n{ok} match · {diff} changed · {miss} missing  (expected {exp["n"]}, built {exp["built"]})')
sys.exit(1 if (diff or miss) else 0)
