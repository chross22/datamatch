# datamatch 0.0.0.9000

## Bug fixes

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

* **Failed downloads surfaced as an unreadable file.** A run of failures warned
  and returned a status code the caller ignored, so the error appeared later from
  `terra::rast()` on a file that was never written. Failures now raise where they
  happen, carrying the Copernicus client's output.

## Breaking changes

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

* **A monthly workflow** checks the variable catalog against the live Copernicus
  catalogue and opens an issue when dataset identifiers drift.
