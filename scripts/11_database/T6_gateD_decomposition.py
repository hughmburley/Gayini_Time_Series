#!/usr/bin/env python
"""T6 Gate D - three-arm gap decomposition with BOTH floor (veg_p05_spatial) and mean
cover, WITHIN stratum (community x regime_band) plus a community roll-up (band='ALL').
Deficits are vs grazed_14day, the fixed comparator. Additive new table + view; the T2
fact_reference_gap_decomposition is NOT modified. mean_of_seasons variant.

Gives a DB home to the mean-vs-floor finding: not_grazed matches grazed on MEAN cover
but sits far below on the FLOOR - now stored, per arm, per stratum.
"""
import sqlite3
import statistics as st
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
EARLY, LATE = 1997, 2013
ARMS = ["not_grazed", "grazed_14day", "unzoned_inferred_standard", "unzoned_plot_confirmed"]


def win_years(ys, w):
    if w == "early_8897":
        return [y for y in ys if y <= EARLY]
    if w == "late_1322":
        return [y for y in ys if y >= LATE]
    return list(ys)


def main():
    con = sqlite3.connect(DB)
    c = con.cursor()
    rows = c.execute("""SELECT treatment_arm, community, regime_band, water_year,
        n_units, veg_p05_spatial, veg_mean FROM fact_three_arm_stratum_veg_annual
        WHERE series_variant='mean_of_seasons'""").fetchall()
    # idx[(comm,band)][arm] -> list of (year, p05, mean, n_units)
    idx = {}
    for arm, comm, band, yr, nu, p05, mn in rows:
        idx.setdefault((comm, band), {}).setdefault(arm, []).append((yr, p05, mn, nu))

    c.execute("""CREATE TABLE IF NOT EXISTS fact_three_arm_gap_decomposition (
        community TEXT, regime_band TEXT, window TEXT, treatment_arm TEXT,
        n_units INTEGER, floor_p05 REAL, mean_cover REAL,
        floor_deficit_pp REAL, mean_deficit_pp REAL,
        support_level TEXT, aggregation_unit TEXT,
        PRIMARY KEY (community, regime_band, window, treatment_arm))""")

    def level(recs, w):
        ys = win_years([r[0] for r in recs], w)
        p = [r[1] for r in recs if r[0] in ys and r[1] is not None]
        m = [r[2] for r in recs if r[0] in ys and r[2] is not None]
        nu = max((r[3] for r in recs), default=None)
        return (st.mean(p) if p else None, st.mean(m) if m else None, nu)

    out = []
    for (comm, band), arms in sorted(idx.items()):
        for w in ("early_8897", "late_1322", "all"):
            base = arms.get("grazed_14day")
            gf, gm, _ = level(base, w) if base else (None, None, None)
            for arm in ARMS:
                if arm not in arms:
                    continue
                f, m, nu = level(arms[arm], w)
                fd = None if (f is None or gf is None) else round(f - gf, 2)
                md = None if (m is None or gm is None) else round(m - gm, 2)
                rec = (comm, band, w, arm, nu,
                       None if f is None else round(f, 2),
                       None if m is None else round(m, 2), fd, md,
                       "pixel", "arm_community_band_window")
                out.append(rec)
                c.execute("""INSERT OR REPLACE INTO fact_three_arm_gap_decomposition
                    VALUES (?,?,?,?,?,?,?,?,?,?,?)""", rec)
    c.execute("DROP VIEW IF EXISTS v_three_arm_gap_decomposition")
    c.execute("""CREATE VIEW v_three_arm_gap_decomposition AS
                 SELECT * FROM fact_three_arm_gap_decomposition""")
    con.commit()
    n = c.execute("SELECT COUNT(*) FROM fact_three_arm_gap_decomposition").fetchone()[0]
    print(f"fact_three_arm_gap_decomposition rows: {n}")

    print("\n=== COMMUNITY ROLL-UP (regime_band=ALL, window=all): floor vs mean deficit vs 14-day ===")
    print(f"{'community':26s} {'arm':26s} {'nU':>3} {'floor':>6} {'mean':>6} {'fl_def':>7} {'mn_def':>7}")
    for r in c.execute("""SELECT community, treatment_arm, n_units, floor_p05, mean_cover,
        floor_deficit_pp, mean_deficit_pp FROM fact_three_arm_gap_decomposition
        WHERE regime_band='ALL' AND window='all'
        ORDER BY community, CASE treatment_arm WHEN 'not_grazed' THEN 1 WHEN 'grazed_14day'
        THEN 2 WHEN 'unzoned_inferred_standard' THEN 3 ELSE 4 END"""):
        print(f"{r[0][:26]:26s} {r[1]:26s} {r[2]:>3} {r[3]:6.1f} {r[4]:6.1f} "
              f"{('' if r[5] is None else f'{r[5]:+.1f}'):>7} {('' if r[6] is None else f'{r[6]:+.1f}'):>7}")

    print("\n=== WITHIN-STRATUM three-arm floor deficit vs 14-day (window=all, wetness controlled) ===")
    print(f"{'community':22s} {'band':5s} {'notgrz':>7} {'unzon':>7} {'unz_pc':>7}  (floor pp vs 14-day)")
    for comm in sorted({k[0] for k in idx}):
        for band in ("low", "mid", "high"):
            d = {}
            for r in c.execute("""SELECT treatment_arm, floor_deficit_pp FROM
                fact_three_arm_gap_decomposition WHERE community=? AND regime_band=?
                AND window='all'""", (comm, band)):
                d[r[0]] = r[1]
            def g(a):
                return "" if d.get(a) is None else f"{d[a]:+.1f}"
            print(f"{comm[:22]:22s} {band:5s} {g('not_grazed'):>7} "
                  f"{g('unzoned_inferred_standard'):>7} {g('unzoned_plot_confirmed'):>7}")
    con.close()


if __name__ == "__main__":
    main()
