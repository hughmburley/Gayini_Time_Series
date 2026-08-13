"""Gayini report batch — data layer.

Every value here is read from Gayini_Results.sqlite at render time.
No number is typed as a literal. Registered constants are read from
dim_headline_number and asserted at 1e-4 before use (RS note 31 July, item 3).

Emits one JSON record per unit for the document builder.
"""
import sqlite3, json, sys, os
import numpy as np, pandas as pd

from config import DB, ROOT, TABLES, PARTREG, UNITS_DIR as OUT, require
require(DB, 'Gayini_Results.sqlite')

con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
con.execute('PRAGMA query_only=1')
q = lambda s, **p: pd.read_sql(s, con, params=p)

# ---------------------------------------------------------------- registry
REG = dict(q("select number_id,pinned_value from dim_headline_number").values)

EXPECT = {   # assert tighter than the precision we depend on
    'floor_flood_slope_64pdk':      0.547838,
    'floor_flood_intercept_64pdk': 52.652934,
    'floor_flood_r_64pdk':          0.710000,
    'floor_flood_residual_sd_64pdk': 6.620800,
}
for k, v in EXPECT.items():
    got = REG.get(k)
    if got is None:
        sys.exit(f'FAIL: {k} not registered')
    if abs(got - v) > 1e-4:
        sys.exit(f'FAIL: {k} = {got}, expected {v} (tolerance 1e-4). '
                 'A constant was re-pinned — check the change report before proceeding.')
print(f'registry OK — {len(REG)} rows; {len(EXPECT)} constants asserted at 1e-4')

# The census cell size is a project constant and has exactly one home. Client prose used to
# type "25 m"; PIXEL_SIDE_M is 24.970268.
#
# R-6, 4 Aug 2026: the reports render it to TWO decimal places — 24.97 m — not to the nearest
# metre. Both uses are descriptions, not arithmetic (every area in the batch comes from the
# census area_ha, which uses the true constant), so nothing computed was ever wrong. But
# nominalising 24.970268 to 25 is the class CLAUDE.md warns about: it inflates areas by 0.238%,
# and a rounded grid constant sitting in prose invites reuse in arithmetic the report never
# performed. 24.97 is a precise number rather than jargon and costs a reader nothing.
# Resolved MODULE-relative first, then ROOT. gayini_params is source that ships beside this
# module (scripts/lib next to scripts/15_reports); GAYINI_ROOT locates the DATA — the database,
# the figure renders, the output tree. Resolving code through the data root couples the two, and
# pointing GAYINI_ROOT at a data-only fixture then breaks the import rather than the fixture.
# Found by tests/test_canaries_can_fail.py before it could test a single canary.
_LIB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'lib')
for _p in (_LIB, os.path.join(ROOT, 'scripts', 'lib')):
    if os.path.isdir(_p) and _p not in sys.path:
        sys.path.insert(0, _p)
from gayini_params import PIXEL_SIDE_M                                    # noqa: E402

_T10_GAP = os.path.join(TABLES, 'T10_annual_gap_series.csv')


def t10_gap_series(series):
    """The annual gap series the registered t10_gap_annual_slope_* values were fitted to.

    NOT IN THE DATABASE. `Output/tables/T10_annual_gap_series.csv` is its only home and it is
    registered nowhere — no asset row by any path or id. A client figure now depends on an
    unregistered file, which is a gate stop for registration (session 1), not for this build:
    the alternative is to keep drawing a registered slope over points it was not fitted to.

    Returns None if the artefact or the series is absent, so the caller falls back to the
    derived series and says so, rather than silently drawing nothing.
    """
    if not os.path.exists(_T10_GAP):
        return None
    t = pd.read_csv(_T10_GAP)
    g = t[(t.series == series) & (t.series_variant == 'mean_of_seasons')].sort_values('water_year')
    if not len(g):
        return None
    return {'year': [int(y) for y in g.water_year], 'value': [float(v) for v in g.gap_pp]}


# R-16 constants, from the ruling, with ONE home. The slope band inside which the gap is
# neither closing nor widening, and the correlation below which no trend line is drawn.
# report_figs and report_build both read the decisions these produce, never the cuts.
GAP_SLOPE_FLAT = 0.05
GAP_R_MIN = 0.30

SLOPE = REG['floor_flood_slope_64pdk']
INTER = REG['floor_flood_intercept_64pdk']
RSD   = REG['floor_flood_residual_sd_64pdk']

# ---------------------------------------------------------------- lookups
ZONES = q("select zone_fid,zone_name,zone_group,grazing_treatment,area_ha_computed from dim_management_zone")
FID = dict(zip(ZONES.zone_name, ZONES.zone_fid))

COMM_SHORT = {'Aeolian Chenopod Shrublands': 'Aeolian',
              'Riverine Chenopod Shrublands': 'Riverine',
              'Inland Floodplain Shrublands / Swamps': 'Inland Floodplain',
              'Floodplain Woodland / Forest': 'Woodland'}
COMM_PLACE = {'Aeolian Chenopod Shrublands': 'the dry rises',
              'Riverine Chenopod Shrublands': 'the middle country',
              'Inland Floodplain Shrublands / Swamps': 'the channel country'}
STATE_WORDS = {'Recovering': 'coming back',
               'Declining': 'going backwards',
               'Persistently poor': 'low and staying low',
               'Unremarkable': 'behaving like that country elsewhere'}

# all-paddock frame for ranks and the scatter
PADDOCK = q("""select z.zone_name, z.grazing_treatment,
   avg(f.veg_p05_spatial) floor, avg(f.flood_frac_pct) ff
 from fact_zone_veg_annual f join dim_management_zone z using(zone_fid)
 where f.series_variant='mean_of_seasons' and f.water_year between 1988 and 2022
 group by 1,2""")
PADDOCK['rank_ff'] = PADDOCK.ff.rank(ascending=False).astype(int)
PADDOCK['rank_floor'] = PADDOCK.floor.rank(ascending=False).astype(int)
N_PDK = len(PADDOCK)

# every supported part, for the page-3 context cloud
PARTS_ALL = q("""select zone_name, community, level, trend_adj, trend_z, state_registered,
   marginal_flag, robustness_changed, state_drop2wettest
 from fact_zone_community_part_classification""")
COMM_MED = PARTS_ALL.groupby('community')['level'].median().to_dict()

# ------------------------------------------------------- REPORT-2 · water-adjusted part ranks
#
# The parts page already ranks each part's cover floor against the same community elsewhere.
# That column does NOT hold wetness constant: within Inland Floodplain the floor rises about
# +0.285 pp per point of wetness across a 6%-59% range, so a dry part reads as poor country for
# a reason that has nothing to do with how it is faring. REPORT-2 adds a second column ranking
# the part's DEPARTURE FROM ITS OWN EXPECTATION, which does hold wetness constant.
#
# Nothing is refitted and no residual is recomputed here (spec §4). Both quantities are read
# whole from the registered PARTREG table; this module only ranks them.
#
# Ranks are WITHIN COMMUNITY across all 115 supported parts — not within the paddock (which
# would manufacture a first/second/third in every paddock and invite exactly the reading the
# part-grain argument exists to prevent) and not across the property (an Inland rank and an
# Aeolian rank are positions in different distributions). The CSV's own
# `whole_record__residual_rank_1_is_largest_shortfall` ranks across all 115 together and is
# therefore NOT the column the reports need.
#
# Direction: rank 1 = worst on both columns, matching the existing floor column. A silent
# direction flip here would be the hardest error in this batch to catch downstream.
require(PARTREG, 'PARTREG_part_residuals.csv (pack v1.2)')
_pr = pd.read_csv(PARTREG).rename(columns={
    'whole_record__floor_mean': 'floor', 'whole_record__inund_mean': 'inund',
    'whole_record__residual': 'residual'})
_pr['rank_floor'] = _pr.groupby('community')['floor'].rank(method='min').astype(int)
_pr['rank_water'] = _pr.groupby('community')['residual'].rank(method='min').astype(int)
_pr['n_of'] = _pr.groupby('community')['part_id'].transform('count')

# The join is (zone_fid, community) — both tables carry the full community string, so no
# short-name mapping is interposed. A mapping dict here would be a second place for the
# community vocabulary to live and a silent way to drop a part.
_chk = PARTS_ALL.merge(q("select zone_fid, zone_name from dim_management_zone"), on='zone_name') \
    .merge(_pr[['zone_fid', 'community']], on=['zone_fid', 'community'], how='outer', indicator=True)
if (_chk._merge != 'both').any():
    sys.exit(f'FAIL: PARTREG does not cover the classified parts one-for-one — '
             f'{(_chk._merge != "both").sum()} unmatched of {len(_chk)}. Check the join keys.')

# The floor column already on the parts page is computed from the classification table's own
# `level`. If ranking PARTREG's floor disagreed with it, the two columns beside each other on
# one row would be reading different objects. Asserted, not assumed.
_cmp = PARTS_ALL.merge(q("select zone_fid, zone_name from dim_management_zone"), on='zone_name') \
    .merge(_pr[['zone_fid', 'community', 'rank_floor']], on=['zone_fid', 'community'])
_cmp['rank_build'] = _cmp.groupby('community')['level'].rank(method='min').astype(int)
if (_cmp.rank_build != _cmp.rank_floor).any():
    _d = _cmp[_cmp.rank_build != _cmp.rank_floor]
    sys.exit(f'FAIL: the floor rank on the parts page disagrees with PARTREG on '
             f'{len(_d)} parts, e.g. {_d.iloc[0].zone_name}/{_d.iloc[0].community}: '
             f'page {_d.iloc[0].rank_build} vs PARTREG {_d.iloc[0].rank_floor}.')

# Spec §5's stated invariant, asserted rather than eyeballed: Bala 29ca's Aeolian and Riverine
# thirds sit near their communities' dry ends, so both columns must agree on them; only its
# Inland third moves. If the dry thirds move, the join is wrong.
_B29 = 'Bala 29ca'      # one home; also keeps the digits out of an f-string, where the prose
                        # lint cannot tell a paddock name from a typed result number
_b29 = _pr[_pr.paddock_name == _B29].set_index('community')
for _c, _short in (('Aeolian Chenopod Shrublands', 'Aeolian'),
                   ('Riverine Chenopod Shrublands', 'Riverine')):
    _row = _b29.loc[_c]
    if _row.rank_floor != _row.rank_water:
        sys.exit(f'FAIL: {_B29} {_short} moves {_row.rank_floor} -> {_row.rank_water} '
                 f'between the two rankings. The spec says it must not; the join is wrong.')
if _b29.loc['Inland Floodplain Shrublands / Swamps'].rank_floor == \
        _b29.loc['Inland Floodplain Shrublands / Swamps'].rank_water:
    sys.exit(f'FAIL: {_B29} Inland does not move between the two rankings. '
             'It is the one part that must; the join or the direction is wrong.')

PART_RANK = {(int(x.zone_fid), x.community): (int(x.rank_floor), int(x.rank_water), int(x.n_of))
             for _, x in _pr.iterrows()}

# The derived table, emitted for QA to check the reports against by an independent path.
# Registration as a table asset is session 1's, not this module's — flagged, not attempted.
os.makedirs(TABLES, exist_ok=True)   # config.py creates the output dirs it owns, not this one
_out = os.path.join(TABLES, 'REPORT2_part_ranks.csv')
_pr[['part_id', 'zone_fid', 'paddock_name', 'community', 'community_short', 'conserved',
     'n_pixels_part', 'area_ha', 'floor', 'inund', 'residual',
     'rank_floor', 'rank_water', 'n_of']].sort_values(['community', 'rank_water']).to_csv(
    _out, index=False)
print(f'REPORT-2 OK — {len(_pr)} parts ranked within community '
      f'({", ".join(f"{k.split()[0]} {v}" for k, v in _pr.groupby("community").size().items())}); '
      f'wrote {os.path.basename(_out)}')

# network-level counts, derived (a typed literal is not a check)
NET = q("""select
   sum(treed_plot_flag=0) n_nontreed, sum(treed_plot_flag=1) n_treed, count(*) n_total
 from dim_plot""").iloc[0].to_dict()
NET_ZONED = int(q("""select count(*) n from plot_paddock pp join dim_plot dp using(plot_id)
 where dp.treed_plot_flag=0 and pp.in_zone=1""").n[0])

# every non-treed site, for the page-5 community boxplot and site peer panel
SITES_ALL = q("""select p.plot_id, p.simplified_vegetation_group community,
   avg(v.annual_wet_any)*100 ff, avg(v.mean_total_veg_pct) tot,
   avg(v.mean_pv_pct) green, avg(v.mean_npv_pct) dead, avg(v.mean_bare_ground_pct) bare
 from v_plot_year_analysis_spine v join dim_plot p using(plot_id)
 where p.treed_plot_flag=0 group by 1,2""")

# annual grazed baseline (area-weighted) for the gap series
_gz = q("""select z.zone_name, z.area_ha_computed ha, f.water_year, f.veg_p05_spatial floor
 from fact_zone_veg_annual f join dim_management_zone z using(zone_fid)
 where f.series_variant='mean_of_seasons' and z.grazing_treatment <> 'No grazing'""")
GRAZED_YR = _gz.groupby('water_year').apply(
    lambda g: (g.floor * g.ha).sum() / g.ha.sum(), include_groups=False)


def paddock_record(name):
    fid = int(FID[name])
    r = {'unit': name, 'kind': 'paddock', 'zone_fid': fid}

    # ---- contract row: cover headline (page 1)
    r['floor'] = float(q("""select avg(veg_p05_spatial) v from fact_zone_veg_annual
        where zone_fid=:f and series_variant='mean_of_seasons'
          and water_year between 1988 and 2022""", f=fid).v[0])
    # ---- contract row: flood frequency (page 2)
    r['ff'] = float(q("""select avg(flood_frac_pct) v from fact_zone_veg_annual
        where zone_fid=:f and series_variant='mean_of_seasons'
          and water_year between 1988 and 2022""", f=fid).v[0])

    p = PADDOCK[PADDOCK.zone_name == name].iloc[0]
    r['rank_ff'] = int(p.rank_ff); r['rank_floor'] = int(p.rank_floor); r['n_paddocks'] = N_PDK
    r['grazing'] = p.grazing_treatment
    r['conserved'] = (p.grazing_treatment == 'No grazing')

    # ---- contract row: composition, denominator A (page 3)
    comp = q("""select community, share_a, share_c, n_pixels_a, dominance_a, dominance_class_a,
        n_parts_supported from v_zone_community_composition where zone_fid=:f
        order by share_a desc""", f=fid)
    r['composition'] = [{'community': x.community, 'short': COMM_SHORT.get(x.community, x.community),
                         'share': float(x.share_a), 'share_all': float(x.share_c)}
                        for _, x in comp.iterrows() if x.share_a > 0]
    r['woodland_share'] = float(comp[comp.community == 'Floodplain Woodland / Forest'].share_c.sum())
    r['dominance'] = float(comp.dominance_a.iloc[0])
    r['dominance_class'] = comp.dominance_class_a.iloc[0]
    r['n_parts'] = int(comp.n_parts_supported.iloc[0])

    # areas by wetness band, non-treed
    cen = q("""select regime_band, sum(n_pixels) px, sum(area_ha) ha,
        sum(n_pixels*flood_freq_mean)/sum(n_pixels) ff
      from v_census_by_zone_stratum where zone_name=:n and treed_context_flag=0
      group by 1""", n=name)
    BAND = {'low': 'Drier ground', 'mid': 'Middle', 'high': 'Wetter ground'}
    # regime_band is carried through, not just its label: the figure colours the bars by
    # band identity (R-2). Deriving colour from a flood-frequency cutoff instead invented a
    # second classification of rows this query has already classified, and the two disagreed
    # on 10 of 21 bars.
    r['bands'] = [{'band': BAND.get(x.regime_band, x.regime_band), 'regime_band': x.regime_band,
                   'ha': float(x.ha), 'ff': float(x.ff)}
                  for _, x in cen.iterrows() if x.regime_band in BAND]
    r['bands'].sort(key=lambda b: -b['ff'])
    r['area_ha'] = float(cen[cen.regime_band.isin(BAND)].ha.sum())
    tre = q("""select sum(area_ha) ha from v_census_by_zone_stratum
        where zone_name=:n and treed_context_flag=1""", n=name).ha[0]
    r['area_treed_ha'] = float(tre or 0)

    # ---- contract row: residual from the REGISTERED line (page 4) — read, never refit
    res = q("select residual, rank, predicted_floor, mean_floor, mean_flood "
            "from v_zone_floor_flood_residual where zone_fid=:f", f=fid)
    if len(res):
        r['residual'] = float(res.residual[0]); r['residual_rank'] = int(res['rank'][0])
        r['predicted'] = float(res.predicted_floor[0])
    else:
        r['residual'] = None
    r['fit'] = {'slope': SLOPE, 'intercept': INTER, 'resid_sd': RSD,
                'r': REG['floor_flood_r_64pdk']}

    # ---- contract row: part states (page 3) — registered classification
    pc = q("""select community, level, trend_adj, trend_z, state_registered, pp_split,
        marginal_flag, robustness_changed, state_drop2wettest, dist_to_nearest_cut, assert_state
      from fact_zone_community_part_classification where zone_fid=:f order by community""", f=fid)
    parts = []
    for _, x in pc.iterrows():
        share = next((cc['share'] for cc in r['composition'] if cc['community'] == x.community), None)
        # REPORT-2: rank against the same community elsewhere on cover (existing) and on
        # departure from expectation (new). Both read from PARTREG, both rank 1 = worst.
        _rf, _rw, _rn = PART_RANK[(fid, x.community)]
        parts.append({
            'community': x.community, 'short': COMM_SHORT.get(x.community, x.community),
            'place': COMM_PLACE.get(x.community, x.community),
            'level': float(x['level']), 'vs_median': float(x['level'] - COMM_MED[x.community]),
            'rank': _rf, 'rank_water': _rw, 'n_of': _rn,
            'state': x.state_registered, 'state_words': STATE_WORDS[x.state_registered],
            'marginal': bool(x.marginal_flag), 'robust_changed': bool(x.robustness_changed),
            'drop2': x.state_drop2wettest, 'trend_z': float(x.trend_z),
            'share': share, 'ha': (share / 100 * r['area_ha']) if share else None})
    r['parts'] = parts
    r['n_recovering'] = sum(p['state'] == 'Recovering' for p in parts)

    # R-8, 4 Aug 2026. Page 1 counts the parts that reach the part-classification support
    # rule — exactly the rows page 3 will show — not the communities in the census. The two
    # pages then cannot disagree, because they read the same object rather than because a
    # threshold was tuned until they matched.
    #
    # A community present in the census but below that rule is a TRACE: named, never counted,
    # never given a percentage, never printed as 0%. Derived from the set difference, so no
    # paddock is named in code. Affects 3 of 64 — Bala 15 (23 px), Bala 28ca (10 px), Mara 3
    # (ONE 24.97 m cell, 0.0624 ha). A percentage cut would have been a new constant to
    # defend; the support rule is already in force and already registered.
    _classified = {p['community'] for p in parts}
    r['trace_communities'] = [
        {'community': c['community'], 'short': c['short'],
         'share': c['share'], 'ha': c['share'] / 100 * r['area_ha']}
        for c in r['composition']
        if c['short'] != 'Woodland' and c['community'] not in _classified]

    # ---- annual gap series (page 4) — series derived; SLOPE read from the registry
    me = q("""select water_year, veg_p05_spatial floor, flood_frac_pct ff, veg_mean
        from fact_zone_veg_annual where zone_fid=:f and series_variant='mean_of_seasons'
        order by water_year""", f=fid)
    r['series'] = {'year': [int(y) for y in me.water_year],
                   'floor': [float(v) for v in me.floor],
                   'ff': [float(v) for v in me.ff],
                   'mean': [float(v) for v in me.veg_mean]}
    # §8.1 resolved, v1.5. The registered slopes are NOT wrong: all three reproduce from
    # Output/tables/T10_annual_gap_series.csv to the rounding of their pinned values
    # (A_all4 0.2727 vs 0.273 · B_excl29ca 0.0571 vs 0.057 · C_29ca 0.9193 vs 0.919).
    #
    # The defect was that the figure drew the registered SLOPE over points derived here by a
    # different construction of the same quantity — a different grazed-baseline aggregation.
    # The two series differ by a mean of 4.70 pp and up to 8.69 pp, and fig_gap anchors the
    # line's intercept to the mean of whichever points it is given, so the drawn line was
    # neither series. Its two annotated endpoints read 41 and 10 points below where the
    # registered series gives 45 and 14.
    #
    # So where a registered slope is asserted, the POINTS come from the artefact that slope
    # was fitted to. Where none is, the series is derived here and the figure fits its own
    # line to its own points — internally consistent, and asserting no registered value.
    T10_SERIES = {'Bala 29ca': 'C_29ca'}          # paddock -> series in the T10 artefact
    key = {'Bala 29ca': 't10_gap_annual_slope_C_29ca'}.get(name)
    r['gap_slope_registered'] = REG.get(key) if key else None
    reg_series = t10_gap_series(T10_SERIES[name]) if name in T10_SERIES else None
    if reg_series is not None:
        r['gap'] = reg_series
        r['gap_source'] = f'T10_annual_gap_series.csv :: {T10_SERIES[name]}'
    else:
        gap = (me.set_index('water_year').floor - GRAZED_YR).dropna()
        r['gap'] = {'year': [int(y) for y in gap.index], 'value': [float(v) for v in gap.values]}
        r['gap_source'] = 'derived: paddock floor minus grazed baseline, this module'
    # gap_slope_derived was removed at v1.3 because nothing read it. R-16 gives it a reader:
    # the gap figure's caption must state the direction, the slope and the correlation, and
    # must not draw a trend line through noise. So it returns, WITH a reader and a stated
    # method — which is the condition on which it was withdrawn, not a reversal of it.
    #
    # Rounded to 6 dp on emission. The reason it was noise in the v1.3 diffs was np.polyfit's
    # last-bit ordering differing between machines at the 15th significant figure; rounding
    # far beyond the 3 dp the caption prints makes the record stable without touching what a
    # reader sees.
    _gy = np.asarray(r['gap']['year'], float); _gv = np.asarray(r['gap']['value'], float)
    r['gap_slope_derived'] = round(float(np.polyfit(_gy, _gv, 1)[0]), 6)
    r['gap_r_derived'] = round(float(np.corrcoef(_gy, _gv)[0, 1]), 6)

    # The direction and the draw/omit decision are settled HERE, once, and both the figure and
    # its caption read them. Computing them in each place would let a caption describe a trend
    # the figure did not draw — the R-8 failure in a new costume.
    # Slope of record: the registered value where one exists, since that is what the figure
    # draws; otherwise the derived one.
    _sl = r['gap_slope_registered'] if r['gap_slope_registered'] is not None else r['gap_slope_derived']
    r['gap_slope_shown'] = float(_sl)
    r['gap_direction'] = ('closing' if _sl > GAP_SLOPE_FLAT
                          else 'widening' if _sl < -GAP_SLOPE_FLAT else 'neither')
    r['gap_line_drawn'] = bool(abs(r['gap_r_derived']) >= GAP_R_MIN)

    r['year_first']=int(me.water_year.min()); r['year_last']=int(me.water_year.max())
    r['n_years']=int(me.water_year.nunique())
    r['pixel_side_m']=float(PIXEL_SIDE_M)

    # extremes, annual only — no period statistics (handoff C-2)
    r['best_year'] = int(me.loc[me.floor.idxmax(), 'water_year'])
    r['best_floor'] = float(me.floor.max())
    r['worst_year'] = int(me.loc[me.floor.idxmin(), 'water_year'])
    r['worst_floor'] = float(me.floor.min())
    r['wettest_year'] = int(me.loc[me.ff.idxmax(), 'water_year'])
    r['wettest_ff'] = float(me.ff.max())

    # ---- sites (page 5), with the treed rule stated (handoff C-1)
    s = q("""select pp.plot_id, dp.treed_plot_flag treed, dp.simplified_vegetation_group community,
        dp.spatial_review_flag srf
      from plot_paddock pp join dim_plot dp using(plot_id)
      where pp.zone_name=:n order by pp.plot_id""", n=name)
    r['n_sites_total'] = len(s); r['n_sites_treed'] = int(s.treed.sum())
    keep = s[s.treed == 0]
    sd = SITES_ALL[SITES_ALL.plot_id.isin(keep.plot_id)].merge(
        keep[['plot_id', 'srf']], on='plot_id')
    r['sites'] = [{'plot_id': x.plot_id, 'community': x.community,
                   'short': COMM_SHORT.get(x.community, x.community),
                   'ff': float(x.ff), 'tot': float(x.tot), 'green': float(x.green),
                   'dead': float(x.dead), 'bare': float(x.bare),
                   'review_flag': bool(x.srf)}
                  for _, x in sd.sort_values('ff').iterrows()]
    r['n_sites'] = len(r['sites'])
    r['network'] = {'nontreed': int(NET['n_nontreed']), 'treed': int(NET['n_treed']),
                    'total': int(NET['n_total']), 'zoned_nontreed': NET_ZONED}
    return r


def site_record(plot_id):
    r = {'unit': plot_id, 'kind': 'site'}
    d = q("""select p.plot_id, p.simplified_vegetation_group community, p.plot_area_ha ha,
        p.spatial_review_flag srf, pp.zone_name
      from dim_plot p left join plot_paddock pp using(plot_id) where p.plot_id=:p""", p=plot_id).iloc[0]
    r['community'] = d.community; r['short'] = COMM_SHORT.get(d.community, d.community)
    r['place'] = COMM_PLACE.get(d.community, d.community)
    r['area_ha'] = float(d.ha); r['paddock'] = d.zone_name; r['review_flag'] = bool(d.srf)

    y = q("""select water_year, mean_total_veg_pct tot, mean_pv_pct green, mean_npv_pct dead,
        mean_bare_ground_pct bare, annual_wet_any wet from v_plot_year_analysis_spine
      where plot_id=:p order by water_year""", p=plot_id)
    y['yr'] = y.water_year.str.slice(0, 4).astype(int)
    r['series'] = {'year': [int(v) for v in y.yr], 'tot': [float(v) for v in y.tot],
                   'green': [float(v) for v in y.green], 'dead': [float(v) for v in y.dead],
                   'bare': [float(v) for v in y.bare], 'wet': [int(v) for v in y.wet]}
    r['ff'] = float(y.wet.mean() * 100); r['n_wet'] = int(y.wet.sum()); r['n_years'] = len(y)
    r['wet_years'] = [int(v) + 1 for v in y[y.wet == 1].yr]
    for k, col in [('tot', 'tot'), ('green', 'green'), ('dead', 'dead'), ('bare', 'bare')]:
        r[k] = float(y[col].mean())
    r['best_year'] = int(y.loc[y.tot.idxmax(), 'yr']); r['best_tot'] = float(y.tot.max())
    r['worst_year'] = int(y.loc[y.tot.idxmin(), 'yr']); r['worst_tot'] = float(y.tot.min())

    peers = SITES_ALL[SITES_ALL.community == d.community]
    r['n_peers'] = len(peers)
    r['rank_ff'] = int((peers.ff > r['ff']).sum() + 1)
    r['rank_tot'] = int((peers.tot > r['tot']).sum() + 1)
    r['peer_median_ff'] = float(peers.ff.median())

    # parent-paddock context, prose only
    if d.zone_name in FID:
        pr = q("""select community, state_registered from fact_zone_community_part_classification
            where zone_fid=:f""", f=int(FID[d.zone_name]))
        m = pr[pr.community == d.community]
        r['part_state'] = m.state_registered.iloc[0] if len(m) else None
        r['part_state_words'] = STATE_WORDS.get(r['part_state'])
        r['paddock_n_parts'] = len(pr)
    return r


CANARY = {   # contract canaries — a drift here fails the build, not a client document
    'rptscope_canary_p1_paddock_floor_bala29ca':
        lambda: round(paddock_record('Bala 29ca')['floor'], 2),
    'rptscope_canary_p3_composition_share_bala29ca_inland':
        lambda: round([c['share'] for c in paddock_record('Bala 29ca')['composition']
                       if c['short'] == 'Inland Floodplain'][0], 2),
    'rptscope_canary_p5_recovering_parts_bala29ca':
        lambda: float(paddock_record('Bala 29ca')['n_recovering']),
    't10_bala29ca_xsec_residual':
        lambda: round(paddock_record('Bala 29ca')['residual'], 2),
}


def run_canaries():
    for nid, fn in CANARY.items():
        want, got = REG[nid], fn()
        if abs(want - got) > 0.011:
            sys.exit(f'CANARY FAIL: {nid} registered {want}, builder produced {got}')
        print(f'  canary OK  {nid:54s} {got}')


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--paddocks', nargs='*', default=[])
    ap.add_argument('--all-paddocks', action='store_true',
                    help='every management zone (R-7). Derived from dim_management_zone, '
                         'not typed — a list of 64 names is a literal standing in for a query.')
    ap.add_argument('--sites', nargs='*', default=[])
    a = ap.parse_args()
    run_canaries()

    paddocks = list(a.paddocks)
    if a.all_paddocks:
        # R-7, 4 Aug 2026: paddock coverage is EVERY management zone. Expressed as the query
        # that defines the set, so it cannot drift from dim_management_zone the way a typed
        # list of 64 names would. R-7 supersedes R-4 on paddocks only; sites stay at 25.
        paddocks = [z for z in q('select zone_name from dim_management_zone '
                                 'order by zone_name').zone_name]
        print(f'  --all-paddocks: {len(paddocks)} zones from dim_management_zone')

    for nm in paddocks:
        rec = paddock_record(nm)
        json.dump(rec, open(f"{OUT}/paddock_{nm.replace(' ', '_').replace('/', '-')}.json", 'w'), indent=1)
        print(f"  paddock {nm:12s} floor {rec['floor']:.2f} ff {rec['ff']:.2f} "
              f"resid {rec['residual']} parts {rec['n_parts']} sites {rec['n_sites']}/{rec['n_sites_total']}")
    for sid in a.sites:
        rec = site_record(sid)
        json.dump(rec, open(f"{OUT}/site_{sid}.json", 'w'), indent=1)
        print(f"  site {sid:8s} ff {rec['ff']:.1f} tot {rec['tot']:.1f} in {rec['paddock']}")
