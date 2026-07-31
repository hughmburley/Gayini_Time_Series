#!/usr/bin/env python
"""Re-register floor_flood_slope_64pdk and floor_flood_intercept_64pdk at 6 dp.

PRECISION CORRECTION, NOT A VALUE CHANGE. The fitted values are unchanged; only the number of
decimals stored moves. Reason: the rounded constants (0.548 / 52.6529) could NOT reproduce
v_zone_floor_flood_residual - recomputing from them missed the registered residuals by up to
0.0135 pp, against 0.0048 from the full-precision fit, which is the view's own 2-dp column
rounding and nothing more. The report stream draws the page-4 expectation line from these two
rows, so every one of the 21 paddock reports would otherwise carry a line marginally
inconsistent with the residual printed beside it.

A registry whose pinned constants cannot reproduce its own derived view has a latent
inconsistency, which is the opposite of what dim_headline_number is for.

The fit is RE-DERIVED here (bivariate OLS on the 64 paddock means, 1988-2022, mean_of_seasons)
and the script STOPS if it does not match the values being registered.

Display convention is unaffected: 3 significant figures in prose. No client-facing number moves.
"""
import sqlite3, statistics as st
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"

NEW_SLOPE, NEW_INTERCEPT = 0.547838, 52.652934      # 6 dp
OLD_SLOPE, OLD_INTERCEPT = 0.548, 52.6529

con = sqlite3.connect(DB); c = con.cursor()

# ---------------------------------------------------------------- re-derive the fit
F = {}
for zf, wy, p05, ff in c.execute(
        "SELECT zone_fid,water_year,veg_p05_spatial,flood_frac_pct FROM fact_zone_veg_annual "
        "WHERE series_variant='mean_of_seasons'"):
    F.setdefault(zf, []).append((wy, p05, ff))
X, Y = [], []
for zf in sorted(F):
    fl = [r[2] for r in F[zf] if 1988 <= r[0] <= 2022 and r[2] is not None]
    fy = [r[1] for r in F[zf] if 1988 <= r[0] <= 2022 and r[1] is not None]
    if fl and fy:
        X.append(st.mean(fl)); Y.append(st.mean(fy))
n = len(X); mx, my = st.mean(X), st.mean(Y)
sxx = sum((x - mx) ** 2 for x in X); sxy = sum((x - mx) * (y - my) for x, y in zip(X, Y))
slope = sxy / sxx; inter = my - slope * mx
print(f"re-derived bivariate OLS on {n} paddocks: slope {slope:.9f}  intercept {inter:.9f}")
assert n == 64, n
assert round(slope, 6) == NEW_SLOPE, (round(slope, 6), NEW_SLOPE)
assert round(inter, 6) == NEW_INTERCEPT, (round(inter, 6), NEW_INTERCEPT)
print(f"  rounds to 6 dp as {NEW_SLOPE} / {NEW_INTERCEPT}  -> matches the values being registered")
# the value has NOT changed: the new figures must round back to the old ones
assert round(NEW_SLOPE, 3) == OLD_SLOPE and round(NEW_INTERCEPT, 4) == OLD_INTERCEPT
print("  and both round back to the previously pinned values - precision only, no value change")

NOTE = ("PRECISION CORRECTION 2026-07-31, NOT a value change: {old} -> {new} is the same fitted "
        "constant stored to 6 dp, and rounds back to {old} exactly. Reason: the rounded constants "
        "could not reproduce v_zone_floor_flood_residual (max |diff| 0.0135 pp from the pinned "
        "pair vs 0.0048 from full precision, the latter being the view's own 2-dp column "
        "rounding). The report stream draws the page-4 expectation line from this row, so the "
        "rounding would have put a line marginally inconsistent with its own printed residual in "
        "all 21 paddock reports. DISPLAY CONVENTION UNCHANGED: 3 significant figures in prose "
        "(\"0.55\", \"about 0.5 pp per pp\"); no client-facing number moves. Prior note: {prior}")

for nid, new, old, dp in (("floor_flood_slope_64pdk", NEW_SLOPE, OLD_SLOPE, 3),
                          ("floor_flood_intercept_64pdk", NEW_INTERCEPT, OLD_INTERCEPT, 4)):
    pv, smin, smax, prior, dby = c.execute(
        "SELECT pinned_value,spread_min,spread_max,decision_note,decided_by "
        "FROM dim_headline_number WHERE number_id=?", (nid,)).fetchone()
    assert abs(pv - old) < 1e-9, (nid, pv, old)
    # Only the spread endpoint that IS the bivariate primary fit can be re-stated at 6 dp; the
    # other endpoint comes from a DIFFERENT model (the slope's 0.498 alternative, the intercept's
    # within-Inland 54.5840) and re-deriving it would be a refit, which this correction is not.
    new_min = new if abs(smin - old) < 1e-9 else smin
    new_max = new if abs(smax - old) < 1e-9 else smax
    c.execute("UPDATE dim_headline_number SET pinned_value=?, spread_min=?, spread_max=?, "
              "decision_note=?, decided_by=? WHERE number_id=?",
              (new, new_min, new_max,
               NOTE.format(old=old, new=new, prior=(prior or "")[:400]),
               (dby or "") + "; precision correction CC 2026-07-31 "
                             "(docs/change_reports/floor_flood_precision_correction.md)", nid))
    print(f"  {nid:30} {old} -> {new}   spread {smin} - {smax}  ->  {new_min} - {new_max}")

con.commit()

# ---------------------------------------------------------------- verify against the view
full = {z: (st.mean([r[1] for r in F[z] if 1988 <= r[0] <= 2022 and r[1] is not None]),
            st.mean([r[2] for r in F[z] if 1988 <= r[0] <= 2022 and r[2] is not None])) for z in F}
view = dict(c.execute("SELECT zone_fid,residual FROM v_zone_floor_flood_residual"))
P = dict(c.execute("SELECT number_id,pinned_value FROM dim_headline_number "
                   "WHERE number_id IN ('floor_flood_slope_64pdk','floor_flood_intercept_64pdk')"))
S = P["floor_flood_slope_64pdk"]; I = P["floor_flood_intercept_64pdk"]
gap_new = max(abs((full[z][0] - (I + S * full[z][1])) - view[z]) for z in view)
gap_old = max(abs((full[z][0] - (OLD_INTERCEPT + OLD_SLOPE * full[z][1])) - view[z]) for z in view)
budget = 0.005 + 5e-7 * max(f for _, f in full.values()) + 5e-7   # view 2 dp + 6-dp half-ulp
print(f"\nreproduce v_zone_floor_flood_residual from the PINNED constants:")
print(f"  before: max |diff| {gap_old:.5f}")
print(f"  after : max |diff| {gap_new:.5f}   budget {budget:.5f} (view 2-dp columns + 6-dp half-ulp)")
assert gap_new < budget, (gap_new, budget)
print("  -> the registry now reproduces its own derived view within the view's own rounding.")
con.close()
print("\nAdditive-in-spirit: two existing rows' precision, spread and notes updated. "
      "No value changed, no row added or deleted, no other object touched.")
