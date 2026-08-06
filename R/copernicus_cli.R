#' Where downloaded Copernicus files are kept
#'
#' Copernicus subsets are slow to fetch and rarely change, so `accessEnvDat()`
#' writes each one to disk and reads it back on later calls. This resolves where
#' that cache lives.
#'
#' The location is taken from the first of these that is set:
#'
#' \enumerate{
#'   \item `getOption("datamatch.cache")`
#'   \item the `DATAMATCH_CACHE` environment variable
#'   \item [tools::R_user_dir()], the per-package location R reserves for exactly
#'     this purpose
#' }
#'
#' The third is a working default, so nothing has to be configured before the
#' first download. Set one of the first two to put the cache on a larger disk, or
#' to share one cache between projects:
#'
#' ```
#' options(datamatch.cache = "~/data/copernicus")   # in .Rprofile
#' ```
#'
#' @section Moving an existing cache:
#' Earlier versions of this package took the cache root from a `~/.copernicusdata`
#' file, by way of the `copernicus` package. That file is no longer read. To keep
#' using files downloaded under the old scheme, point the option at the same
#' directory rather than moving anything:
#'
#' ```
#' options(datamatch.cache = readLines("~/.copernicusdata"))
#' ```
#'
#' @param ... path components appended to the cache root, as [file.path()]
#' @return the resolved path, with its parent directory created if needed
#' @keywords internal
copernicus_cache <- function(...) {
  root <- getOption("datamatch.cache", default = Sys.getenv("DATAMATCH_CACHE"))
  if (!nzchar(root)) {
    root <- tools::R_user_dir("datamatch", which = "cache")
  }

  if (length(list(...)) == 0) {
    dir.create(root, recursive = TRUE, showWarnings = FALSE)
    return(root)
  }

  path <- file.path(root, ...)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}

#' Locate the Copernicus Marine command line tool
#'
#' Downloads go through `copernicusmarine`, the official Python client. It is not
#' an R package and is not installed with this one.
#'
#' The executable is taken from `getOption("datamatch.copernicusmarine")` when
#' set, and otherwise looked up on the `PATH`. Setting the option explicitly is
#' worth doing when it lives in a conda environment that RStudio does not
#' inherit the `PATH` of — a common source of "works in the terminal, fails in R":
#'
#' ```
#' options(datamatch.copernicusmarine = "~/miniconda3/bin/copernicusmarine")
#' ```
#'
#' @return the path to the executable
#' @keywords internal
copernicus_app <- function() {
  app <- getOption("datamatch.copernicusmarine", default = "copernicusmarine")

  if (!nzchar(Sys.which(app)) && !file.exists(app)) {
    stop("Could not find the Copernicus Marine client ('", app, "').\n",
         "Install it with:  pip install copernicusmarine\n",
         "Then sign in once with:  copernicusmarine login\n",
         "If it is installed but not on R's PATH (common with conda), set:\n",
         "  options(datamatch.copernicusmarine = \"/full/path/to/copernicusmarine\")",
         call. = FALSE)
  }
  app
}

#' Build the argument vector for a `copernicusmarine subset` call
#'
#' Kept separate from the call itself so the arguments can be inspected and
#' tested without contacting the API.
#'
#' Long-form flags are used throughout (`--dataset-id` rather than `-i`). The
#' short forms are aliases the client has changed before, and a renamed flag
#' fails as an unrecognised option rather than as anything self-explanatory.
#'
#' @param dataset_id <char> Copernicus dataset identifier
#' @param vars <char> variable codes to request
#' @param bb bounding box: a named list or vector with `xmin`, `xmax`, `ymin`,
#'   `ymax`, or an `sf`/`sfc` object to take the bounding box of
#' @param depth <numeric> length-2 depth range in metres
#' @param time <Date> or <char> length 1 or 2; a single value requests one instant
#' @param ofile <char> full path of the file to write
#' @param overwrite <logical> pass `--overwrite`
#' @param dry_run <logical> pass `--dry-run`, which validates the request against
#'   the API without downloading anything
#' @param log_level <char> one of the client's levels: DEBUG, INFO, WARN, ERROR,
#'   CRITICAL, QUIET
#' @return character vector of arguments, suitable for [system2()]
#' @keywords internal
build_copernicus_args <- function(dataset_id, vars, bb, depth, time, ofile,
                                  overwrite = TRUE, dry_run = FALSE,
                                  log_level = "QUIET") {
  args <- c("subset", "--dataset-id", dataset_id[1],
            "--log-level", toupper(log_level))

  if (!is.null(vars)) {
    # One --variable per code; the client has no comma-separated form.
    args <- c(args, as.vector(rbind("--variable", vars)))
  }

  if (!is.null(bb)) {
    if (inherits(bb, c("sf", "sfc"))) {
      bb <- sf::st_bbox(bb)
    } else {
      missing <- setdiff(c("xmin", "xmax", "ymin", "ymax"), names(bb))
      if (length(missing) > 0) {
        stop("bounding_box is missing: ", paste(missing, collapse = ", "),
             call. = FALSE)
      }
    }
    args <- c(args,
              "--minimum-longitude", sprintf("%0.4f", bb[["xmin"]]),
              "--maximum-longitude", sprintf("%0.4f", bb[["xmax"]]),
              "--minimum-latitude", sprintf("%0.4f", bb[["ymin"]]),
              "--maximum-latitude", sprintf("%0.4f", bb[["ymax"]]))
  }

  if (!is.null(depth) && !all(is.na(depth))) {
    args <- c(args,
              "--minimum-depth", sprintf("%0.4f", as.numeric(depth[1])),
              "--maximum-depth", sprintf("%0.4f", as.numeric(depth[2])))
  }

  if (!is.null(time)) {
    if (length(time) == 1) time <- c(time, time)
    time <- if (inherits(time, "character")) {
      format(as.Date(time, format = "%Y-%m-%d"), "%Y-%m-%dT%H:%M:%S")
    } else {
      format(time, "%Y-%m-%dT%H:%M:%S")
    }
    args <- c(args, "--start-datetime", time[1], "--end-datetime", time[2])
  }

  # The progress bar is always suppressed: output is captured rather than
  # streamed, and a carriage-return progress bar in a captured character vector
  # is noise that obscures the real error when one occurs.
  args <- c(args, "--disable-progress-bar")
  if (overwrite) args <- c(args, "--overwrite")
  if (dry_run) args <- c(args, "--dry-run")

  # Output directory and filename are passed separately; the client has no
  # single "full path" argument.
  c(args, "--output-directory", dirname(ofile), "--output-filename", basename(ofile))
}

#' Download a Copernicus subset through the command line client
#'
#' Wraps one `copernicusmarine subset` call. Arguments are passed to [system2()]
#' as a character vector rather than pasted into a shell string, so paths
#' containing spaces are handled by the process boundary instead of by quoting.
#'
#' @section Retries:
#' The API is intermittently unavailable under load, and a failed request is
#' usually transient. Failures are retried `tries` times with a pause between,
#' and only a run of failures is raised as an error.
#'
#' That error carries the client's own output. A download that fails and returns
#' quietly would surface later as an unreadable file, at the point of
#' `terra::rast()`, with nothing left to say why.
#'
#' @inheritParams build_copernicus_args
#' @param tries <integer> number of attempts before giving up
#' @param wait <numeric> seconds to wait between attempts
#' @param verbose <logical> echo the command and the client's output
#' @return `0`, invisibly, on success; errors otherwise
#' @keywords internal
download_copernicus_subset <- function(dataset_id, vars, bb, depth, time, ofile,
                                       overwrite = TRUE, tries = 3, wait = 10,
                                       verbose = FALSE, dry_run = FALSE,
                                       log_level = "QUIET") {
  app <- copernicus_app()
  args <- build_copernicus_args(dataset_id = dataset_id, vars = vars, bb = bb,
                                depth = depth, time = time, ofile = ofile,
                                overwrite = overwrite, dry_run = dry_run,
                                log_level = log_level)

  if (verbose) cat("CMD:", app, paste(args, collapse = " "), "\n")

  for (attempt in seq_len(tries)) {
    output <- suppressWarnings(system2(app, args, stdout = TRUE, stderr = TRUE))
    status <- attr(output, "status") %||% 0

    if (verbose) cat(paste(output, collapse = "\n"), "\n")
    if (status == 0) return(invisible(0))

    if (attempt < tries) Sys.sleep(wait)
  }

  stop("Copernicus download failed after ", tries, " attempt(s).\n",
       "  dataset: ", dataset_id[1], "\n",
       "  time:    ", paste(format(time), collapse = " to "), "\n",
       "  file:    ", ofile, "\n",
       "Client output:\n", paste(utils::tail(output, 20), collapse = "\n"),
       call. = FALSE)
}

#' The cache filename for one day's download
#'
#' A cached file is only reusable by a request that would have produced the same
#' file, so everything that changes the file has to be in its name: the
#' variables, the bounding box and the depth as well as the product, dataset and
#' date.
#'
#' Leaving them out was a real bug rather than a theoretical one. A request for
#' `thetao` over a small box wrote a file that a later request for
#' `thetao, so` over a large one then reused - and the second request either
#' failed for the missing variable, which is the lucky case, or silently
#' returned a grid covering the wrong area, which is not. Two people sharing a
#' cache, or one person narrowing a study area between runs, hit this without
#' doing anything unusual.
#'
#' The identifying part is a short hash rather than the values spelled out. A
#' dozen variables and four coordinates make a filename longer than some file
#' systems accept, and the date and dataset stay readable at the front so the
#' cache can still be browsed.
#'
#' @param product_id,dataset_id the Copernicus product and dataset
#' @param time the day, as a `Date`
#' @param vars variable codes requested
#' @param bb the bounding box
#' @param depth the depth range
#' @return a filename
#' @keywords internal
cache_filename <- function(product_id, dataset_id, time, vars, bb, depth) {
  key <- paste(
    paste(sort(vars), collapse = ","),
    # Rounded, so that floating-point noise in a bounding box does not make two
    # identical requests miss each other.
    paste(round(unlist(bb[c("xmin", "xmax", "ymin", "ymax")]), 6), collapse = ","),
    paste(round(as.numeric(depth), 6), collapse = ","),
    sep = "|"
  )
  paste0(product_id, "_", dataset_id, "_", time, "_", short_hash(key), ".nc")
}

#' A short, stable hash of a string
#'
#' Base R has no string hash, and this needs no cryptographic strength: it
#' distinguishes cache keys, and a collision would have to occur between two
#' requests for the same dataset on the same day. Written out rather than taken
#' from a package so that the cache does not gain a dependency.
#'
#' @param x a string
#' @return eight hexadecimal characters
#' @keywords internal
short_hash <- function(x) {
  bytes <- as.integer(charToRaw(paste(x, collapse = "")))
  # FNV-1a, in doubles. R has no unsigned 32-bit integer, so the modulus is
  # applied at every step to keep the value inside what a double represents
  # exactly.
  hash <- 2166136261
  for (byte in bytes) {
    hash <- bitwXor(hash %% 2^31, byte)
    hash <- (hash * 16777619) %% 2^31
  }
  sprintf("%08x", as.integer(hash %% 2^31))
}
