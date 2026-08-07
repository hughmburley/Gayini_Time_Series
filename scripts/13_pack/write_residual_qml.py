#!/usr/bin/env python
"""Write the QGIS style for the part-residual GeoPackage.

CALLED BY THE MAPS PRODUCER, with the producer's own RLIM and CMAP.

Written standalone once, it diverged: that version took max|residual| on the
whole-record column alone (27.64) against the printed maps' RLIM across all three
periods (32.36) - a scale 15% tighter, so the same part took a different colour in
QGIS than on the page. Passing the constants in removes the class of error rather
than the instance.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from matplotlib.colors import Normalize

SYMBOL = """      <symbol name="{i}" type="fill" alpha="1">
        <layer class="SimpleFill">
          <Option type="Map">
            <Option name="color" type="QString" value="{rgb},255"/>
            <Option name="outline_color" type="QString" value="138,131,120,255"/>
            <Option name="outline_width" type="QString" value="0.12"/>
            <Option name="style" type="QString" value="solid"/>
          </Option>
        </layer>
      </symbol>"""

HEAD = """<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<!-- Gayini pack v1.3. Graduated on {attr}, symmetric about zero at
     +/-{rlim:.4f} pp - THE SAME LIMIT AND THE SAME RAMP AS THE PRINTED RESIDUAL MAPS,
     derived from the producer's own constants so screen and page cannot diverge.
     BLUE = more cover than its water predicts, RED = less. A residual is a departure
     from a fitted expectation: not condition, and not management. -->
<qgis version="3.34" styleCategories="Symbology">
  <renderer-v2 type="graduatedSymbol" attr="{attr}" graduatedMethod="GraduatedColor">
    <ranges>
{ranges}
    </ranges>
    <symbols>
{symbols}
    </symbols>
  </renderer-v2>
</qgis>
"""


def write_qml(path: Path, rlim: float, cmap, attr: str = "whole_record__residual",
              n_class: int = 24) -> tuple[float, int]:
    """n_class is high enough that the stepped QGIS ramp reads as the continuous print."""
    edges = np.linspace(-rlim, rlim, n_class + 1)
    norm = Normalize(-rlim, rlim)
    ranges, symbols = [], []
    for i in range(n_class):
        rgba = cmap(norm((edges[i] + edges[i + 1]) / 2))
        rgb = ",".join(str(int(round(255 * v))) for v in rgba[:3])
        ranges.append(f'      <range render="true" symbol="{i}" lower="{edges[i]:.6f}" '
                      f'upper="{edges[i+1]:.6f}" '
                      f'label="{edges[i]:+.1f} to {edges[i+1]:+.1f} pp"/>')
        symbols.append(SYMBOL.format(i=i, rgb=rgb))
    Path(path).write_text(HEAD.format(attr=attr, rlim=rlim, ranges="\n".join(ranges),
                                      symbols="\n".join(symbols)), encoding="utf-8")
    return float(rlim), n_class
