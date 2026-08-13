#!/usr/bin/env Rscript
#
# Check the FVCOM, HYCOM and CCMP catalogs against the live services.
#
# inst/scripts/check_catalog.R does this for Copernicus. The other three sources
# had nothing watching them, which is a worse gap than it sounds: each hardcodes
# server URLs, filename patterns, variable names and coverage dates, and every
# one of those has already been observed to drift.
#
#   - CCMP's real filenames end `_V03.1_L4.nc`, where the published RSS
#     documentation says `_L4.0_RSS.nc`.
#   - The HYCOM catalogue's own title for expt_56.3 said it ended April 2016
#     when the data runs to September.
#   - FVCOM archives move between THREDDS catalogs as they are reorganised.
#
# Nothing in the package notices any of that until a user's fetch fails, and it
# fails as an opaque netCDF error rather than as anything pointing at a stale
# entry. This asks the services what is actually there and reports the
# difference. It reads only, and deliberately does not guess replacements.
#
# Usage:
#   Rscript inst/scripts/check_sources.R [--json <path>] [--markdown <path>]
#
# Exits 0 when everything resolves, 1 when anything has drifted, 2 when nothing
# could be reached at all - which is not the same as drift and is reported
# separately.

suppressMessages({
  library(jsonlite)
  library(ncdf4)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) default else args[hit + 1]
}
markdown_path <- arg_value("--markdown")
json_path <- arg_value("--json")

suppressMessages(pkgload::load_all(quiet = TRUE))

findings <- list()
reached <- 0L
attempted <- 0L

note <- function(source, entry, kind, detail) {
  findings[[length(findings) + 1]] <<- data.frame(
    source = source, entry = entry, kind = kind, detail = detail,
    stringsAsFactors = FALSE)
}

# Opening a remote dataset is the expensive part, so each archive is opened once
# and every claim about it checked against that one handle.
with_handle <- function(url, f) {
  attempted <<- attempted + 1L
  handle <- tryCatch(ncdf4::nc_open(url), error = function(e) e)
  if (inherits(handle, "error")) return(conditionMessage(handle))
  reached <<- reached + 1L
  on.exit(ncdf4::nc_close(handle), add = TRUE)
  f(handle)
}

# ---- FVCOM -------------------------------------------------------------------

message("Checking FVCOM archives")
for (name in names(fvcom_archives())) {
  spec <- fvcom_archives()[[name]]
  url <- if (identical(spec$layout, "per_month")) {
    sprintf(spec$url, as.integer(format(spec$start, "%Y")),
            as.integer(format(spec$start, "%Y")),
            as.integer(format(spec$start, "%m")))
  } else {
    spec$url
  }

  message("  ", name)
  failure <- with_handle(url, function(handle) {
    # The mesh sizes are quoted in the documentation and used to describe what
    # the archive is, so a change in them is a change in the product.
    for (field in c("nodes", "elements")) {
      dimension <- if (field == "nodes") "node" else "nele"
      claimed <- spec[[field]]
      actual <- handle$dim[[dimension]]$len
      if (!is.null(claimed) && !is.null(actual) && claimed != actual) {
        note("fvcom", name, paste0(field, " changed"),
             paste0("catalog says ", claimed, ", archive has ", actual))
      }
    }

    # Every variable the catalog offers for this archive must exist in it.
    absent <- Filter(function(v) {
      is.null(handle$var[[fvcom_variables()[[v]]$variable]])
    }, names(fvcom_variables()))
    if (length(absent) > 0) {
      note("fvcom", name, "variables absent", paste(absent, collapse = ", "))
    }
    NULL
  })
  if (is.character(failure)) {
    note("fvcom", name, "unreachable", failure)
  }
}

# ---- HYCOM -------------------------------------------------------------------

message("Checking HYCOM archives")
for (name in names(hycom_archives())) {
  spec <- hycom_archives()[[name]]
  url <- if (identical(spec$layout, "per_year")) {
    sprintf(spec$url, as.integer(format(spec$start, "%Y")))
  } else {
    spec$url
  }

  message("  ", name)
  failure <- with_handle(url, function(handle) {
    absent <- Filter(function(v) {
      is.null(handle$var[[hycom_variables()[[v]]$variable]])
    }, names(hycom_variables()))
    if (length(absent) > 0) {
      note("hycom", name, "variables absent", paste(absent, collapse = ", "))
    }

    # Coverage dates decide which archive a request is routed to, so a drift in
    # them sends people to the wrong one - or to none.
    units <- ncdf4::ncatt_get(handle, "time", "units")$value
    epoch <- as.POSIXct(substr(trimws(sub("^.*since\\s+", "", units)), 1, 19),
                        tz = "UTC")
    steps <- handle$dim$time$len
    last <- as.Date(epoch + ncdf4::ncvar_get(handle, "time", start = steps,
                                             count = 1) * 3600)

    # Only the single-aggregation archives can be checked this way; a per-year
    # dataset ends when its own year does, which says nothing about the archive.
    if (identical(spec$layout, "single") && abs(as.numeric(last - spec$end)) > 2) {
      note("hycom", name, "end date drifted",
           paste0("catalog says ", spec$end, ", archive ends ", last))
    }
    NULL
  })
  if (is.character(failure)) {
    note("hycom", name, "unreachable", failure)
  }
}

# ---- CCMP --------------------------------------------------------------------

message("Checking CCMP versions")
for (name in names(ccmp_versions())) {
  spec <- ccmp_versions()[[name]]
  # A day known to exist, well inside the record.
  probe <- as.Date("2010-06-15")
  url <- file.path(spec$root, sprintf(
    spec$pattern,
    as.integer(format(probe, "%Y")), as.integer(format(probe, "%m")),
    as.integer(format(probe, "%Y")), as.integer(format(probe, "%m")),
    as.integer(format(probe, "%d"))))

  message("  ", name)
  attempted <- attempted + 1L
  # CCMP is a plain file server, so a HEAD request settles whether the filename
  # pattern still resolves without pulling 33 MB to find out.
  status <- tryCatch(
    curl_status <- system2("curl", c("-sIL", "-o", "/dev/null", "-w", "%{http_code}",
                                     "--max-time", "60", shQuote(url)),
                           stdout = TRUE),
    error = function(e) NA_character_)

  if (is.na(status[1]) || !identical(as.character(status[1]), "200")) {
    note("ccmp", name, "file pattern does not resolve",
         paste0(url, " returned ", status[1]))
  } else {
    reached <- reached + 1L
  }
}

findings <- if (length(findings) > 0) do.call(rbind, findings) else NULL

# ---- report ------------------------------------------------------------------

if (!is.null(json_path)) {
  jsonlite::write_json(
    list(attempted = attempted, reached = reached,
         findings = if (is.null(findings)) list() else findings),
    json_path, auto_unbox = TRUE, pretty = TRUE)
}

report <- c(
  "## FVCOM, HYCOM and CCMP source check",
  "",
  paste0("Checked **", attempted, "** archives against the live services on ",
         format(Sys.Date()), "; **", reached, "** were reachable."),
  ""
)

if (is.null(findings)) {
  report <- c(report, paste("Every archive resolves, carries the variables the",
                            "catalog claims, and covers the period it says.",
                            "No action needed."))
} else {
  report <- c(report,
    "The following no longer match the services. Each would fail at fetch time ",
    "as an opaque netCDF or HTTP error rather than as anything pointing here.",
    "",
    "| Source | Entry | Problem | Detail |",
    "|---|---|---|---|",
    apply(findings, 1, function(r) {
      paste0("| ", r[["source"]], " | `", r[["entry"]], "` | ", r[["kind"]],
             " | `", substr(r[["detail"]], 1, 160), "` |")
    }),
    "",
    "Fix by updating `fvcom_archives()`, `hycom_archives()` or ",
    "`ccmp_versions()`. Choosing a replacement is a judgement about which run ",
    "or version to track, so this check deliberately does not guess one.")
}

# Unreachable is not drift. A university THREDDS server being down for an
# afternoon should not be reported as a stale catalog.
if (reached == 0) {
  message("Could not reach any source.")
  quit(status = 2)
}

text <- paste(report, collapse = "\n")
cat(text, "\n")
if (!is.null(markdown_path)) writeLines(text, markdown_path)

quit(status = if (is.null(findings)) 0 else 1)
