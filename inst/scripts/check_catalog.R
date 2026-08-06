#!/usr/bin/env Rscript
#
# Check the package's variable catalog against the live Copernicus Marine
# catalogue.
#
# copernicus_variables() and forecast_variables() hard-code a product id, a
# dataset id, and a variable code for every name the package offers. Copernicus
# revises dataset identifiers periodically - a new version of a reanalysis gets a
# new id, and the old one is retired. Nothing in this package notices until a
# user's fetch fails, and it fails as an opaque unknown-dataset error from the
# CLI rather than as anything pointing at a stale catalog entry.
#
# This script asks the catalogue what actually exists and reports the difference.
# It reads the live catalogue only - it changes nothing, and it deliberately does
# not attempt to guess replacements, because choosing the successor to a retired
# dataset is a judgement about versions and coverage rather than a lookup.
#
# Usage:
#   Rscript inst/scripts/check_catalog.R [--json <path>] [--markdown <path>]
#
# Exits 0 when the catalog matches, 1 when anything has drifted, 2 when the
# catalogue could not be reached (which is not the same as drift, and should not
# be reported as though it were).

suppressMessages({
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) default else args[hit + 1]
}
markdown_path <- arg_value("--markdown")
json_path <- arg_value("--json")

# Load the package without installing it, so this runs against the working tree.
suppressMessages(pkgload::load_all(quiet = TRUE))

# ---- what the package claims -------------------------------------------------

claims <- function() {
  rows <- list()
  claim <- function(name, mode, frequency, entry, dataset_id) {
    rows[[length(rows) + 1]] <<- data.frame(
      name = name,
      mode = mode,
      frequency = frequency,
      product_id = entry$product_id,
      dataset_id = dataset_id,
      variable = entry$variable,
      stringsAsFactors = FALSE
    )
  }
  add <- function(catalog, mode) {
    for (name in names(catalog)) {
      entry <- catalog[[name]]
      claim(name, mode, "monthly", entry, entry$dataset_id)
      # Daily identifiers are as load-bearing as monthly ones and drift the same
      # way. NA is a deliberate "Copernicus publishes no daily version of this",
      # not an omission, so there is nothing to check against the catalogue.
      daily <- entry$daily_dataset_id
      if (!is.null(daily) && !is.na(daily)) {
        claim(name, mode, "daily", entry, daily)
      }
    }
  }
  add(copernicus_variables(), "reanalysis")
  add(forecast_variables(), "forecast")
  do.call(rbind, rows)
}

# ---- what the catalogue holds ------------------------------------------------

describe_product <- function(product_id) {
  out <- suppressWarnings(system2(
    "copernicusmarine",
    c("describe", "--product-id", product_id, "--return-fields", "all",
      "--disable-progress-bar"),
    stdout = TRUE, stderr = FALSE
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    return(NULL)
  }
  parsed <- tryCatch(jsonlite::fromJSON(paste(out, collapse = "\n"),
                                        simplifyVector = FALSE),
                     error = function(e) NULL)
  if (is.null(parsed) || length(parsed$products) == 0) return(NULL)
  parsed$products[[1]]
}

# A dataset's variables are spread across versions, parts, and services, and the
# same variable appears under several services. The union is what matters: the
# question is whether the code exists in that dataset at all.
dataset_variables <- function(dataset) {
  codes <- character()
  for (version in dataset$versions %||% list()) {
    for (part in version$parts %||% list()) {
      for (service in part$services %||% list()) {
        for (variable in service$variables %||% list()) {
          codes <- c(codes, variable$short_name)
        }
      }
    }
  }
  unique(codes)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- compare -----------------------------------------------------------------

wanted <- claims()
products <- unique(wanted$product_id)

message("Checking ", nrow(wanted), " catalog entries across ",
        length(products), " products.")

live <- list()
unreachable <- character()
for (product_id in products) {
  message("  fetching ", product_id)
  described <- describe_product(product_id)
  if (is.null(described)) {
    unreachable <- c(unreachable, product_id)
  } else {
    live[[product_id]] <- described
  }
}

# A product the catalogue does not return is ambiguous: it may have been retired,
# or the request may simply have failed. Retirement is real drift and a network
# failure is not, and the two cannot be told apart from here. Reported as a
# separate category rather than folded into either.
if (length(unreachable) == length(products)) {
  message("Could not reach the Copernicus catalogue for any product.")
  quit(status = 2)
}

findings <- list()
note <- function(...) findings[[length(findings) + 1]] <<- data.frame(..., stringsAsFactors = FALSE)

for (i in seq_len(nrow(wanted))) {
  row <- wanted[i, ]
  product <- live[[row$product_id]]

  if (is.null(product)) {
    note(name = row$name, mode = row$mode, frequency = row$frequency,
         kind = "product unreachable", detail = row$product_id)
    next
  }

  ids <- vapply(product$datasets, function(d) d$dataset_id, character(1))
  if (!row$dataset_id %in% ids) {
    note(name = row$name, mode = row$mode, frequency = row$frequency,
         kind = "dataset not in catalogue",
         detail = paste0(row$dataset_id, "  (product now offers: ",
                         paste(ids, collapse = ", "), ")"))
    next
  }

  dataset <- product$datasets[[which(ids == row$dataset_id)[1]]]
  codes <- dataset_variables(dataset)
  if (length(codes) > 0 && !row$variable %in% codes) {
    note(name = row$name, mode = row$mode, frequency = row$frequency,
         kind = "variable not in dataset",
         detail = paste0(row$variable, " not among: ", paste(codes, collapse = ", ")))
  }
}

findings <- if (length(findings) > 0) do.call(rbind, findings) else NULL

# ---- report ------------------------------------------------------------------

if (!is.null(json_path)) {
  jsonlite::write_json(
    list(checked = nrow(wanted), products = products,
         unreachable = unreachable,
         findings = if (is.null(findings)) list() else findings),
    json_path, auto_unbox = TRUE, pretty = TRUE)
}

report <- c(
  "## Copernicus catalog drift check",
  "",
  paste0("Checked **", nrow(wanted), "** catalog entries across **",
         length(products), "** products against the live Copernicus Marine ",
         "catalogue on ", format(Sys.Date()), "."),
  ""
)

if (is.null(findings)) {
  report <- c(report, paste("Everything in `copernicus_variables()` and",
                            "`forecast_variables()` still resolves.",
                            "No action needed."))
} else {
  report <- c(report,
    "The following entries no longer match the catalogue. Each one would fail ",
    "at fetch time with an unknown-dataset or unknown-variable error rather ",
    "than anything pointing here.",
    "",
    "| Name | Mode | Frequency | Problem | Detail |",
    "|---|---|---|---|---|",
    apply(findings, 1, function(r) {
      paste0("| `", r[["name"]], "` | ", r[["mode"]], " | ", r[["frequency"]],
             " | ", r[["kind"]], " | `", r[["detail"]], "` |")
    }),
    "",
    "Fix by updating the affected entry in `R/variables.R`. Choosing the ",
    "replacement is a judgement about which version and coverage the package ",
    "should track, so this check deliberately does not guess one.")
}

if (length(unreachable) > 0) {
  report <- c(report, "",
    paste0("> Could not reach the catalogue for: ",
           paste(paste0("`", unreachable, "`"), collapse = ", "),
           ". This may be a retired product or a transient failure - the two ",
           "are indistinguishable from here, so it is reported separately ",
           "rather than counted as drift."))
}

text <- paste(report, collapse = "\n")
cat(text, "\n")
if (!is.null(markdown_path)) writeLines(text, markdown_path)

quit(status = if (is.null(findings)) 0 else 1)
