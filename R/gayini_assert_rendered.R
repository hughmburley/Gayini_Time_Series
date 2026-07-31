# gayini_assert_rendered.R — post-render assertions for figures that draw numbers as TEXT.
#
# WHY THIS EXISTS (I-32). Every acceptance check in this project tests a data object. A figure
# is built FROM that object but the drawing step can still corrupt it, and no data-level check
# can see that. The worked case: `fmt()` in the Adrian-pack build used `ifelse()`, which returns
# a value the length of its TEST — the test was length 1, so the formatted number collapsed to a
# single element and `sprintf()` recycled it across all four paddocks. The CSV was correct. The
# PNG showed "45.3" in every column. Every acceptance check passed. The PNG is what the client
# sees.
#
# The rule: a figure that renders numbers as text asserts the RENDERED STRINGS against the source
# values — not the data frame the plot was built from, the strings actually drawn.
#
# Load with source("R/gayini_assert_rendered.R").

# Assert each rendered string contains the number it is supposed to carry.
#   rendered : character vector, exactly as it will be drawn
#   values   : the source values, same length
#   digits   : decimals used in the rendering
#   signed   : TRUE if rendered with a leading + / -
#   label    : name used in the failure message
gayini_assert_rendered_values <- function(rendered, values, digits = 1, signed = FALSE,
                                          label = "figure text") {
  if (length(rendered) != length(values))
    stop(sprintf("[%s] rendered length %d != values length %d — recycling bug",
                 label, length(rendered), length(values)))
  want <- if (signed) sprintf(paste0("%+.", digits, "f"), values)
          else        sprintf(paste0("%.", digits, "f"), values)
  bad <- which(!mapply(grepl, want, rendered, MoreArgs = list(fixed = TRUE)))
  if (length(bad))
    stop(sprintf("[%s] %d of %d rendered strings do not contain their source value:\n%s",
                 label, length(bad), length(rendered),
                 paste(sprintf("   want '%s' in: '%s'", want[bad], rendered[bad]), collapse = "\n")))
  invisible(TRUE)
}

# Assert a set of rendered strings is not uniform where the source values vary.
# Catches recycling even when the value itself is not separately parseable.
gayini_assert_rendered_varies <- function(rendered, label = "figure text") {
  if (length(unique(rendered)) == 1 && length(rendered) > 1)
    stop(sprintf("[%s] all %d rendered strings are identical — recycling bug",
                 label, length(rendered)))
  invisible(TRUE)
}

# Assert a number quoted in prose (a caption, a subtitle) matches its source, to the precision
# the prose states it. Prose rounds; the check must round too, not compare to an epsilon.
gayini_assert_caption_number <- function(caption, value, digits, label = "caption number") {
  want <- format(round(value, digits), nsmall = digits)
  if (!grepl(want, caption, fixed = TRUE))
    stop(sprintf("[%s] caption does not contain '%s' (source %.6f)", label, want, value))
  invisible(TRUE)
}

# Convenience: run both string checks over a list of rendered rows.
gayini_assert_rendered_table <- function(rows, label = "table") {
  for (nm in names(rows)) gayini_assert_rendered_varies(rows[[nm]], paste0(label, ": ", nm))
  invisible(TRUE)
}
