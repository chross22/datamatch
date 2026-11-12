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
#                                        [--history <dir>]
#
# Exits 0 when nothing has drifted, 1 when anything has, 2 when nothing could be
# reached at all - which is not the same as drift and is reported separately.
#
# An archive that cannot be opened is not drift either, at first. The HYCOM
# THREDDS server fails to open a different archive most weeks and then serves it
# the next, so one failure says nothing about the catalog. An archive is only
# reported as drifted once it has been unreachable in UNREACHABLE_RUNS
# consecutive weeks, counted from the --json reports of earlier runs placed
# under --history: one report per ISO week, so a manual rerun does not count as
# another week, and none from a run that reached nothing at all. Without
# --history, unreachable archives are listed but never counted as drift.

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
history_dir <- arg_value("--history")

# Consecutive checks an archive must fail before it counts as drift. Weekly runs,
# so three is three weeks: long enough to outlast a server outage, short enough
# that a moved archive is reported within the month.
UNREACHABLE_RUNS <- 3L

# Each open is retried before it is recorded as a failure, since most of the
# failures seen are a server that refuses one request and answers the next.
OPEN_ATTEMPTS <- 3L
OPEN_BACKOFF_SECONDS <- c(30, 90)

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
  for (attempt in seq_len(OPEN_ATTEMPTS)) {
    handle <- tryCatch(ncdf4::nc_open(url), error = function(e) e)
    if (!inherits(handle, "error")) break
    if (attempt < OPEN_ATTEMPTS) {
      message("    open failed (", conditionMessage(handle), "); retrying in ",
              OPEN_BACKOFF_SECONDS[attempt], " s")
      Sys.sleep(OPEN_BACKOFF_SECONDS[attempt])
    }
  }
  if (inherits(handle, "error")) {
    return(paste0(conditionMessage(handle), " (", OPEN_ATTEMPTS, " attempts)"))
  }
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
    # the archive is, so a change in them is a change in the product - except
    # where the catalog already says the mesh moves between files. There the
    # sizes are descriptive, the reader takes the mesh from each file, and the
    # file opened here (the first month) need not be one the sizes describe:
    # GOM7's January 2025 file is on an older mesh than the one quoted.
    fields <- if (isTRUE(spec$mesh_varies)) character(0) else c("nodes", "elements")
    for (field in fields) {
      dimension <- if (field == "nodes") "node" else "nele"
      claimed <- spec[[field]]
      actual <- handle$dim[[dimension]]$len
      if (!is.null(claimed) && !is.null(actual) && claimed != actual) {
        note("fvcom", name, paste0(field, " changed"),
             paste0("catalog says ", claimed, ", archive has ", actual))
      }
    }

    # Every variable the catalog offers for this archive must exist in it. An
    # archive that declares a subset is held to that subset: GOM7 saves no
    # surface forcing or wind stress, says so, and refuses requests for them.
    offered <- spec$variables %||% names(fvcom_variables())
    absent <- Filter(function(v) {
      is.null(handle$var[[fvcom_variables()[[v]]$variable]])
    }, offered)
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

# ---- unreachable archives: drift only when it persists ---------------------

# Earlier reports, newest first, at most one per ISO week. Each records when it
# ran and the entries it could not open.
#
# The threshold is a number of weeks, and a report is not a week. A
# workflow_dispatch rerun on the same day as the scheduled run, or a second
# rerun later that week, would otherwise count as further consecutive failures
# and could declare drift within hours. So the history is thinned to the newest
# report in each ISO week, and the week this run falls in is left to this run.
#
# A report from a run that reached nothing at all (exit 2) is left out entirely.
# That was the runner's network or a general outage, not evidence about any one
# archive, and counting it would let one bad Monday advance every streak.
read_history <- function(history_dir, today = Sys.Date()) {
  if (is.null(history_dir) || !dir.exists(history_dir)) return(list())
  files <- list.files(history_dir, pattern = "\\.json$", recursive = TRUE,
                      full.names = TRUE)
  history <- Filter(Negate(is.null), lapply(files, function(f) {
    tryCatch(jsonlite::read_json(f, simplifyVector = TRUE),
             error = function(e) NULL)
  }))
  history <- Filter(function(h) {
    !is.null(h$date) && !is.na(as.Date(h$date, optional = TRUE)) &&
      !isTRUE(h$outage) && !identical(as.integer(h$reached), 0L)
  }, history)
  if (length(history) == 0) return(list())

  # Ordered by the full timestamp where a report has one, so two reports from
  # the same day do not tie; older reports carry only the date.
  stamp <- vapply(history, function(h) h$time %||% paste0(h$date, "T00:00:00Z"),
                  "")
  history <- history[order(stamp, decreasing = TRUE)]

  week <- vapply(history, function(h) iso_week(as.Date(h$date)), "")
  keep <- !duplicated(week) & week != iso_week(today)
  history[keep]
}

iso_week <- function(date) format(date, "%G-W%V")

# The Monday that starts a date's ISO week, as a day count, so that weeks can be
# checked for adjacency across a year boundary.
week_start <- function(date) {
  date <- as.Date(date)
  as.numeric(date) - (as.integer(format(date, "%u")) - 1L)
}

# Consecutive weeks, this one included, in which an entry could not be opened.
# A week with no report breaks the streak: nothing is known about it, and
# counting across the gap would treat two failures a month apart as a run.
streak <- function(key, history, today = Sys.Date()) {
  n <- 1L
  expected <- week_start(today) - 7
  for (h in history) {
    if (week_start(h$date) != expected) break
    if (!key %in% h$unreachable) break
    n <- n + 1L
    expected <- expected - 7
  }
  n
}

history <- read_history(history_dir)

entry_key <- function(source, entry) paste(source, entry, sep = "/")

unreachable_now <- if (is.null(findings)) character(0) else
  with(findings[findings$kind == "unreachable", , drop = FALSE],
       entry_key(source, entry))

transient <- NULL
if (!is.null(findings)) {
  is_unreachable <- findings$kind == "unreachable"
  runs <- vapply(entry_key(findings$source, findings$entry), streak, 1L,
                 history = history)
  persistent <- is_unreachable & runs >= UNREACHABLE_RUNS
  findings$kind[persistent] <- paste0("unreachable in ", runs[persistent],
                                      " consecutive checks")
  transient <- findings[is_unreachable & !persistent, , drop = FALSE]
  transient$runs <- runs[is_unreachable & !persistent]
  findings <- findings[!is_unreachable | persistent, , drop = FALSE]
  if (nrow(findings) == 0) findings <- NULL
  if (nrow(transient) == 0) transient <- NULL
}

if (!is.null(json_path)) {
  # A run that reached nothing records no per-archive failures, so that a later
  # run does not count a general outage toward any archive's streak.
  outage <- reached == 0
  jsonlite::write_json(
    list(date = format(Sys.Date()),
         time = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
         event = Sys.getenv("GITHUB_EVENT_NAME", "local"),
         attempted = attempted, reached = reached, outage = outage,
         unreachable = if (outage) character(0) else unreachable_now,
         findings = if (is.null(findings) || outage) list() else findings),
    json_path, auto_unbox = TRUE, pretty = TRUE)
}

# ---- report ------------------------------------------------------------------

table_rows <- function(df) {
  apply(df, 1, function(r) {
    paste0("| ", r[["source"]], " | `", r[["entry"]], "` | ", r[["kind"]],
           " | `", substr(r[["detail"]], 1, 160), "` |")
  })
}

report <- c(
  "## FVCOM, HYCOM and CCMP source check",
  "",
  paste0("Checked **", attempted, "** archives against the live services on ",
         format(Sys.Date()), "; **", reached, "** were reachable."),
  ""
)

if (is.null(findings)) {
  report <- c(report, paste("Every reachable archive resolves, carries the",
                            "variables the catalog claims, and covers the",
                            "period it says. No action needed."))
} else {
  report <- c(report,
    "The following no longer match the services. Each would fail at fetch time ",
    "as an opaque netCDF or HTTP error rather than as anything pointing here.",
    "",
    "| Source | Entry | Problem | Detail |",
    "|---|---|---|---|",
    table_rows(findings),
    "",
    "Fix by updating `fvcom_archives()`, `hycom_archives()` or ",
    "`ccmp_versions()`. Choosing a replacement is a judgement about which run ",
    "or version to track, so this check deliberately does not guess one.")
}

if (!is.null(transient)) {
  transient$kind <- paste0("unreachable (", transient$runs, " of ",
                           UNREACHABLE_RUNS, " checks)")
  report <- c(report, "",
    paste0("Not yet counted as drift: these could not be opened after ",
           OPEN_ATTEMPTS, " attempts, but have not failed in ", UNREACHABLE_RUNS,
           " consecutive checks."),
    "",
    "| Source | Entry | Problem | Detail |",
    "|---|---|---|---|",
    table_rows(transient))
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
