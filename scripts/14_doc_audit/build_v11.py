#!/usr/bin/env python3
"""
Gayini methods document — V10 -> V11 producer.

Deterministic. Re-runnable. Every edit is declared in ORDERED_OPS below and traces
to a row of Gayini_V10_to_V11_change_list.md.

Input : unpacked/  (V10 unzipped, runs merged)
Output: Gayini_RS_methods_doc_V11.docx

NOT a hand edit. Do not edit the .docx; edit this script and re-run.
"""
import re, sys, uuid

SRC = 'unpacked/word/document.xml'

RPR = '<w:rPr><w:rFonts w:ascii="Calibri" w:eastAsia="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/></w:rPr>'
RPR_B = '<w:rPr><w:rFonts w:ascii="Calibri" w:eastAsia="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/></w:rPr>'
RPR_I = '<w:rPr><w:rFonts w:ascii="Calibri" w:eastAsia="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:i/></w:rPr>'


def norm(t):
    """Collapse the soft line breaks that come from reading the doc as markdown."""
    return ' '.join(t.split())


def variants(t):
    """Markdown extraction renders em/en dashes as --- / --. Try the real characters."""
    t = norm(t)
    out = [t]
    for a, b in (('---', '\u2014'), ('--', '\u2013'), ('--', '\u2212'), ("'", '\u2019')):
        out += [v.replace(a, b) for v in list(out) if a in v]
    seen, uniq = set(), []
    for v in out:
        if v not in seen:
            seen.add(v); uniq.append(v)
    return uniq


def locate(x, marker):
    for v in variants(marker):
        i = x.find(v)
        if i >= 0:
            return i, v
    return -1, None


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def pid():
    return format(uuid.uuid4().int % 0x7FFFFFFF | 0x1000000, '08X')


def run(text, bold=False, ital=False):
    rpr = RPR_B if bold else (RPR_I if ital else RPR)
    return f'<w:r>{rpr}<w:t xml:space="preserve">{esc(text)}</w:t></w:r>'


def para(*parts):
    """parts: str (plain) or ('b', str) / ('i', str)"""
    runs = ''
    for p in parts:
        if isinstance(p, tuple):
            runs += run(p[1], bold=(p[0] == 'b'), ital=(p[0] == 'i'))
        else:
            runs += run(p)
    return (f'<w:p w14:paraId="{pid()}" w14:textId="77777777" w:rsidR="008E2085" '
            f'w:rsidRDefault="00E273A2"><w:pPr><w:keepLines/>'
            f'<w:spacing w:after="130" w:line="276" w:lineRule="auto"/></w:pPr>{runs}</w:p>')


_BM = [900]


def heading2(text):
    _BM[0] += 1
    b = _BM[0]
    return (f'<w:p w14:paraId="{pid()}" w14:textId="77777777" w:rsidR="008E2085" '
            f'w:rsidRDefault="00E273A2"><w:pPr><w:pStyle w:val="Heading2"/><w:keepLines/>'
            f'<w:spacing w:before="250" w:after="120"/></w:pPr>'
            f'<w:bookmarkStart w:id="{b}" w:name="_Toc9{b}"/>'
            f'<w:r><w:t xml:space="preserve">{esc(text)}</w:t></w:r>'
            f'<w:bookmarkEnd w:id="{b}"/></w:p>')


def para_span(x, marker):
    """Return (start, end) char offsets of the <w:p> element containing marker."""
    i, _ = locate(x, marker)
    if i < 0:
        raise SystemExit(f'MARKER NOT FOUND: {norm(marker)[:70]!r}')
    s = x.rfind('<w:p ', 0, i)
    e = x.find('</w:p>', i) + len('</w:p>')
    return s, e


# ────────────────────────────────────────────────────────────────────────
# operations
# ────────────────────────────────────────────────────────────────────────

def op_text(old, new, count=1):
    def f(x):
        i, found = locate(x, old)
        if i < 0:
            raise SystemExit(f'TEXT NOT FOUND: {norm(old)[:70]!r}')
        return x.replace(found, norm(new))
    return f


def op_insert_after(marker, xml):
    def f(x):
        s, e = para_span(x, marker)
        return x[:e] + xml + x[e:]
    return f


def op_replace_block(start_marker, end_marker, xml):
    def f(x):
        s, _ = para_span(x, start_marker)
        _, e = para_span(x, end_marker)
        if e <= s:
            raise SystemExit(f'BLOCK ORDER WRONG: {start_marker[:40]!r}')
        return x[:s] + xml + x[e:]
    return f


# ── new §4.2 subsection: two footprints ────────────────────────────────
FOOTPRINTS = (
    heading2('4.2b Two footprints')
    + para(('b', 'Flood frequency is measured over two different pixel sets, and they are not '
                 'interchangeable. '),
           'The census footprint is the pixel-weighted mean over a unit\u2019s non-treed strata in '
           'census_by_zone_stratum. It is the standing basis: registered, and used by Figure 28 and '
           'by every rank and residual in this document. The polygon footprint is every valid raster '
           'cell inside the zone boundary, regardless of vegetation mapping or treed status. It is '
           'used by the unit dashboards of Section 8, because a dashboard locates the whole unit '
           'rather than its analysable subset.')
    + para('The two coincide where a paddock\u2019s boundary lies wholly inside mapped, non-treed '
           'country, and diverge where it does not. ',
           ('b', 'For Bala 29ca they read 8.5% and 10.3% respectively'),
           ', because its boundary encloses unmapped and context cells that are wetter than its '
           'mapped country. For Bala 23 the two are identical at 38.6%. Neither value is wrong; a '
           'value quoted without its footprint is.')
)

# ── new §4.6 subsection: how a number is formed ────────────────────────
FORMED = (
    heading2('4.6 How a number is formed')
    + para('Section 4.5 states the unit a measurement applies to. This section states how '
           'measurements were combined to reach it. Three conventions are recorded here because '
           'three separate discrepancies in this assessment were the same failure: one name '
           'covering several quantities.')
    + para(('b', 'Aggregation order. '),
           'The same support admits several defensible aggregations that give materially different '
           'answers. Whole-property mean inundation across the four post-management water years '
           'reads 43.64% pixel-weighted \u2014 summing wet and valid cells across the property, then '
           'dividing \u2014 45.97% as a mean of paddock means, and 37.94% as an unweighted mean of the '
           '118 zone-by-community stratum means. The spread is 8.0 percentage points. The three '
           'answer different questions: what the property does, what the average paddock does, and '
           'what the average stratum does. Only the first is the property\u2019s inundation. Every ratio '
           'in this document is pixel-weighted unless stated otherwise, and where a quantity has more '
           'than one defensible aggregation its order is given in the same sentence as its value.')
    + para(('b', 'Rounding order. '),
           'Values are rounded once, from source. The results registry stores pinned values at two '
           'decimal places, and re-rounding a pinned value can shift the last digit: an adjusted '
           'difference of 7.947 is +7.9 at one decimal place, while the pinned 7.95 would give +8.0. '
           'A value in this document that disagrees with the registry in its last digit has been '
           'rounded once and the registry twice.')
    + para(('b', 'Counting basis. '),
           'A count of units may be taken on geometry \u2014 the parts that exist \u2014 or on support \u2014 the '
           'parts that clear the minimum of 30 valid cells. Both are legitimate and they differ. '
           'Bala 28ca holds an Aeolian portion of 10 cells, so a geometric count of conserved Aeolian '
           'units is two and a supported count is one. Wherever a count appears, its basis is named.')
)

# ── Figure 21 passage ──────────────────────────────────────────────────
FIG21 = (
    para(('b', 'What the figure compares. '),
         'Each coloured line is one conserved paddock\u2019s portion of one vegetation community, year '
         'by year. The grey band covers the middle half of the grazed portions of that same '
         'community \u2014 a quarter sit above it and a quarter below \u2014 with the median drawn through it. '
         'A line inside the band is behaving like ordinary grazed country of its kind. Both the '
         'lines and the band are computed on the paddock-community part, at a minimum of 30 valid '
         'cells per part-year, so the comparison is like for like.')
    + para('The unit is the part rather than the whole paddock, so a paddock appears in every '
           'community it holds. Bala 29ca holds all three in near-equal proportion and appears in all '
           'three panels. Bala 26ca and Bala 28ca each hold a Riverine portion alongside their Inland '
           'one and appear in both. Bala 27ca is entirely Inland Floodplain and appears once. ',
           ('b', 'The Aeolian panel carries a single conserved line, Bala 29ca\u2019s'),
           ' \u2014 not because Bala 28ca holds no Aeolian country, but because its Aeolian portion is 10 '
           'cells and falls below the support rule. No comparison within that panel is a comparison '
           'between paddocks.')
    + para(('b', 'Two arms, not three. '),
           'The grey band is the 14-day rotational paddocks. The third management arm \u2014 the unzoned '
           'country carrying standard grazing \u2014 has no mapped boundary and is absent from this figure '
           'entirely. Figure 26 draws all three, and the unzoned arm sits at or above the rotational '
           'band in most strata. A reader taking this page alone forms a two-arm picture that Figure '
           '26 corrects.')
    + para(('b', 'What it shows. '),
           'In Inland Floodplain country the conserved parts other than Bala 29ca\u2019s sit inside the '
           'grazed band across the record. Bala 29ca\u2019s Inland part sits below it in several dry '
           'periods. In Aeolian and Riverine country Bala 29ca\u2019s parts sit well below the band '
           'throughout, and rise toward it at +0.919 percentage points a year.')
    + para('That rise begins in the early part of the record, roughly thirty years before '
           'conservation management commenced. Whatever explains it, the present grazing arrangement '
           'does not.')
    + para(('b', 'What it does not show. '),
           'Nothing here separates the two management categories. That is a description of this '
           'figure, not a finding about grazing: the comparison rests on four conserved paddocks '
           'against sixty grazed ones, the conserved four are not distributed across the hydrological '
           'range, and no stocking record or cultivation history exists for any paddock. ',
           ('b', 'A design of this shape could not detect a grazing effect of moderate size, so its '
                 'absence here is not evidence of absence.'))
    + para(('b', 'A note on line weight. '),
           'Bala 26ca is 98.1% Inland Floodplain. Its Riverine portion is 1.9% of the paddock, or 636 '
           'cells; it clears the support rule comfortably and draws a line of the same weight as '
           'portions representing a third of a paddock, and it is the most volatile series in that '
           'panel. Read the Riverine panel\u2019s Bala 26ca line as a fragment of a paddock, not as a '
           'paddock.')
    + para(('b', 'A note on the legend. '),
           'The figure legend reads \u201creference\u201d. That is the analysis category the four paddocks '
           'were assigned before the analysis, not a finding; Figure 28 sets out why they do not '
           'function as a reference set.')
    + para(('b', 'Limitation. '),
           'This contrast is grazed against conserved, not grazed against formerly-cropped, because '
           'cultivation history is unavailable for all 64 paddocks.')
)

# ── Figure 22 passage ──────────────────────────────────────────────────
FIG22 = (
    para(('b', 'A control, not a result. '),
         'On mean cover the separation collapses. In Aeolian country the difference between the '
         'conserved arm and the rotational comparator falls from \u221232.0 raw and \u221210.5 adjusted on the '
         'cover floor to \u22124.1 raw and \u22122.3 adjusted on the mean. Across the other two communities '
         'the conserved parts sit on or inside the band for most of the record.')
    + para(('b', 'It does not vanish entirely, and this text does not say it does. '),
           'Bala 29ca\u2019s Aeolian line still runs below the band through the 1990s and 2000s before '
           'converging, and Bala 26ca\u2019s Riverine fragment still drops well below it in several years. '
           'What changes between Figures 21 and 22 is the size of the separation, not its existence: '
           'a difference of the order of thirty points becomes one of the order of four.')
    + para('This is the argument of Section 5 appearing at unit scale. An assessment built on mean '
           'cover would report differences small enough to dismiss \u2014 not because there are none, but '
           'because averaging well-covered and poorly-covered ground within a unit removes most of '
           'the quantity that responds to water. Which figure gives the right answer depends on which '
           'quantity carries the ecological meaning, and Section 5 sets out why the poorest patches '
           'were chosen.')
    + para(('b', 'Read as a pair, Figures 21 and 22 make one point: the metric determines how much '
                 'there is to see.'))
)

# ── Figure 23 passage ──────────────────────────────────────────────────
FIG23 = (
    para(('b', 'Note on grain. '),
         'Figures 21 and 22 compare paddock-community parts. This figure compares whole paddocks. '
         'The unit has changed and the two are not numerically comparable.')
    + para(('b', 'What it shows. '),
           'The series excluding Bala 29ca is flat: +0.057 percentage points per year, r = 0.22, mean '
           'gap \u22122.07 percentage points, ranging \u22127.04 to +4.99 across years and crossing zero in both '
           'directions. There is no movement toward or away from grazed country. Bala 29ca alone '
           'rises at +0.919 percentage points per year, r = 0.85. The four-paddock series at +0.273, '
           'r = 0.77, is that one paddock carried by the average \u2014 it sits near \u221210 points throughout '
           'because it averages three paddocks near \u22122 with one near \u221230.')
    + para(('b', 'Limitation. '),
           'A flat difference establishes that the difference is not changing. It does not establish '
           'that the difference is small, and no distance claim is made from this figure.')
    + para(('b', 'Nomenclature. '),
           '\u201cThree paddocks\u201d here denotes Bala 26ca, 27ca and 28ca, excluding Bala 29ca as the '
           'outlier. A different three-paddock set exists in the results store, defined by '
           'monitoring-plot presence and excluding Bala 27ca. The two share only two members and the '
           'term is never used unqualified.')
)

# ── Figure 26 passage ──────────────────────────────────────────────────
FIG26 = (
    para(('b', 'The three arms. '),
         'Conserved \u2014 the four paddocks under no grazing. Rotational \u2014 sixty paddocks under 14-day '
         'rotation, drawn as the grey comparator band. Unzoned \u2014 property area carrying no management '
         'zone at all, which is standard grazing; it has no mapped boundary, so it is inferred from '
         'the absence of a rotational zone rather than confirmed. A plot-confirmed subset of the '
         'unzoned arm is drawn separately.')
    + para(('b', 'Reading the two numbers. '),
           'The visible separation between a coloured line and the grey band is the raw difference. '
           'The labelled value is that difference after comparing each arm with the comparator '
           'separately within each wetness band and recombining weighted by stratum area. In Aeolian '
           'country a raw difference of \u221232.0 percentage points becomes \u221210.5 once like is compared '
           'with like. ',
           ('b', 'Most of the apparent difference between management arms is hydrological position, '
                 'not management.'))
    + para(('b', 'The nine adjusted differences, in percentage points against the rotational '
                 'comparator; positive is above. '),
           'Conserved: Aeolian \u221210.5, Inland +1.1, Riverine \u22124.5. Unzoned inferred standard: Aeolian '
           '+6.0, Inland \u22121.2, Riverine +7.9. Unzoned plot-confirmed: Aeolian +10.2, Inland \u22121.8, '
           'Riverine +9.3. These are rounded once from source; see Section 4.6.')
    + para(('b', 'The ordering runs opposite to the expected direction. '),
           'The conserved arm sits below the comparator in Aeolian and Riverine country, while both '
           'unzoned arms sit at or above it \u2014 the inferred arm in six of nine strata, the '
           'plot-confirmed subset in eight of nine. If heavier grazing reduced the cover floor, the '
           'ordering would be the reverse.')
    + para('Two readings are available and the figure states both. Either grazing intensity does not '
           'order the cover floor on this property, or the unzoned land is in fact less grazed than '
           'the rotational land rather than more, which would invert the inferred ordering. ',
           ('b', 'Nothing in the data distinguishes them, because no stocking record exists.'),
           ' The arms are management categories, not measured intensities, and the conserved Aeolian '
           'arm is Bala 29ca alone.')
    + para(('b', 'This is the figure behind the statement that management category does not order '
                 'the results. '),
           'It is a statement about categories as recorded, not about grazing as a process. The arm '
           'label \u201creference\u201d on the figure is the analysis category, not a finding.')
    + para(('b', 'Limitation. '),
           'No stocking data exists. Arm membership is a management category and the standard-grazing '
           'arm is inferred from the absence of a rotational-grazing zone rather than confirmed. Arm '
           'sizes are small and unequal \u2014 one to four paddocks on the conserved side against '
           'seventeen on the inferred-standard arm in Inland Floodplain country.')
)


ORDERED_OPS = [
    # ---- front matter (rows 1, 2) ----
    ('r1+r2 front matter', op_insert_after(
        'they are stated at a precision this document cannot itself confirm',
        para(('b', 'Two further classes of quantity are declared here. '),
             'Four figures in this document have no file, no producing script and no registry row, '
             'and are marked where they appear. The two persistence percentages in Section 7.4 '
             '(94.9% and 81.2%) reproduce exactly from the shipped surfaces but no producer emits '
             'them and neither carries a registry identifier. And the dashboard figures of Section 8 '
             'predate the current state of the code that produces them, so a re-render today would '
             'not reproduce them exactly.'))),

    # ---- §1 (rows 3, 4, 5) ----
    ('r3+r4 four bases', op_text(
        'Percentages are reported against one of these two bases and the base is always stated; the two are never interchanged.',
        'Four area bases appear in this assessment and the base is always stated. The property '
        'boundary is 85,910.8 ha on the analysis grid. The mapped census is 67,349.3 ha, being '
        '1,080,157 cells at 24.97 m. The non-treed census, which every floor number uses, is '
        '61,655.0 ha, being 988,831 cells. And the property boundary measured on the native 30 m '
        'grid in EPSG:3577 is 86,385 ha, being 959,833 cells; that is the same boundary as the '
        'first, on a coarser grid in a different projection, and not a second property. The first '
        'two reconcile: 67,349.3 ha mapped plus 18,561.5 ha unmapped is the property. The bases are '
        'never interchanged.')),

    ('r5 cover trend', op_text(
        'Trend statistics and the expectation line of Section 6.1 are fitted over 1988',
        'Cover trend statistics and the expectation line of Section 6.1 are fitted over 1988')),

    # ---- §3.1 (row 6) ----
    ('r6 community list', op_text(
        'three communities --- Aeolian Chenopod Shrublands, Riverine Chenopod Shrublands, Inland Floodplain Shrublands and Swamps --- each divided',
        'three communities \u2014 Aeolian Chenopod Shrublands; Riverine Chenopod Shrublands; and Inland '
        'Floodplain Shrublands and Swamps \u2014 each divided')),

    # ---- new subsections (rows 7, 8) ----
    ('r7 two footprints', op_insert_after(
        'no duration-based inference is available from it', FOOTPRINTS)),

    ('r8 how a number is formed', op_insert_after(
        'Plot-support results are reported as an independent reference and are not merged with census-support results',
        FORMED)),

    # ---- bare "floor" (rows 9, 10, 12, 13, 17, 29) ----
    ('r9 s5 heading', op_text('Why the floor rather than the mean',
                              'Why the poorest patches rather than the mean')),
    ('r10 s6.2', op_text('indicates the floor rising by about half',
                         'indicates the cover floor rising by about half')),
    ('r12a s7.2 heading', op_text('Flooding sets the drought floor, not typical cover',
                                  'Flooding sets the drought cover floor, not typical cover')),
    ('r12b s7.2 body', op_text('the floor moves roughly 34 points against',
                               'the cover floor moves roughly 34 points against')),
    ('r13a s7.4 lead', op_text('Mapping the floor shows where cover is retained',
                               'Mapping the cover floor shows where cover is retained')),
    ('r13b s7.4 fig8', op_text('across most of the property; the floor is\nmarkedly more variable',
                               'across most of the property; the cover floor is markedly more variable')),
    ('r17 s8 panel', op_text('cells with the GAM floor curve', 'cells with the GAM cover-floor curve')),
    ('r29 sF6 close', op_text('Section 5 sets out why the floor was chosen',
                              'Section 5 sets out why the poorest patches were chosen')),

    # ---- §6.6 p-value (row 11) ----
    ('r11 kruskal', op_text(
        'It is\nlabelled descriptive on the figures because the units are not\nindependent observations, and the reported p-value should be read as a\nsummary of separation rather than as inferential evidence.',
        'The delivery pack carries no p-values anywhere, and the report batch crops this one out of '
        'every dashboard it reproduces, so no client-facing report carries it. It is retained here '
        'because it is a between-community separation statistic and not an inferential claim about '
        'the annual series, and it is labelled descriptive on the figures because the units are not '
        'independent observations. The reported p-value should be read as a summary of separation '
        'rather than as inferential evidence.')),

    # ---- §7.4 (rows 14, 15, 16) ----
    ('r14 footprint', op_text(
        'this median and area are measured over the 86,385 ha property\nboundary including treed country',
        'this median and area are measured over the 86,385 ha property boundary on the native 30 m '
        'grid, including treed country (see Section 1)')),

    ('r15+r16 persistence', op_insert_after(
        '20 of its 50\ncomponents are under 5 ha',
        para(('b', 'What the two percentages are measured on. '),
             'The 94.9% and 81.2% figures are computed on the drawn, reprojected, '
             'component-filtered surfaces \u2014 406.09 ha satisfying both criteria, against 7,969.70 ha '
             'of total-cover surface and 500.06 ha of green-share surface. Neither percentage has a '
             'producing script or a registry identifier.')
        + para(('b', 'Four values, four objects. '),
               'The green-share surface is quoted at four figures in this project and they are not '
               'four estimates of one thing: 6,458 ha is the measurement at native 30 m and is the '
               'one to quote; 4,474 ha is an arithmetic conversion of the native cell count and is '
               'not a reprojection; 3,744 ha is the correct reprojection thresholded on the analysis '
               'grid; and 500 ha is that surface after the 5 ha component filter, which is what '
               'Figure 10 draws.'))),

    # ---- §8.1 captions (row 18) ----
    ('r18 fig12 basis', op_text(
        'Long-run flood frequency\n10%, recent 17%.',
        'Long-run flood frequency 10%, recent 17%, on the polygon footprint (Section 4.2b); the '
        'census footprint gives 8.5%.')),

    # ---- §9 (rows 19, 20, 20b, 21) ----
    ('r19 roadmap', op_text(
        'they differ from one another on every axis\nmeasured, and three of the four sit in the wettest country on the\nproperty (Figure 15)',
        'they differ from one another on every axis measured, and two of the four sit in the '
        'property\u2019s wettest country at ranks 3 and 6 of 64 while the third is at rank 31, '
        'essentially the midpoint, and the fourth at 61 (Figure 28)')),

    ('r20 nesting', op_text(
        'Between three and fifteen parts meet the\nrecovering criterion depending on the cut, and it is the same parts\nthroughout.',
        'Between three and fifteen parts meet the recovering criterion depending on the cut, and the '
        'sets are strictly nested: three parts at \u00b11.50, four at \u00b11.25, five under removal of the '
        'two wettest years, eight at the registered \u00b11.00, ten at \u00b10.75 and fifteen at \u00b10.50. Parts '
        'enter and leave as the cut moves but are never exchanged.')),

    ('r21 dinan tie', op_text(
        'Bala 29ca at --16.8, and Dinan 10 at --15.1. Two of\nthe three are grazed.',
        'Bala 29ca at \u221216.8, and Dinan 10 at \u221215.1. Two of the three are grazed. Dinan 13 is a '
        'fourth at \u221215.0, two hundredths of a point behind Dinan 10, so the third rank is '
        'effectively a tie between two grazed paddocks.')),

    # ---- §10 (rows 22 to 28) ----
    ('r22 signal', op_text(
        'It supplies most of the signal in Figure 20',
        'It carries the second-largest shortfall in Figure 20, behind Bala 15')),

    ('r23 figure 21', op_replace_block(
        'In Inland Floodplain country the three ungrazed paddocks other than',
        'because cultivation history is unavailable', FIG21)),

    ('r24 figure 22', op_replace_block(
        'A control rather than a result',
        'no difference between\nungrazed and grazed paddocks would be apparent', FIG22)),

    ('r25 figure 23', op_replace_block(
        'The three-paddock series is flat',
        'The two share only two members and the term is\nnever used unqualified', FIG23)),

    ('r27 figure 26', op_replace_block(
        'Reading the two numbers',
        'Arm sizes are small and\nunequal, at n = 1 to 4 for the ungrazed arm', FIG26)),

    ('r28 fig28 basis', op_text(
        'Bala 26ca floods in\n45.3% of years and ranks 3rd of 64; Bala 29ca floods in 8.5% and ranks\n61st.',
        'Bala 26ca floods in 45.3% of years and ranks 3rd of 64; Bala 29ca floods in 8.5% and ranks '
        '61st. Both are on the census footprint (Section 4.2b).')),

    # ---- T2 limitation (row 20b) ----
    ('r20b unsupported parts', op_text(
        'Three of 118 parts fall below the minimum support rule\n--- 25 years of at least 30 valid cells --- and are absent.',
        'Three of 118 parts fall below the minimum support rule \u2014 25 years of at least 30 valid '
        'cells \u2014 and are absent. They are Bala 15\u2019s Riverine portion (23 cells, 1.43 ha), Bala '
        '28ca\u2019s Aeolian portion (10 cells, 0.62 ha) and Mara 3\u2019s Aeolian portion (1 cell, 0.06 ha).')),

    # ---- §11 (rows 30, 31) ----
    ('r30 dispersed', op_text(
        'Four paddocks,\n    spatially clustered, hydrologically dissimilar',
        'Four paddocks, spatially dispersed across three separate parts of the property, '
        'hydrologically dissimilar')),

    ('r31 aggregation', op_text(
        'with mean inundation of 43.6%\nagainst 22.8% across the preceding thirty-one years.',
        'with mean inundation of 43.6% against 22.8% across the preceding thirty-one years, both '
        'pixel-weighted over the property (Section 4.6).')),
    # ---- vocabulary sweep (row 32) ----
    ('r32 vocabulary', lambda x: x.replace('ungrazed', 'conserved').replace('Ungrazed', 'Conserved')),
]


def main():
    x = open(SRC, encoding='utf8').read()
    # normalise soft line breaks introduced by extraction comparisons
    applied = []
    for name, fn in ORDERED_OPS:
        before = x
        # markers may contain newlines from the markdown view; XML has none
        x = fn(x)
        if x == before:
            print(f'  !! NO CHANGE: {name}')
        else:
            applied.append(name)
            print(f'  ok  {name}')
    open(SRC, 'w', encoding='utf8').write(x)

    # version stamp: title block and all three footers
    import glob
    for f in ['unpacked/word/document.xml'] + sorted(glob.glob('unpacked/word/footer*.xml')):
        t = open(f, encoding='utf8').read()
        if 'Draft v10' in t:
            open(f, 'w', encoding='utf8').write(t.replace('Draft v10', 'Draft v11'))
            print(f'  ok  version stamp {f.split("/")[-1]}')

    print(f'\n{len(applied)}/{len(ORDERED_OPS)} operations applied')


if __name__ == '__main__':
    main()
