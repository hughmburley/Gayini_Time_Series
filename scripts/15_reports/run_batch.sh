#!/usr/bin/env bash
# Gayini report batch — full chain. Usage:
#   ./run_batch.sh                     the 32-document set delivered 4 Aug
#   GAYINI_ROOT=/path/to/repo ./run_batch.sh
#
# The lint runs FIRST and is fatal. It checks four things, each of which has stood in for
# a derived value in this code at some point: digit literals in client prose, ${...} inside
# a quoted JS string (which renders literally), counts recorded about the build that
# disagree with the build, and companion files read but never produced.
set -euo pipefail
cd "$(dirname "$0")"

PADDOCKS=("Bala 26ca" "Bala 27ca" "Bala 28ca" "Bala 29ca" "Bala 15" "Dinan 10" "Dinan 8")
SITES=(GA_001 GA_002 GA_057 GA_003 GA_004 GA_005 GA_006 GA_007 GA_053 GA_054 GA_066 \
       GA_008 GA_009 GA_010 GA_034 GA_035 GA_036 GA_043 GA_055 GA_056 GA_058 \
       GA_025 GA_026 GA_027 GA_028)

echo "== 0/5  pre-batch lint"
python lint_builder.py

echo "== 1/5  data layer (registry asserts + contract canaries)"
python report_data.py --paddocks "${PADDOCKS[@]}" --sites "${SITES[@]}"
echo "== 2/5  figures"
python report_figs.py
echo "== 3/5  documents"
node report_build.js

echo "== 4/5  reproduction check"
if ! python verify_batch.py; then
  echo
  echo "verify_batch reported a difference. Diff every CHANGED document and explain it"
  echo "before going near fingerprint_batch.py. Do NOT re-fingerprint to make this pass."
  echo "A run that emitted literal template source into two client documents was caught"
  echo "here, and only because the fingerprints were compared rather than regenerated."
fi

echo "== 5/5  render QA"
python check_page_fill.py
echo "done."
