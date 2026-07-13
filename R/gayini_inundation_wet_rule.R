# ------------------------------------------------------------------------------
# R/gayini_inundation_wet_rule.R
# The confirmed, LOAD-BEARING inundation wet/valid reclassification rule.
#
# gayini_make_binary_inundation_layers() turns a raw inundation class raster into
# binary wet + valid layers. It encodes Adrian's confirmed value legend (2026-07-07)
# and is the single point of truth for "what counts as wet". The ACTIVE unified
# annual stack (scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R)
# depends on it, so it MUST live in a neutral, non-archivable file.
#
# It was previously defined inside R/inundation_pre_post_raster_functions.R (a file
# classed for archiving with the retired pre/post lineage). Extracting it here
# defuses that dependency: the active stack now sources ONLY this file for the wet
# rule, and the pre/post functions file (and background/prepost impls) source this
# file too so their own aggregation helpers keep working after the pre/post file is
# eventually archived. Moved verbatim — behaviour is unchanged.
# ------------------------------------------------------------------------------

gayini_make_binary_inundation_layers <- function(raster_layer,
                                                 product,
                                                 daily_wet_rule = c("strict_value_1", "include_ors_value_2"),
                                                 nodata_values = c(255, 65535, 127, -1)) {
  daily_wet_rule <- match.arg(daily_wet_rule)

  if (terra::nlyr(raster_layer) != 1) {
    raster_layer <- raster_layer[[1]]
  }

  if (product == "landsat_inundation") {
    # Confirmed value legend (NSW SEED metadata + Adrian's ruling, 2026-07-07):
    #   0 = not inundated     -> dry  (valid observation)
    #   1 = inundated         -> WET
    #   2 = off-river storage -> WET  (Adrian: "those pixels were wet just the same")
    #   3 = cloud shadow      -> MASK (failed observation: neither wet nor valid)
    # Explicit rule replacing the implicit `x > 0`, which silently counted value 3
    # (cloud shadow) as wet. wet = value IN (1,2); valid = value IN (0,1,2); value 3
    # is excluded from both. The vectorised %in% needs no branch on whether value 3
    # is present in a given raster. For the 35 canonical Landsat sources this is
    # identical to `x > 0` (they contain values {0,1,2} only), so the value-3 mask is
    # a no-op here -- but it is active for Sentinel-2 cloud shadow (Tier 3).
    landsat_valid_values <- c(0L, 1L, 2L)
    landsat_wet_values   <- c(1L, 2L)

    valid <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% landsat_valid_values)
      }
    )

    wet <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% landsat_wet_values)
      }
    )

  } else {
    valid_values <- c(0, 1, 2)

    wet_values <- if (daily_wet_rule == "include_ors_value_2") {
      c(1, 2)
    } else {
      c(1)
    }

    valid <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% valid_values)
      }
    )

    wet <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% wet_values)
      }
    )
  }

  names(valid) <- "valid_observation"
  names(wet) <- "wet_observation"

  list(wet = wet, valid = valid)
}
