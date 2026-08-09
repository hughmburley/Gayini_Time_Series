#!/usr/bin/env python
"""UNZONED v3, Arm B section 4.5 - the pre-registered predictions against what happened.

Reads the fits rather than refitting, so a verdict can be re-worded without re-running
18,000 bootstrap draws.

THE COMPARISON MUST BE LIKE-FOR-LIKE, AND ON THE FIRST PASS IT WAS NOT. Section 4.5's
table gives the real parts' community figures under the heading "within-part MEDIAN" -
the median of the per-unit slopes, unweighted. The first run compared them against the
POOLED PIXEL-WEIGHTED community fits, which is a different estimator, and reported the
ordering as simply inverted. On the median - the quantity the prediction was actually
made about - Aeolian is the highest of the three, exactly as predicted.

Both orderings are reported here, because they genuinely differ and the difference is
itself a finding: weighting by cell count moves Aeolian from first to last.

No result is adjusted toward a prediction. Section 4.5.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "unzoned"

REAL_WITHIN_POOLED = 0.1613          # section 4.2's comparator
# section 4.5's table, real parts. BOTH columns, because they order differently.
REAL = pd.DataFrame([
    {"community_short": "aeolian", "real_between_part_slope": -0.309,
     "real_within_part_median": 0.350},
    {"community_short": "riverine", "real_between_part_slope": 0.348,
     "real_within_part_median": 0.218},
    {"community_short": "inland", "real_between_part_slope": 0.285,
     "real_within_part_median": 0.140},
])


def main() -> int:
    dist = pd.read_csv(OUT / "UNZONED_v3_armB_slope_distribution.csv")
    fits = pd.read_csv(OUT / "UNZONED_v3_armB_within_fits.csv")
    ar1 = pd.read_csv(OUT / "UNZONED_v3_armB_ar1_fit.csv")

    pooled = fits[fits.scope == "pooled"].iloc[0]
    a = ar1.iloc[0]
    comm = dist[dist.scope != "all"].copy()
    med_order = comm.sort_values("slope_median", ascending=False).scope.tolist()
    wt_order = (fits[fits.scope != "pooled"]
                .sort_values("slope", ascending=False).scope.tolist())
    share_all = float(dist.loc[dist.scope == "all", "share_positive"].iloc[0])

    # community comparison table, like-for-like on the median
    cc = (comm.rename(columns={"scope": "community_short"})
              .merge(REAL, on="community_short", how="left"))
    cc["unzoned_within_median"] = cc.slope_median
    cc["unzoned_pixel_weighted"] = [
        float(fits.loc[fits.scope == c, "slope"].iloc[0]) for c in cc.community_short]
    cc["median_ratio_unzoned_over_real"] = (cc.unzoned_within_median
                                            / cc.real_within_part_median)
    cc = cc[["community_short", "n_patches", "unzoned_within_median",
             "real_within_part_median", "median_ratio_unzoned_over_real",
             "unzoned_pixel_weighted", "real_between_part_slope"]]
    cc.to_csv(OUT / "UNZONED_v3_armB_community_comparison.csv", index=False,
              lineterminator="\n")

    rel = 100 * (pooled.slope - REAL_WITHIN_POOLED) / REAL_WITHIN_POOLED
    inside = bool(pooled.boot10000_p2_5 <= REAL_WITHIN_POOLED <= pooled.boot10000_p97_5)
    rows = [
        {"prediction": "pooled within slope near +0.16 (real parts +0.1613)",
         "comparator": f"{REAL_WITHIN_POOLED:+.4f}",
         "observed": f"{pooled.slope:+.4f} OLS-within; {a.slope:+.4f} under AR(1)",
         "verdict": "PARTLY HELD",
         "detail": (f"the same sign and the same order of magnitude, but "
                    f"{rel:+.0f}% on the like-for-like OLS-within comparison. The real-part "
                    f"value sits {'inside' if inside else 'outside'} the unzoned 10,000-draw "
                    f"interval [{pooled.boot10000_p2_5:+.4f}, {pooled.boot10000_p97_5:+.4f}] "
                    f"- and essentially ON its lower bound, so 'near +0.16' is true only at "
                    f"the edge. Under AR(1) the unzoned estimate falls to {a.slope:+.4f}, "
                    f"which is closer to the comparator but is NOT like-for-like with it.")},
        {"prediction": "community ordering Aeolian > Riverine > Inland",
         "comparator": "aeolian > riverine > inland (real within-part MEDIANS)",
         "observed": (f"median: {' > '.join(med_order)}; "
                      f"pixel-weighted: {' > '.join(wt_order)}"),
         "verdict": "PARTLY HELD",
         "detail": ("on the median - the quantity the prediction was made about - Aeolian "
                    "is the highest of the three as predicted. Riverine and Inland swap, "
                    "but they are separated by "
                    f"{abs(comm.loc[comm.scope == 'riverine', 'slope_median'].iloc[0] - comm.loc[comm.scope == 'inland', 'slope_median'].iloc[0]):.3f}, "
                    "which is not an ordering so much as a tie. The PIXEL-WEIGHTED "
                    "ordering is different again and puts Aeolian LAST: its median is "
                    "carried by small patches, one of which slopes +5.821, while its "
                    "weighted fit is carried by its few large ones. Which estimator is "
                    "used decides the answer, and that is the finding.")},
        {"prediction": "close to 100% of patches positive",
         "comparator": "~100%", "observed": f"{share_all:.1%}",
         "verdict": "HELD",
         "detail": ("every one of the 93 supported patches slopes positive, in all three "
                    "communities, with the smallest at +0.016. This is the least "
                    "equivocal of the three results.")},
    ]
    preds = pd.DataFrame(rows)
    preds["note"] = ("Predictions to check, not targets. No result is adjusted toward "
                     "them. Section 4.5.")
    preds["metric"] = "veg_p05_spatial"
    preds["estimator_note"] = ("the pooled figure is the demeaned pixel-weighted within "
                               "estimator; the community figures are reported BOTH as "
                               "the unweighted median of per-patch slopes and as the "
                               "pixel-weighted within fit, because they order differently")
    preds.to_csv(OUT / "UNZONED_v3_armB_predictions.csv", index=False,
                 lineterminator="\n")

    print("\n[4.5] pre-registered predictions against what happened\n")
    for _, r in preds.iterrows():
        print(f"  {r.verdict}")
        print(f"    prediction : {r.prediction}")
        print(f"    comparator : {r.comparator}")
        print(f"    observed   : {r.observed}")
        print(f"    {r.detail}\n")
    print("  community comparison, like-for-like on the median:")
    print(cc.to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
