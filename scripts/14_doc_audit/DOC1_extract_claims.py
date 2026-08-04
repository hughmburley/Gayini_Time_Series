"""DOC-1 Gate 0 - extract verifiable claims from the methods document.

READ-ONLY. Parses the .docx directly from OOXML (python-docx is not installed) and emits
Output/audit/DOC1_claim_check.csv, one row per quantitative or methodological claim.

Verdict columns are left EMPTY at Gate 0. Gates B and C populate them.

Classification is heuristic and is meant to be reviewed, not trusted blind:
  value       - reports a measured number or statistic
  structural  - a count, an extent, a scope, a field or object name
  method      - states how something was computed
  interpretive- a statement about meaning; recorded, not verified

Usage: python scripts/14_doc_audit/DOC1_extract_claims.py <docx> <out.csv>
"""
import zipfile, re, sys, csv, collections

# ---------------------------------------------------------------- docx -> blocks

def load_blocks(path):
    z = zipfile.ZipFile(path)
    xml = z.read('word/document.xml').decode('utf-8', 'replace')
    body = re.search(r'<w:body>(.*)</w:body>', xml, re.S).group(1)
    out = []
    for m in re.finditer(r'<w:(p|tbl)[ >].*?</w:\1>', body, re.S):
        frag, kind = m.group(0), m.group(1)
        if kind == 'tbl':
            for r in re.findall(r'<w:tr[ >].*?</w:tr>', frag, re.S):
                cells = [clean(c) for c in re.findall(r'<w:tc[ >].*?</w:tc>', r, re.S)]
                cells = [c for c in cells if c]
                if cells:
                    out.append(('table', ' | '.join(cells)))
            continue
        t = clean(frag)
        if not t:
            continue
        st = re.search(r'<w:pStyle w:val="([^"]+)"', frag)
        out.append((st.group(1) if st else 'Normal', t))
    return out

def clean(frag):
    t = ''.join(re.findall(r'<w:t[^>]*>(.*?)</w:t>', frag, re.S))
    t = re.sub(r'<[^>]+>', '', t)
    for a, b in (('&amp;', '&'), ('&lt;', '<'), ('&gt;', '>'), ('&quot;', '"'),
                 ('&#8217;', "'"), ('&#8216;', "'"), ('&#8211;', '-'), ('&#8212;', '-'),
                 ('&#8220;', '"'), ('&#8221;', '"'), ('&apos;', "'")):
        t = t.replace(a, b)
    return t.strip()

# ---------------------------------------------------------------- classification

METHOD_KW = re.compile(
    r'\b(regress\w*|ordinary least squares|OLS|fitted?|fitting|computed?|calculat\w*|'
    r'standardis\w*|z-score|correlation|Pearson|Spearman|GAM|generalised additive|'
    r'Kruskal|Theil|Mann-Kendall|Mann–Kendall|percentile|weighted|adjust\w*|threshold|'
    r'resampl\w*|bilinear|nearest neighbour|slope of|estimat\w*|derived|defined as|'
    r'is the sum of|pre-registered|cut of|test\b|rule\b|specification)\b', re.I)

STRUCT_KW = re.compile(
    r'\b(cells?|zones?|paddocks?|plots?|parts?|strata|stratum|communit\w+|ha\b|hectares?|'
    r'EPSG|grid|rows?|columns?|field|bands?|sites?|records?|years? of record|of 64|of 118|'
    r'of 115|of 24|of 66|comprises|covers)\b', re.I)

UNIT_PAT = [
    (r'pp/yr|percentage points? per year', 'pp/yr'),
    (r'percentage points?|\bpp\b', 'pp'),
    (r'\bha\b|hectares?', 'ha'),
    (r'%', '%'),
    (r'\bcells?\b', 'cells'),
    (r'\bm\b(?!\w)', 'm'),
]

NUM = re.compile(r'[-−+]?\d[\d,]*(?:\.\d+)?')

def has_num(s):
    return bool(NUM.search(s))

def classify(s, style):
    if style == 'table':
        return 'structural' if has_num(s) else 'interpretive'
    method = bool(METHOD_KW.search(s))
    struct = bool(STRUCT_KW.search(s))
    n = has_num(s)
    if method and not n:
        return 'method'
    if method and n:
        # a sentence that both states a procedure and reports its output
        return 'method' if re.search(
            r'\b(is|are|was|were)\s+(the\s+)?(sum|proportion|value|difference|'
            r'correlation|slope|percentile)|defined as|specification|rule\b', s, re.I) else 'value'
    if n and struct:
        return 'structural'
    if n:
        return 'value'
    return 'interpretive'

def units_of(s):
    return ';'.join(sorted({u for pat, u in UNIT_PAT if re.search(pat, s)}))

def values_of(s):
    return ';'.join(NUM.findall(s)[:12])

def sentences(t):
    # protect decimals, abbreviations and figure refs from the splitter
    p = re.sub(r'(\d)\.(\d)', r'\1<DOT>\2', t)
    p = re.sub(r'\b(Fig|No|approx|et al|e\.g|i\.e|Dr|vs)\.', r'\1<DOT>', p)
    parts = re.split(r'(?<=[.!?])\s+(?=[A-Z"\'(])', p)
    return [x.replace('<DOT>', '.').strip() for x in parts if x.strip()]

# ---------------------------------------------------------------- main

def main(docx, out):
    blocks = load_blocks(docx)
    section, fig, rows, i = 'front matter', '', [], 0
    in_toc = False
    verify_n = 0

    for style, text in blocks:
        if style.startswith('TOC'):
            in_toc = True
            continue
        if style.startswith('Heading'):
            in_toc = False
            section = text
            continue
        if in_toc or text.startswith('Right-click'):
            continue

        cap = re.match(r'^Figure\s+(\d{1,2})\.\s', text)
        if cap:
            fig = f"Figure {cap.group(1)}"

        verify = text.startswith('VERIFY')
        if verify:
            verify_n += 1
        # Bare citations are bibliographic metadata, not claims. The closing VERIFY
        # passage in References IS a claim and is kept.
        if section.startswith('References') and not verify:
            continue

        for s in sentences(text):
            if len(s) < 25:
                continue
            ctype = classify(s, style)
            # keep every numeric/method claim; keep interpretive only alongside numbers
            if ctype == 'interpretive' and not verify and not has_num(s):
                continue
            i += 1
            rows.append({
                'claim_id': f'DOC1-{i:03d}',
                'section': section,
                'page_ref': '',
                'claim_text': s,
                'claim_type': ctype,
                'stated_value': values_of(s),
                'stated_units': units_of(s),
                'figure_ref': fig if (cap or style != 'table') else '',
                'verdict': '',
                'found_value': '',
                'source_object': '',
                'source_query': '',
                'evidence': '',
                'notes': f'VERIFY flag {verify_n}' if verify else ('caption' if cap else
                         ('table row' if style == 'table' else '')),
            })

    cols = ['claim_id', 'section', 'page_ref', 'claim_text', 'claim_type', 'stated_value',
            'stated_units', 'figure_ref', 'verdict', 'found_value', 'source_object',
            'source_query', 'evidence', 'notes']
    with open(out, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)

    print(f"claims extracted: {len(rows)}\nwritten: {out}\n")
    by_type = collections.Counter(r['claim_type'] for r in rows)
    print("BY TYPE")
    for k, v in by_type.most_common():
        print(f"  {k:14s} {v:4d}")
    print("\nBY SECTION")
    for k, v in collections.Counter(r['section'] for r in rows).items():
        t = collections.Counter(r['claim_type'] for r in rows if r['section'] == k)
        detail = ' '.join(f"{a[:4]}={b}" for a, b in sorted(t.items()))
        print(f"  {v:4d}  {k[:52]:54s} {detail}")
    vrows = [r for r in rows if r['notes'].startswith('VERIFY flag')]
    print(f"\nVERIFY-flagged rows: {len(vrows)} across "
          f"{len({r['notes'] for r in vrows})} distinct passages")
    print(f"caption rows       : {sum(1 for r in rows if r['notes'] == 'caption')}")
    print(f"table rows         : {sum(1 for r in rows if r['notes'] == 'table row')}")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
