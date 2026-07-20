# Kickoff — dashboards refresh chat

*Paste this into a new Claude.ai chat in the Gayini project. Attach the built example dashboards (`D2_site_GA_*`) to the project first — they are the design reference.*

---

This chat is dedicated to ONE workstream: the Gayini **site-dashboard refresh** — scaling the existing site dashboards from **5 of 66 to all 66**, so they can feed the 66 per-site reports (Deliverable 1, the biggest item on the path to 10 August). This is **design-seat work**: we confirm the design and write the batch-build spec here; **CC executes it on the workstation.**

## First, read for context (project knowledge)

- **CLAUDE.md** — conventions, hard rules, the builder-is-destructive warning, four-CRS discipline.
- **Gayini_presentation_design_system.md** — the palette, community colours, slide/stat-card grammar the dashboards must match (deep-teal / cream / rust; Aeolian gold, Riverine teal, Inland blue, Woodland grey).
- **taskI_deck_stocktake_20260717.md** — what the D1/D2/D3 dashboards contain and their status (site dashboards are "held at the gate", 5 built: GA_001/003/019/032/052).
- **Gayini_site_report_GA_019_prototype.md** — the site report the dashboards plug into (defines what each dashboard needs to show and the plot→paddock link).
- **Gayini_Results_database_overview.md** — how to consume the DB: `v_plot_current_summary` and `v_plot_year_analysis_spine` are the per-site drivers.
- **Gayini_established_data_facts.md** — settled numbers.  **Gayini_path_to_Aug10.md** — where this fits.

## Design reference — use the EXISTING dashboards, do not redesign

- The attached examples (`D2_site_GA_*`) **are** the design. The task is to reproduce this exact layout/generator for the other 61 sites, **not** to invent a new one.
- Start by reading the existing dashboard **generator** in the repo (the D2 site-dashboard R code) and confirming it against the attached examples. **Recon first — report what the generator does and STOP before proposing any change.**

## Key constraints (carry into the spec)

- Per-site = **PLOT support** (1 ha, any-water rule) — the gradient panel places each site on **9/22/50**. Never swap in census pixel-support means (6/13/28) — that's the C10 error.
- **Full-record** framing (1988–2023). **No pre/post language.**
- Each dashboard carries the site's community, wetness regime, ground-cover, and grazing (metadata, not a driver), from the DB. **Resolve paths from the DB, never hardcode.**
- **Cultural sensitivity:** sites are `internal_review` / `public_release_ok = 0` / `cultural_sensitivity = review_required`; some carry `spatial_review_flag` (GA_016/029/006/007/022/066). Surface these.
- **The builder is destructive** — the dashboard build must be additive; never re-run the builder to register figures.

## Goal of this chat

A detailed **CC batch-build spec** that runs the existing generator for all 66 sites (plus confirms the paddock maps cover every site's paddock, since the reports reference them), matching the attached examples, **held for review — not merged.** Recon-first, gated.
