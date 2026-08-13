# datamatch 0.1.0

## Bug fixes

* **A `yearday` column could be matched on as though it were the year.**
  `matchData()` finds a table's time columns by prefix, and `yearday` begins with
  `year`. With no plain `year` column beside it to win the tiebreak, it was
  renamed to `YEAR` without complaint, and every row went into a period no
  `source` covers — so the join came back all `NA` behind a warning about
  uncovered periods, which reads like a gap in the data rather than a mistake.

  Day-of-year names — `yearday`, `dayofyear`, `jday`, `doy` and the usual
  variants — are now never matched on, for any time column. A table carrying one
  and no real year or day column gets the missing-column error instead.

* **The missing-column error now names the columns it passed over.** The lookup
  stays a prefix match, so `obs_month` and `survey_year` are still not
  recognised. Rather than only saying what it looked for, the error lists the
  similar names that are present and asks for the intended one to be renamed.
  Suggesting is not selecting: widening the rule to a contains match would have
  swept up `jday` and `yearday` alongside `obs_month`, trading a clear error for
  a wrong answer.

* **Variables could be silently mislabelled in multi-variable downloads.** This
  can affect results already in hand, so it is worth checking rather than just
  reading.

  `accessEnvDat()` named result columns positionally from `vars`. Copernicus
  returns layers in the NetCDF's own order, which is alphabetical by variable
  code, so the two agreed only by coincidence. Requesting `c("SST", "SSS")` sends
  `c("thetao", "so")` and gets back `so` first, so the columns were labelled the
  wrong way round:

  ```
  # before the fix, Gulf of Maine, January 2010
  SST = 32.69     # 32.69 PSU of salinity, in the temperature column
  SSS = 6.18      # 6.18 C of temperature, in the salinity column
  ```

  There was no warning. Any download of two or more variables whose requested
  order differed from the alphabetical order of their Copernicus codes was
  affected. Single-variable downloads never were, and neither were requests that
  happened to be in alphabetical code order.

  *Checking existing results:* look for a column whose values sit in the wrong
  range for its name, such as salinity near 32 in an `SST` column. Re-running the
  fetch fixes it. The cached NetCDF files were always correct; only the naming
  was wrong.

  *The fix:* `order_layers()` strips the depth suffix that 3D variables carry
  (`thetao_depth=0.494025`) and selects layers by matching the variable code, so
  naming cannot drift from content.

* **`Expected N variable column(s)` blamed the depth range for every cause.** The
  check that caught the problem above could only count columns, so it guessed:

  ```
  Error: Expected 4 variable column(s) but the download returned 2. This usually
  means the depth range spans several model levels...
  ```

  For a request whose real problem was two variables the dataset never returned,
  that pointed in the wrong direction. The two causes are now distinguished: a
  variable the download omitted is named along with what did arrive, and a code
  appearing on several layers is reported as the depth-range problem it is, with
  the levels it returned.

* **Daily datasets whose identifier ends in `P1D` fetched one day per month.**
  `accessEnvDat()` decided whether a dataset was daily by reading a single
  character three from the end of `dataset_id`. That is `D` in
  `..._P1D-m`, which the model products use, but `P` in `..._P1D`, which the
  satellite ocean colour products use — so an explicitly passed ocean colour
  daily dataset was treated as monthly and only day 1 of each month was
  downloaded. The frequency token is now matched as such.

* **matchData() returned rows grouped by period, not in the order they went
  in.** Rows are processed a period at a time, so a table whose periods were
  interleaved came back reordered. Anyone aligning the result against the input
  by position - `cbind()`, or assigning a column straight across - would have
  got silently mismatched rows. The order is now restored before returning.

* **Sparse daily data could be matched as though it were monthly.**
  `detect_temporal_resolution()` infers daily data from more than one day within
  a month, so a set of survey dates — one per month — was indistinguishable from
  monthly data by inspection, and `matchData()` would join by month and ignore
  the day.

  `accessEnvDat()` knows which dataset it fetched, so it now records the step on
  the result and `detect_temporal_resolution()` trusts that over the heuristics.
  Passing `temporal_resolution` explicitly still overrides both.

* **Failed downloads surfaced as an unreadable file.** A run of failures warned
  and returned a status code the caller ignored, so the error appeared later from
  `terra::rast()` on a file that was never written. Failures now raise where they
  happen, carrying the Copernicus client's output.

## Breaking changes

* **`matchData()`'s arguments are now `dat` and `source`**, replacing
  `speciesDat` and `envDat`.

  The function was never specific to species observations or environmental data.
  It is a spatiotemporal nearest-feature join between two `sf` point objects, and
  works as well for tag positions against a model field, moorings against
  satellite retrievals, or one gridded product against another. The old names
  described one use of it as though it were the only one.

  **The old names still work**, with a warning, so existing scripts and
  `taupatch` keep running. They will be removed in a later version.

  ```r
  matchData(observations, env)                 # positional, unchanged
  matchData(dat = observations, source = env)  # new names
  matchData(speciesDat = obs, envDat = env)    # still works, warns
  ```

  One related change: a `source` column whose name collides with one already in
  `dat` is now suffixed **`.matched`** rather than `.env`, for the same reason.

* **The `BigelowLab/copernicus` dependency is gone.** It was used in two places,
  both in `accessEnvDat()`, and both are now internal. This removes the
  `Remotes:` field and the hand-created `~/.copernicusdata` file that a new
  machine previously needed.

  **The download cache has moved** to `tools::R_user_dir("datamatch", "cache")`.
  Files downloaded under the old scheme are not found there and would be
  re-downloaded. To keep using them:

  ```r
  options(datamatch.cache = readLines("~/.copernicusdata"))   # in .Rprofile
  ```

  `getOption("datamatch.cache")` and the `DATAMATCH_CACHE` environment variable
  both override the default. The Copernicus client is located via
  `getOption("datamatch.copernicusmarine")` or the `PATH`, and a missing client
  now says so with install instructions.

## New features

* **Daily data.** `accessEnvDat(frequency = "daily")` fetches the daily datasets
  rather than the monthly means, expanding each requested month into its days.

  Daily is not simply the monthly identifier at a finer step, and the catalog
  records what Copernicus actually publishes. `PH`, `PP`, `DIATO` and `DINO` are
  monthly composites only, and requesting them daily is refused before anything
  is downloaded. Daily `CHL` comes from the gap-free interpolated ocean colour
  dataset, whose cloud gaps Copernicus has already filled — so
  `fill_satellite_gaps()` has nothing to do on it, and `accessEnvDat()` says so
  when it makes the substitution.

  `variable_dataset()` takes `frequency` too, and returns `NA` where no daily
  dataset exists.

  `dates` names the exact dates to fetch, which is the argument to use when
  matching daily data to observations:

  ```r
  accessEnvDat(vars = "SST", dates = unique(observations$date), bounding_box = bb)
  ```

  Survey dates differ from month to month, and a day-of-month rule does not
  describe them. `YYYYMMDD` strings, `YYYY-MM-DD` strings, and `Date` objects
  are all accepted. Dates are sorted and deduplicated, and a date the calendar
  does not have is an error naming it rather than a silently dropped request.

  `dates` replaces `years` and `months`, which must not be given alongside it,
  and implies `frequency = "daily"`. Passing it with an explicit
  `frequency = "monthly"` is a contradiction and an error.

  Since it fetches only the dates named, it is also how a long record is sampled
  rather than fetched whole.

  **Monthly remains the default.** A call naming neither `frequency` nor `days`
  fetches monthly means exactly as before.

* **Downloads run in parallel.** Only the days not already cached are fetched,
  and they go out `n_workers` at a time (default 4). A month of daily SST and
  SSS takes about 40 seconds rather than about 160.

  A failed day no longer abandons the rest: every day is attempted, successful
  ones stay in the cache, and the error names each day that failed, so
  re-running the same call retries only those. Reading and converting the files
  stays in the calling session — those are local reads, and returning each day's
  data frame from a worker would cost more than the read saves.

* **Resampling.** `upscale_grid()`, `downscale_grid()`, `upscale_time()`, and
  `downscale_time()` move data between grids and time steps, each with a choice
  of method. Targets may be a resolution or another object's grid. Aggregation
  guards partial coverage with `min_coverage`; interpolation defaults to the
  methods that do not invent structure.

* **Plotting.** `plot_env()`, `plot_coverage()`, `plot_series()`, and
  `plot_matched()`, in base graphics, each returning the data it drew.

* **`TPI`** joins the bathymetry covariates. A cell's depth relative to its
  neighbours, which separates banks from basins where plain depth cannot.

* **`LCR`**, the Labrador Current retroflection index, joins the climate index
  catalog. Published with Jutras et al. (2023) and cited in `index_dictionary()`.

* **Every climate index now declares its `units`**, surfaced in
  `index_dictionary()`. Most are standardized anomalies, in standard deviations
  rather than anything physical; only `AMO` (degrees C) and `AMOC` (Sverdrups)
  carry real units. A coefficient fitted to one of those is not comparable with
  one fitted to `NAO`, and a table of model output gave no way to tell.

* **`AMOC`**, the overturning transport measured by the RAPID array at 26.5°N,
  joins it too. Unlike the other indices this is a direct measurement rather than
  a pressure or SST pattern — which is also its limitation: it begins in April
  2004 and is recorded far south of the shelf, so it describes the basin-scale
  circulation the Labrador and slope currents sit within rather than local
  conditions.

  RAPID publishes only NetCDF at a stable URL, so this one is downloaded as
  bytes and read with `ncdf4` (a `Suggests`) rather than parsed as text. The
  twelve-hourly series is averaged to monthly. The file is cached like the
  Copernicus downloads, since it is over a megabyte and RAPID times out on
  repeated requests, and the time origin is read from the file rather than
  hard-coded — RAPID has re-based it across releases.

* **Cached indices now expire on their provider's publishing cadence**, so a
  living dataset does not quietly stop being current. Each index records how its
  source updates — monthly for the NOAA indices, roughly yearly for `AMOC`, never
  for `LCR`, which was published with a paper and ends at 2014 — and that sets
  how long a cached copy is reused: a week, a month, or forever. Living indices
  re-download on their own; finished ones are not re-fetched pointlessly.

  Staleness is judged from the data rather than the cache, because a fresh
  download of a file the provider stopped updating is still stale. A series
  ending further behind the present than its source's usual lag is reported, with
  the command to force a refresh.

  A failed download with a usable cached copy on disk returns that copy and
  warns, rather than erroring: a provider being briefly unreachable should not
  become an outage here, and the warning is what stops the old copy being
  mistaken for a current one.

  `climate_index_status()` reports what is cached and what is due without
  downloading anything, so it is safe offline. `refresh_climate_index()` forces a
  re-fetch and skips the indices that cannot change.

  The text indices were previously re-downloaded on every call and are now cached
  too, since downloading moved out of the NetCDF reader into a step every format
  shares.

* **A monthly workflow** checks the variable catalog against the live Copernicus
  catalogue and opens an issue when dataset identifiers drift.
