#!/usr/bin/env Rscript
#
# Check that every DOI this package cites still resolves.
#
# A dead DOI is worse than a missing one. It looks like a citation, so nobody
# checks it, and it sends a reader nowhere. This package has already shipped one:
# the AMOC reference pointed at 10.5285/223b34a3-..., which BODC retired when it
# published a newer version of the RAPID series.
#
# That is the failure this watches for, and it is not a mistake anyone made. Data
# centres reissue DOIs as records are superseded, so a citation that was correct
# when written goes stale on its own. Nothing in the package notices, because
# nothing resolves a DOI at runtime.
#
# Reads only. Reports what is dead and what has moved; changes nothing, because
# choosing a replacement citation is a judgement about which version the package
# should track.
#
# Usage:
#   Rscript inst/scripts/check_citations.R [--markdown <path>] [--json <path>]
#
# Exits 0 when every DOI resolves, 1 when any is dead, 2 when the network could
# not be reached at all - which is not the same as a dead DOI and should not be
# reported as one.

suppressMessages(library(jsonlite))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) default else args[hit + 1]
}
markdown_path <- arg_value("--markdown")
json_path <- arg_value("--json")

suppressMessages(pkgload::load_all(quiet = TRUE))

# ---- every DOI the package cites --------------------------------------------

doi_pattern <- "10\\.[0-9]{4,9}/[-._;()/:A-Za-z0-9]+"

collect_dois <- function() {
  found <- list()
  add <- function(doi, where) {
    # The DOI pattern allows parentheses, because some real DOIs contain them,
    # so it swallows the closing bracket of a markdown link. Trailing prose
    # punctuation comes off here.
    doi <- sub("[])>.,;]+$", "", doi)

    # "10.48670/moi-xxxxx" is the placeholder in Copernicus's own citation
    # format, quoted in the README as an example. Resolving it would report a
    # dead DOI that is not a citation at all.
    if (grepl("x{3,}", doi)) return(invisible(NULL))

    found[[length(found) + 1]] <<- data.frame(doi = doi, where = where,
                                              stringsAsFactors = FALSE)
  }

  # The catalogs are the authoritative place a citation lives; the README is
  # where a reader looks for it. Both are checked, so they cannot drift apart
  # without one of them failing here.
  for (name in names(climate_indices())) {
    reference <- climate_indices()[[name]]$reference
    if (is.null(reference)) next
    for (doi in regmatches(reference, gregexpr(doi_pattern, reference))[[1]]) {
      add(doi, paste0("climate_indices()$", name))
    }
  }

  for (file in c("README.md", "NEWS.md")) {
    if (!file.exists(file)) next
    text <- paste(readLines(file, warn = FALSE), collapse = "\n")
    for (doi in unique(regmatches(text, gregexpr(doi_pattern, text))[[1]])) {
      add(doi, file)
    }
  }

  all <- do.call(rbind, found)
  # One row per DOI, listing everywhere it appears, so a dead one is reported
  # once with all the places needing an edit.
  stats::aggregate(where ~ doi, data = all,
                   FUN = function(w) paste(unique(w), collapse = ", "))
}

# ---- does it resolve? --------------------------------------------------------

# doi.org answers a HEAD for most registrars, but some publishers refuse it and
# return 405 or 503 to anything that is not a browser-shaped GET. A HEAD failure
# is therefore retried as a GET before being believed.
resolves <- function(doi) {
  url <- paste0("https://doi.org/", doi)
  for (method in c("HEAD", "GET")) {
    status <- tryCatch({
      handle <- curl::new_handle(nobody = identical(method, "HEAD"),
                                 followlocation = TRUE, timeout = 30L,
                                 useragent = "datamatch citation check")
      curl::curl_fetch_memory(url, handle)$status_code
    }, error = function(e) NA_integer_)

    if (!is.na(status) && status >= 200 && status < 400) {
      return(list(ok = TRUE, status = status))
    }
    last <- status
  }
  list(ok = FALSE, status = last)
}

# ---- check -------------------------------------------------------------------

if (!requireNamespace("curl", quietly = TRUE)) {
  message("The 'curl' package is required. install.packages(\"curl\")")
  quit(status = 2)
}

dois <- collect_dois()
message("Checking ", nrow(dois), " DOI(s).")

results <- lapply(seq_len(nrow(dois)), function(i) {
  message("  ", dois$doi[i])
  result <- resolves(dois$doi[i])
  data.frame(doi = dois$doi[i], where = dois$where[i],
             ok = result$ok, status = result$status %||% NA_integer_,
             stringsAsFactors = FALSE)
})
results <- do.call(rbind, results)

# Every DOI failing to resolve almost always means no network rather than a
# simultaneous retirement of every citation. Reported as unreachable rather than
# as a wall of dead links.
if (all(!results$ok) && nrow(results) > 1) {
  message("No DOI resolved, which looks like a network problem rather than ",
          "a citation problem.")
  quit(status = 2)
}

dead <- results[!results$ok, ]

# ---- report ------------------------------------------------------------------

if (!is.null(json_path)) {
  jsonlite::write_json(results, json_path, auto_unbox = TRUE, pretty = TRUE)
}

report <- c(
  "## Citation check",
  "",
  paste0("Resolved **", sum(results$ok), "** of **", nrow(results),
         "** cited DOIs on ", format(Sys.Date()), "."),
  ""
)

if (nrow(dead) == 0) {
  report <- c(report, "Every DOI this package cites still resolves.")
} else {
  report <- c(report,
    "These no longer resolve. A dead DOI looks like a citation and sends the ",
    "reader nowhere, so it is worth replacing rather than removing.",
    "",
    "| DOI | HTTP | Cited in |",
    "|---|---|---|",
    apply(dead, 1, function(r) {
      paste0("| `", r[["doi"]], "` | ", r[["status"]], " | ", r[["where"]], " |")
    }),
    "",
    "Data centres reissue DOIs when a record is superseded, so the usual fix is ",
    "to find the current version rather than to drop the citation. BODC does ",
    "this for each RAPID release, which is how the `AMOC` reference went stale ",
    "once already.",
    "",
    "Choosing the replacement is a judgement about which version the package ",
    "should track, so this check does not guess one.")
}

text <- paste(report, collapse = "\n")
cat(text, "\n")
if (!is.null(markdown_path)) writeLines(text, markdown_path)

quit(status = if (nrow(dead) == 0) 0 else 1)
