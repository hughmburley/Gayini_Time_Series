## -----------------------------------------------------------------------------
## demo_spine.R
## Read-only, no-raster demo (~1s): reproduce the project headline + the F7 same-year
## ground-cover response gradient straight from the shipped results database, using
## only the modelling spine (v_plot_year_analysis_spine). No writes, no rasters.
##
## Run:  Rscript demo_spine.R
## -----------------------------------------------------------------------------

suppressPackageStartupMessages({library(DBI); library(RSQLite)})

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
db_path  <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
if (!file.exists(db_path)) stop("Database not found: ", db_path, call. = FALSE)

con <- dbConnect(SQLite(), db_path); on.exit(dbDisconnect(con))
sp  <- dbGetQuery(con, "SELECT * FROM v_plot_year_analysis_spine")

stopifnot(nrow(sp) == 2310L,
          !any(c("period", "vegetation_adrian_group") %in% names(sp)))

## 1. Headline: between-year annual flood frequency = 100 * wet-valid-years / valid-years
hl <- aggregate(cbind(annual_wet_any, annual_valid_any) ~ simplified_vegetation_group,
                data = sp[!is.na(sp$annual_valid_any), ], FUN = sum)
hl$flood_freq_pct <- round(100 * hl$annual_wet_any / hl$annual_valid_any, 1)
cat("\n== Headline: between-year annual flood frequency ==\n")
print(hl[order(hl$flood_freq_pct), c("simplified_vegetation_group", "flood_freq_pct")],
      row.names = FALSE)
cat("   (expect Aeolian 9.1 / Riverine 22.3 / Inland 49.6 / Woodland 44.1)\n")

## 2. F7 same-year gradient: median within-plot r(total_veg, annual_occurrence_pct) by community
u <- sp[sp$treed_plot_flag == 0 & sp$ground_cover_exclusion_flag == 0 &
        !is.na(sp$annual_occurrence_pct) & !is.na(sp$mean_total_veg_pct), ]
r_by_plot <- sapply(split(u, u$plot_id), function(d) {
  if (nrow(d) >= 3 && sd(d$annual_occurrence_pct) > 0 && sd(d$mean_total_veg_pct) > 0)
    cor(d$annual_occurrence_pct, d$mean_total_veg_pct) else NA_real_
})
comm  <- u$simplified_vegetation_group[match(names(r_by_plot), u$plot_id)]
focus <- c("Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
           "Inland Floodplain Shrublands / Swamps")
med   <- tapply(r_by_plot, comm, median, na.rm = TRUE)[focus]
nplt  <- tapply(!is.na(r_by_plot), comm, sum)[focus]
cat("\n== F7 same-year veg~intensity: community median r (usable non-treed plots) ==\n")
for (g in focus) cat(sprintf("   %-40s r=%.3f  n=%d\n", g, med[[g]], nplt[[g]]))
cat("   (expect Aeolian 0.17 / Riverine 0.26 / Inland 0.42; dry->wet strengthening)\n\n")
