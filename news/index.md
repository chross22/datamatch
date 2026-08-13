# Changelog

## datamatch 0.2.0

### New features

- **MUR and VIIRS, through
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md).**
  Satellite SST and chlorophyll from NOAA’s ERDDAP servers: `MUR`
  (0.01°, daily, 2002-06 onward) for SST, and `VIIRSCHL` /
  `VIIRSCHL2018` for chlorophyll. MUR is by a wide margin the finest
  field the package can reach — about 1 km, against 9 km for the physics
  reanalysis.

  **No account is needed.** The same products at PO.DAAC require an
  Earthdata login; ERDDAP serves them openly and subsets server-side, so
  there are no credentials for this package to handle or for the user to
  configure. That is why this route was chosen.

  Three things the documentation is explicit about. A satellite SST is
  the *foundation* temperature, below the daily warming layer, where a
  model `SST` is its topmost level — they differ by a degree or more on
  a calm sunny day, and both arrive in a column called `SST`. MUR is
  gap-free by construction because it is an analysis, so `SST_ERROR` is
  where the interpolation shows up. And there is **no global VIIRS
  SST**: the VIIRS SST on these servers covers the US West Coast only,
  so MUR — a blend taking VIIRS among its inputs — is the SST to use
  instead.

  As with FVCOM, the backend is general rather than a fixed list:
  `erddap_dataset(server, dataset_id)` describes any of the thousands of
  other griddap datasets for
  [`accessERDDAP()`](https://chross22.github.io/datamatch/reference/accessERDDAP.md).

- **HYCOM now reaches 2024, and FVCOM 2025.** Both had stopped short —
  HYCOM at 2015 and FVCOM at 2013 — because each shipped a single
  archive. Neither was a limit of the data.

  [`hycom_archives()`](https://chross22.github.io/datamatch/reference/hycom_archives.md)
  now carries the 1994–2015 reanalysis plus the seven operational
  experiments that follow it, to September 2024, and
  `hycom_covering(date)` says which span a given day. They overlap, so
  where two cover a date the choice between them is a judgement — the
  reanalysis is more internally consistent, the operational run more
  recent — and nothing picks for you. One archive is read per call, and
  a request falling outside the one named is told which others hold it
  rather than being stitched to them silently.

  The seam that matters is the run, not the grid: `GLBv0.08` and
  `GLBy0.08` hold the same 126 latitudes between 40 and 45 °N
  identically, so on a mid-latitude shelf the cells line up across it.
  `GLBy0.08` stores longitude 0–360 where `GLBv0.08` stores −180…180;
  the convention is read off the coordinates rather than recorded, so a
  box given negative west works against either.

  [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)
  gains `GOM7`, the archived operational forecast: hourly on a
  207,081-node mesh from 2025. It is deliberately **not** presented as a
  continuation of the `GOM3` hindcast — the mesh, the step and whether
  the output is retrospective all change at once, and `GOM7` saves no
  wind stress. Between 2014 and 2024 NECOFS publishes neither, which is
  a gap in the source.

  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md)
  gains `frequency` and `hour` for sub-daily archives, defaulting to one
  snapshot a day because a month of hourly `GOM7` is 720 reads of a
  207,081-node field. A snapshot is an instant, not a daily mean;
  [`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
  makes a real one.

- **CCMP winds, through
  [`accessCCMP()`](https://chross22.github.io/datamatch/reference/accessCCMP.md).**
  The Cross-Calibrated Multi-Platform ocean surface wind analysis from
  Remote Sensing Systems: `WSPD`, `UWND`, `VWND` and `NOBS`, six-hourly
  from January 1993 to within days of the present. No account is needed
  — the registration RSS asks for covers their FTP service, and the
  HTTPS archive is open.

  It is the longest and finest-in-time wind record the package can
  reach. The Copernicus L4 wind is monthly from mid-1994 or hourly only
  from 2007, with nothing daily between; CCMP is six-hourly throughout.

  Two costs. **It carries no wind stress**, which the Copernicus product
  does, and stress cannot be recovered from these winds without choosing
  a drag coefficient — so where stress is the covariate, use Copernicus.
  And **there is no server-side subsetting**: RSS publishes static
  files, so a day is one 33 MB global file however small the bounding
  box, and a year is roughly 12 GB of transfer. Subsets are cached, and
  a request for more than 30 days says what it is about to download
  first.

  CCMP is stored on a **0–360 longitude grid**, alone among the sources
  here. `bounding_box` is given negative west as everywhere else,
  converted on the way in, and the returned coordinates are negative
  west too — so a CCMP result overlays the others without adjustment.

- **HYCOM, through
  [`accessHYCOM()`](https://chross22.github.io/datamatch/reference/accessHYCOM.md).**
  Reads the HYCOM + NCODA GOFS 3.1 reanalysis (`GLBv0.08` `expt_53.X`,
  1994–2015) from the Naval Research Laboratory’s THREDDS server, in the
  same `sf` shape as everything else.

  It is worth having for two things GLORYS cannot give. HYCOM publishes
  `salinity_bottom` and `water_temp_bottom` as **fields**, so `BOTS` is
  an ordinary request rather than a derivation from the full depth
  column. And it is an **independent model**, so agreement with
  Copernicus is evidence in a way either alone is not.

  HYCOM publishes instantaneous fields every three hours and no mean at
  all, so none is invented: `frequency = "daily"` takes one **snapshot**
  per day at `hour`, and `frequency = "3hourly"` returns every step with
  an `HOUR` column. A real mean is
  [`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)’s
  job. The archive also has gaps — some steps are simply absent — so a
  daily request at a missing hour skips that day and says so.

- **Any FVCOM endpoint, through
  [`fvcom_archive()`](https://chross22.github.io/datamatch/reference/fvcom_archive.md).**
  FVCOM is a model rather than a data product, so there is no global
  archive of it: groups run it for their own coastlines and publish on
  their own servers, and
  [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)
  ships only what one server publishes for the Northeast US.

  `fvcom_archive(url)` describes any other FVCOM endpoint — opening it
  once to read the mesh size, period, and which fields that run actually
  saved — and the result is passed to `accessFVCOM(archive = )`. This
  works because the reader depends on FVCOM’s structure rather than on
  the region. A URL that is wrong, blocked, or not FVCOM fails there
  with the reason instead of part-way through a fetch.

- **FVCOM, through
  [`accessFVCOM()`](https://chross22.github.io/datamatch/reference/accessFVCOM.md).**
  Reads NECOFS — the Northeast Coastal Ocean Forecast System — from the
  UMass Dartmouth THREDDS server over OPeNDAP, and returns the same `sf`
  shape
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  does, so
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  and everything downstream work unchanged.
  [`fvcom_variables()`](https://chross22.github.io/datamatch/reference/fvcom_variables.md)
  and
  [`fvcom_archives()`](https://chross22.github.io/datamatch/reference/fvcom_archives.md)
  say what can be read; currently the 30-year GOM3 hindcast, 1978–2013,
  monthly means.

  Variables reuse the Copernicus names for the same quantities, so a
  covariate lands in a column of the same name from either source.
  **They are not interchangeable for that reason** — one is a regional
  model on a triangular mesh, the other a global reanalysis. Which was
  used is worth recording.

  Two things behave unlike the Copernicus path, both because FVCOM is an
  unstructured mesh:

  - **Scalars are on mesh nodes and velocities on element centroids**,
    which are two different sets of points (48,451 and 90,415 on GOM3).
    Fetching both in one call is an error rather than a silent
    interpolation of one onto the other, in the same spirit as refusing
    to mix two Copernicus grids.
  - **`BOTS` costs nothing.** FVCOM’s sigma coordinate makes the deepest
    layer the sea floor at every node, so bottom salinity is a layer
    index rather than the derivation it needs against GLORYS. A sigma
    layer is not a depth, though: the deepest sits at 98.9% of the local
    column.

  Only the monthly means are offered. The hourly hindcast carries
  342,348 time steps, and `nc_open()` reads the whole time coordinate
  before returning, so the request exceeds the server’s DAP timeout —
  the failure takes over ten minutes to arrive and says only
  `NetCDF: DAP failure`. Sub-monthly FVCOM would mean reading the
  per-file datasets behind the aggregation, a month at a time. Reading
  FVCOM needs `ncdf4`, a `Suggests`, and a route to a plain-HTTP service
  on port 8080.

- **Surface wind and stress.** Six new variables from the Copernicus L4
  wind product — `WSPD` (speed), `UWND`/`VWND` (components),
  `TAUX`/`TAUY` (stress components) and `TAU` (stress magnitude). Wind
  is its own product on its own 0.25° grid, running from June 1994, so
  it is a separate
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  call from `SST` as usual.

  Stress rather than speed is what sets mixing and Ekman pumping, and
  the two are not interchangeable: stress is roughly quadratic in speed.
  Note also that the monthly `WSPD` is averaged as a *speed*, so it
  exceeds the magnitude of the mean vector wherever direction varied
  within the month.

- **`frequency = "hourly"`.** Copernicus publishes its L4 wind hourly or
  monthly and nothing between, so there is no daily wind to fetch.
  Hourly is the way to a sub-monthly wind field, and
  `upscale_time(to = "day")` aggregates it — which keeps the choice of
  summary, mean or maximum, with the caller.

  Hourly results carry an `HOUR` column, and
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  joins on it, so observations matched against hourly data need an hour
  of their own, on UTC. A day is one download at either step, so hourly
  costs no extra requests — it costs 24 times the rows.

  `frequency = "daily"` is refused for the wind variables, and
  `"hourly"` for everything else, both before anything is downloaded.
  `WSPD` and `TAU` are magnitudes the hourly product does not carry, so
  they are monthly only.

- **`upscale_time(to = "day")`.** The time axis now goes hour → day →
  month → year rather than starting at day.

- **Bottom salinity, as `BOTS`.** GLORYS12V1 publishes potential
  temperature at the sea floor but no salinity counterpart, so in
  reanalysis mode this is *derived*: the full salinity column is fetched
  and the deepest wet level in each cell kept. The depth that value came
  from is returned as `BOTS_depth` rather than left to be assumed — the
  deepest wet model level is not the sea floor, and in deep water can
  sit well above it.

  Because it needs the whole depth column, `BOTS` must be fetched on its
  own; mixing it with a surface variable is an error rather than a quiet
  second download. It is also much more expensive than a surface
  variable, downloading roughly fifty levels to keep one, and
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  says so when it starts.

  In forecast mode none of this applies. The analysis-and-forecast
  product publishes `sob` outright, so `BOTS` is an ordinary variable
  there, fetches alongside `BOTT`, and returns no `BOTS_depth`. The two
  are the same quantity but not the same number, so a record spanning
  both modes has a seam in it.

- `variable_dictionary("wind")` filters the catalog to the wind
  variables, and `variable_dataset(frequency = "hourly")` reports which
  have an hourly dataset.

### Documentation

- **The README is orientation now, and the depth is in vignettes.** It
  had grown to 11,600 words — a forty-five minute read — because every
  capability added a section to it. It is now 9,000, and what left went
  into two new articles rather than being deleted:

  - **Working with what comes back** — resampling between grids and time
    steps, filling satellite gaps, the four plots, and what `n_workers`
    actually buys.
  - **Static and basin-scale covariates** — seafloor terrain and the
    climate indices, including what TPI measures and why the indices are
    not interchangeable.

  The deeper parts of “Satellite or model?”, “Bottom salinity” and
  “Downloads run in parallel” moved into the existing articles, each
  leaving a short summary and a link behind. Four articles now: getting
  started, choosing a source, working with the result, and the other
  covariates.

- **A function reference table.** Every export, grouped by what it is
  for, in one place in the README. That is what the depth moving out
  required: the README says what each function is and where to read
  more, rather than explaining every one at length.

- The contents list was rebuilt to match, and every internal link
  checked — two pointed at sections that had moved to a vignette.

### Bug fixes

- **[`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md)
  and
  [`downscale_time()`](https://chross22.github.io/datamatch/reference/downscale_time.md)
  did not record the step they produced.** The result’s resolution was
  left to be inferred from its own time stamps, which fails when there
  are too few periods to tell: one day of hourly data aggregated to
  daily is a single day in a single month, indistinguishable by
  inspection from monthly data.
  [`detect_temporal_resolution()`](https://chross22.github.io/datamatch/reference/detect_temporal_resolution.md)
  fell back to monthly, and
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  would then join by month and quietly ignore the day. Both now record
  the target step, which they know exactly.

- **A `yearday` column could be matched on as though it were the year.**
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  finds a table’s time columns by prefix, and `yearday` begins with
  `year`. With no plain `year` column beside it to win the tiebreak, it
  was renamed to `YEAR` without complaint, and every row went into a
  period no `source` covers — so the join came back all `NA` behind a
  warning about uncovered periods, which reads like a gap in the data
  rather than a mistake.

  Day-of-year names — `yearday`, `dayofyear`, `jday`, `doy` and the
  usual variants — are now never matched on, for any time column. A
  table carrying one and no real year or day column gets the
  missing-column error instead.

- **The missing-column error now names the columns it passed over.** The
  lookup stays a prefix match, so `obs_month` and `survey_year` are
  still not recognised. Rather than only saying what it looked for, the
  error lists the similar names that are present and asks for the
  intended one to be renamed. Suggesting is not selecting: widening the
  rule to a contains match would have swept up `jday` and `yearday`
  alongside `obs_month`, trading a clear error for a wrong answer.

  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)’s
  own documentation had claimed `obs_month` would be recognised, which
  was never true. It now describes the prefix rule the code implements.

## datamatch 0.1.0

### Bug fixes

- **Variables could be silently mislabelled in multi-variable
  downloads.** This can affect results already in hand, so it is worth
  checking rather than just reading.

  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  named result columns positionally from `vars`. Copernicus returns
  layers in the NetCDF’s own order, which is alphabetical by variable
  code, so the two agreed only by coincidence. Requesting
  `c("SST", "SSS")` sends `c("thetao", "so")` and gets back `so` first,
  so the columns were labelled the wrong way round:

      # before the fix, Gulf of Maine, January 2010
      SST = 32.69     # 32.69 PSU of salinity, in the temperature column
      SSS = 6.18      # 6.18 C of temperature, in the salinity column

  There was no warning. Any download of two or more variables whose
  requested order differed from the alphabetical order of their
  Copernicus codes was affected. Single-variable downloads never were,
  and neither were requests that happened to be in alphabetical code
  order.

  *Checking existing results:* look for a column whose values sit in the
  wrong range for its name, such as salinity near 32 in an `SST` column.
  Re-running the fetch fixes it. The cached NetCDF files were always
  correct; only the naming was wrong.

  *The fix:*
  [`order_layers()`](https://chross22.github.io/datamatch/reference/order_layers.md)
  strips the depth suffix that 3D variables carry
  (`thetao_depth=0.494025`) and selects layers by matching the variable
  code, so naming cannot drift from content.

- **`Expected N variable column(s)` blamed the depth range for every
  cause.** The check that caught the problem above could only count
  columns, so it guessed:

      Error: Expected 4 variable column(s) but the download returned 2. This usually
      means the depth range spans several model levels...

  For a request whose real problem was two variables the dataset never
  returned, that pointed in the wrong direction. The two causes are now
  distinguished: a variable the download omitted is named along with
  what did arrive, and a code appearing on several layers is reported as
  the depth-range problem it is, with the levels it returned.

- **Daily datasets whose identifier ends in `P1D` fetched one day per
  month.**
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  decided whether a dataset was daily by reading a single character
  three from the end of `dataset_id`. That is `D` in `..._P1D-m`, which
  the model products use, but `P` in `..._P1D`, which the satellite
  ocean colour products use — so an explicitly passed ocean colour daily
  dataset was treated as monthly and only day 1 of each month was
  downloaded. The frequency token is now matched as such.

- **matchData() returned rows grouped by period, not in the order they
  went in.** Rows are processed a period at a time, so a table whose
  periods were interleaved came back reordered. Anyone aligning the
  result against the input by position -
  [`cbind()`](https://rdrr.io/r/base/cbind.html), or assigning a column
  straight across - would have got silently mismatched rows. The order
  is now restored before returning.

- **Sparse daily data could be matched as though it were monthly.**
  [`detect_temporal_resolution()`](https://chross22.github.io/datamatch/reference/detect_temporal_resolution.md)
  infers daily data from more than one day within a month, so a set of
  survey dates — one per month — was indistinguishable from monthly data
  by inspection, and
  [`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)
  would join by month and ignore the day.

  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  knows which dataset it fetched, so it now records the step on the
  result and
  [`detect_temporal_resolution()`](https://chross22.github.io/datamatch/reference/detect_temporal_resolution.md)
  trusts that over the heuristics. Passing `temporal_resolution`
  explicitly still overrides both.

- **Failed downloads surfaced as an unreadable file.** A run of failures
  warned and returned a status code the caller ignored, so the error
  appeared later from
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  on a file that was never written. Failures now raise where they
  happen, carrying the Copernicus client’s output.

### Breaking changes

- **[`matchData()`](https://chross22.github.io/datamatch/reference/matchData.md)’s
  arguments are now `dat` and `source`**, replacing `speciesDat` and
  `envDat`.

  The function was never specific to species observations or
  environmental data. It is a spatiotemporal nearest-feature join
  between two `sf` point objects, and works as well for tag positions
  against a model field, moorings against satellite retrievals, or one
  gridded product against another. The old names described one use of it
  as though it were the only one.

  **The old names still work**, with a warning, so existing scripts and
  `taupatch` keep running. They will be removed in a later version.

  ``` r

  matchData(observations, env)                 # positional, unchanged
  matchData(dat = observations, source = env)  # new names
  matchData(speciesDat = obs, envDat = env)    # still works, warns
  ```

  One related change: a `source` column whose name collides with one
  already in `dat` is now suffixed **`.matched`** rather than `.env`,
  for the same reason.

- **The `BigelowLab/copernicus` dependency is gone.** It was used in two
  places, both in
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md),
  and both are now internal. This removes the `Remotes:` field and the
  hand-created `~/.copernicusdata` file that a new machine previously
  needed.

  **The download cache has moved** to
  `tools::R_user_dir("datamatch", "cache")`. Files downloaded under the
  old scheme are not found there and would be re-downloaded. To keep
  using them:

  ``` r

  options(datamatch.cache = readLines("~/.copernicusdata"))   # in .Rprofile
  ```

  `getOption("datamatch.cache")` and the `DATAMATCH_CACHE` environment
  variable both override the default. The Copernicus client is located
  via `getOption("datamatch.copernicusmarine")` or the `PATH`, and a
  missing client now says so with install instructions.

### New features

- **Daily data.** `accessEnvDat(frequency = "daily")` fetches the daily
  datasets rather than the monthly means, expanding each requested month
  into its days.

  Daily is not simply the monthly identifier at a finer step, and the
  catalog records what Copernicus actually publishes. `PH`, `PP`,
  `DIATO` and `DINO` are monthly composites only, and requesting them
  daily is refused before anything is downloaded. Daily `CHL` comes from
  the gap-free interpolated ocean colour dataset, whose cloud gaps
  Copernicus has already filled — so
  [`fill_satellite_gaps()`](https://chross22.github.io/datamatch/reference/fill_satellite_gaps.md)
  has nothing to do on it, and
  [`accessEnvDat()`](https://chross22.github.io/datamatch/reference/accessEnvDat.md)
  says so when it makes the substitution.

  [`variable_dataset()`](https://chross22.github.io/datamatch/reference/variable_dataset.md)
  takes `frequency` too, and returns `NA` where no daily dataset exists.

  `dates` names the exact dates to fetch, which is the argument to use
  when matching daily data to observations:

  ``` r

  accessEnvDat(vars = "SST", dates = unique(observations$date), bounding_box = bb)
  ```

  Survey dates differ from month to month, and a day-of-month rule does
  not describe them. `YYYYMMDD` strings, `YYYY-MM-DD` strings, and
  `Date` objects are all accepted. Dates are sorted and deduplicated,
  and a date the calendar does not have is an error naming it rather
  than a silently dropped request.

  `dates` replaces `years` and `months`, which must not be given
  alongside it, and implies `frequency = "daily"`. Passing it with an
  explicit `frequency = "monthly"` is a contradiction and an error.

  Since it fetches only the dates named, it is also how a long record is
  sampled rather than fetched whole.

  **Monthly remains the default.** A call naming neither `frequency` nor
  `days` fetches monthly means exactly as before.

- **Downloads run in parallel.** Only the days not already cached are
  fetched, and they go out `n_workers` at a time (default 4). A month of
  daily SST and SSS takes about 40 seconds rather than about 160.

  A failed day no longer abandons the rest: every day is attempted,
  successful ones stay in the cache, and the error names each day that
  failed, so re-running the same call retries only those. Reading and
  converting the files stays in the calling session — those are local
  reads, and returning each day’s data frame from a worker would cost
  more than the read saves.

- **Resampling.**
  [`upscale_grid()`](https://chross22.github.io/datamatch/reference/upscale_grid.md),
  [`downscale_grid()`](https://chross22.github.io/datamatch/reference/downscale_grid.md),
  [`upscale_time()`](https://chross22.github.io/datamatch/reference/upscale_time.md),
  and
  [`downscale_time()`](https://chross22.github.io/datamatch/reference/downscale_time.md)
  move data between grids and time steps, each with a choice of method.
  Targets may be a resolution or another object’s grid. Aggregation
  guards partial coverage with `min_coverage`; interpolation defaults to
  the methods that do not invent structure.

- **Plotting.**
  [`plot_env()`](https://chross22.github.io/datamatch/reference/plot_env.md),
  [`plot_coverage()`](https://chross22.github.io/datamatch/reference/plot_coverage.md),
  [`plot_series()`](https://chross22.github.io/datamatch/reference/plot_series.md),
  and
  [`plot_matched()`](https://chross22.github.io/datamatch/reference/plot_matched.md),
  in base graphics, each returning the data it drew.

- **`TPI`** joins the bathymetry covariates. A cell’s depth relative to
  its neighbours, which separates banks from basins where plain depth
  cannot.

- **`LCR`**, the Labrador Current retroflection index, joins the climate
  index catalog. Published with Jutras et al. (2023) and cited in
  [`index_dictionary()`](https://chross22.github.io/datamatch/reference/index_dictionary.md).

- **Every climate index now declares its `units`**, surfaced in
  [`index_dictionary()`](https://chross22.github.io/datamatch/reference/index_dictionary.md).
  Most are standardized anomalies, in standard deviations rather than
  anything physical; only `AMO` (degrees C) and `AMOC` (Sverdrups) carry
  real units. A coefficient fitted to one of those is not comparable
  with one fitted to `NAO`, and a table of model output gave no way to
  tell.

- **`AMOC`**, the overturning transport measured by the RAPID array at
  26.5°N, joins it too. Unlike the other indices this is a direct
  measurement rather than a pressure or SST pattern — which is also its
  limitation: it begins in April 2004 and is recorded far south of the
  shelf, so it describes the basin-scale circulation the Labrador and
  slope currents sit within rather than local conditions.

  RAPID publishes only NetCDF at a stable URL, so this one is downloaded
  as bytes and read with `ncdf4` (a `Suggests`) rather than parsed as
  text. The twelve-hourly series is averaged to monthly. The file is
  cached like the Copernicus downloads, since it is over a megabyte and
  RAPID times out on repeated requests, and the time origin is read from
  the file rather than hard-coded — RAPID has re-based it across
  releases.

- **Cached indices now expire on their provider’s publishing cadence**,
  so a living dataset does not quietly stop being current. Each index
  records how its source updates — monthly for the NOAA indices, roughly
  yearly for `AMOC`, never for `LCR`, which was published with a paper
  and ends at 2014 — and that sets how long a cached copy is reused: a
  week, a month, or forever. Living indices re-download on their own;
  finished ones are not re-fetched pointlessly.

  Staleness is judged from the data rather than the cache, because a
  fresh download of a file the provider stopped updating is still stale.
  A series ending further behind the present than its source’s usual lag
  is reported, with the command to force a refresh.

  A failed download with a usable cached copy on disk returns that copy
  and warns, rather than erroring: a provider being briefly unreachable
  should not become an outage here, and the warning is what stops the
  old copy being mistaken for a current one.

  [`climate_index_status()`](https://chross22.github.io/datamatch/reference/climate_index_status.md)
  reports what is cached and what is due without downloading anything,
  so it is safe offline.
  [`refresh_climate_index()`](https://chross22.github.io/datamatch/reference/refresh_climate_index.md)
  forces a re-fetch and skips the indices that cannot change.

  The text indices were previously re-downloaded on every call and are
  now cached too, since downloading moved out of the NetCDF reader into
  a step every format shares.

- **A monthly workflow** checks the variable catalog against the live
  Copernicus catalogue and opens an issue when dataset identifiers
  drift.
