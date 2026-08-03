# What this analysis cannot tell you

**Pack item T3 · Gayini reference-state assessment · 10 August 2026**

This page is in two parts. The first is what the analysis genuinely cannot tell you,
and it matters most: it is the boundary of what the rest of this pack means. The
second is shorter and less comfortable — it is the record of our own checks failing
and being caught. We include it because a limitations page that lists only the limits
of the data, and not the limits of the people handling it, is half a disclosure.

## Part 1 — What the analysis cannot tell you

### The four conserved paddocks are not one condition

This is the single most important limit on everything else here.

Ranked by how often they flood, the four paddocks with grazing excluded sit **3rd,
6th, 31st and 61st of 64**. They span almost the entire wetness range of the property.
Bala 26ca and Bala 28ca are in the wettest tenth of the farm; Bala 29ca is in the
driest 5%.

A reference state is only useful if it describes one thing. This one does not. Any
measurement of distance from the reference condition is a measurement against a moving
target, and we have not computed one. Where this pack compares conserved and grazed
ground, it compares four specific paddocks to sixty others — not a treatment to a
control.

### Removing grazing is perfectly confounded with where the paddocks are

All four conserved paddocks are in the Bala block. There is no conserved paddock
anywhere else on the property. So "not grazed" and "in Bala" describe exactly the same
ground, and no analysis in this pack can separate them. Any difference we report
between conserved and grazed ground is equally consistent with a difference between
one part of the farm and the rest.

### "Not grazed" is not the same as "conserved"

Land-use history is not recorded. The database reserves five columns for cropping
history and they are empty for **all 64 paddocks**. We do not know which paddocks were
cropped, when, or how heavily. A paddock that was irrigated cropland until 2013 and a
paddock that was never cleared are indistinguishable in this analysis.

### A paddock is not an ecological unit

Management zones were drawn for stock and water, not for vegetation. Bala 29ca — the
paddock that carries most of the reference-state results in this pack — is roughly one
third Inland Floodplain, one third Riverine and one third Aeolian, and its parts behave
in opposite directions: its Aeolian floor sits 32 percentage points below its
community's typical level, its Riverine floor 25 below, and its Inland floor only 6
below.

Any whole-paddock number for Bala 29ca is an average across three communities that
disagree. Where this pack quotes one, it is a summary and not a description. Decompose
by community before interpreting it.

### One arm of the grazing comparison was never measured

The property carries three grazing regimes: no grazing, 14-day rotational, and
standard. Every one of the **15 standard-grazing monitoring sites falls outside every
mapped management zone** — not one is inside a paddock boundary. They have no paddock
to belong to.

This is why the standard-grazing arm has never previously been reported, and why the
site and paddock reports exclude it. That exclusion is stated rather than accidental,
but it is still an exclusion.

### How a part is judged "low" changes which parts qualify

Measured against a within-community water expectation rather than a community median,
twelve of the 115 parts change side, and the count of recovering parts falls from eight
to five — a different five. This was computed at the design seat and has no committed
producer, so it is reported as a caution and not as a result. The classification in
this pack is definition-sensitive, and a reader should treat the eight as one defensible
answer rather than the only one.

### "Refugia" is a line we drew, not a boundary we found

Persistent ground cover does not fall into classes. Sweeping the threshold from 40% to
90% cover produces a smooth, continuous decline with no knee, no plateau and no
bimodality — a 1% rise in the threshold moves the mapped area by roughly 5%. At 70%
cover the persistent area is **12,641 ha**; at 75% it is **8,300 ha**; at 80% it is
**4,179 ha**. Five percentage points either side of the working cut changes the answer
by a factor of three.

We therefore set no headline refugia figure, and none should be quoted from this pack.
Where a persistence surface is mapped, the threshold is an operational choice made to
serve a specific overlay, not a discovered boundary. This was decided by a rule written
before the numbers were seen — see Part 2.

### The floor is a ground-layer measurement

The floor analysis excludes the treed stratum entirely. It runs on nine of eleven
strata — **988,831 of 1,080,157 pixels, 91.55% of the mapped property**. Floodplain
Woodland / Forest, **8.00%** of mapped pixels, and Other / minor units, 0.46%, are
outside the scope of every floor number in this pack.

So the floor is a measure of grass, forb and litter cover. It says little about
structural condition, recruitment, or the lignum and blackbox layers that matter for
habitat. A paddock can hold its ground-layer floor while losing its structure, and this
analysis would not see it.

### Two different things are both called "the floor"

The project computes two vegetation floor metrics that answer different questions on
different grids. They must never be compared numerically or appear in the same figure,
and everything in this pack uses one of them consistently. They differ by as much as 17
percentage points at fine grain, in opposite directions in different communities, so a
reader who mixes them will reach a confident and wrong conclusion.

If you carry a number from this pack into other work, carry its definition with it.

### Thirty-five consecutive years are not thirty-five independent observations

The annual series here are consecutive water years on the same ground, and each year is
strongly related to the ones either side of it. We therefore report no p-values and no
confidence intervals on any annual series, and none should be inferred. Where we
describe a trend we give its slope and its correlation, and stop there.

### The channel result is a proxy

Persistent vegetation sits on ground that floods roughly twice as often as the property
average, and this holds at every threshold tested. It is consistent with persistence
tracking channels and depressions — but no channel or watercourse layer exists anywhere
in this project. The only hydrological geometry available is irrigation infrastructure,
which is not natural channel. Flood frequency is standing in for proximity to water,
and the channel reading remains an interpretation.

### Not every number can be independently re-derived

The pack reports how many of its registered numbers can be recomputed by a second,
independent route; that figure is generated live and appears on the *How we know* sheet.
The remainder are not wrong — no registered number has drifted, and the value-drift
count is zero — but they have no second route written, so their stability is asserted
rather than tested. Both figures travel together wherever either is quoted.

## Part 2 — How we know our own checks work

Part 1 is what the data cannot support. This part is about whether we can be trusted to
have found it. Over the last fortnight our internal checks caught eight instances of one
failure and several of others. We list them because a pack that reports only successful
checks tells you nothing about whether the checks work.

**Recording a decision is not executing it.** Eight times, a decision was correctly
written down and not carried out, or a fact was asserted without being verified. A
retired statistic was still being drawn by two figure scripts four days after it was
retired. Thirty-three stale statements sat in documentation while the correct versions
sat in the output. Seven derivations were written into the registry and never wired into
the test that checks them. A changelog recorded that counts had been updated — to figures
that were themselves wrong. Four file paths were written from memory and all four were
wrong. An acceptance criterion passed because the criterion and the count it checked were
wrong in the same direction, which is why **a criterion stated as a typed literal is not
a check**. And one figure in an early draft of this page did not reproduce from the
database at all. Two of the eight were the senior reviewer's, not the analyst's.

**A check that errors is not a check that catches.** A test fixture that makes code crash
proves only that the code path is reachable. Detecting drift requires a fixture that
returns a wrong value the check must reject. One of our checks was rebuilt on those
grounds after the first version merely crashed.

**A live query is necessary and not sufficient.** The sheet in this pack that reports
how many of our numbers can be re-derived is generated by querying the database at
build time rather than by typing a figure. On the first pass it was still wrong,
because registering the pack's own workbook changed the counts the sheet was reporting
while the same script was running. It was caught by rebuilding until the numbers
stopped moving. The last defect we found was in the sheet whose purpose is to show
there are none, during the build that produced it.

**One numeral, several quantities.** Six occasions where a single number meant different
things in different places — three unrelated eighteens, two unrelated "six of nine"s on
two different metrics, two tasks both called T3, three different three-paddock reference
sets sharing only two members, and two different "three parts, two of them in Bala 29ca"
from two different tests. Each was caught; one only after producing a false defect report
on a figure that was fine, and one a single gate before it reached this pack's opening
page.

**A ruling is only a ruling if it can be quoted.** Twice, a document asserted a decision
that was never made, attributed to a person who never made it. The second time it reached
the delivered pack before it was caught.

**Pre-registration protects against some things and not others.** Two decision rules in
this project were written before their numbers arrived. One fired against us — it is the
rule that killed the refugia headline described above, and it was honoured without
negotiation. The other was aimed at the wrong hypothesis: it executed exactly as written,
downgraded nothing, and was structurally blind to the mechanism actually operating. A
second guard in the same specification did work, and excluded the strongest apparent
candidate on support grounds. Pre-registration stops you choosing a threshold after
seeing the result. It does not stop you testing the wrong proposition.
