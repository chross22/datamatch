#!/usr/bin/env bash
#
# Install datamatch into every R on this machine.
#
# There is more than one R here, and each keeps its own library:
#
#   /opt/homebrew/bin/R   4.6.x   /opt/homebrew/lib/R/4.6/site-library
#   /usr/local/bin/R      4.3.x   ~/Library/R/arm64/4.3/library
#
# `R CMD INSTALL .` installs into whichever one is on PATH and silently leaves
# the other on whatever it had before. That is how a package can be rebuilt,
# tested, and still fail in RStudio or in a dependent project: the R doing the
# failing is not the R that was rebuilt, and the error it raises is from code
# that no longer exists in the source tree.
#
# That is a bad failure to debug, because every obvious check passes. Running
# this instead of `R CMD INSTALL .` makes it impossible.
#
# Usage:
#   inst/scripts/install_all.sh            # install into every R found
#   inst/scripts/install_all.sh --check    # report what each R has, install nothing
#
# Installs only. It never removes an R, a library, or a package.

set -euo pipefail

pkg_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
check_only=false
[[ "${1:-}" == "--check" ]] && check_only=true

# Candidate interpreters, in no particular order. Absent ones are skipped rather
# than reported, since not every machine has both.
candidates=(/opt/homebrew/bin/Rscript /usr/local/bin/Rscript)

found=()
for rscript in "${candidates[@]}"; do
  [[ -x "$rscript" ]] && found+=("$rscript")
done

if [[ ${#found[@]} -eq 0 ]]; then
  echo "No R found at any of: ${candidates[*]}" >&2
  exit 1
fi

report() {
  local rscript="$1"
  "$rscript" --vanilla -e '
    v <- paste0(R.version$major, ".", R.version$minor)
    d <- tryCatch(utils::packageDescription("datamatch"), error = function(e) NULL)
    built <- if (is.null(d) || identical(d, NA)) "not installed" else d$Built
    cat(sprintf("  R %-8s %s\n", v, built))
  ' 2>/dev/null
}

echo "datamatch at $pkg_root"
echo
echo "Before:"
for rscript in "${found[@]}"; do report "$rscript"; done

if $check_only; then
  exit 0
fi

# A tarball is built once and installed into each R, rather than installing the
# source directory. Installing a directory skips vignettes entirely - R CMD
# INSTALL has no option to build them, and --build-vignettes belongs to R CMD
# build - so vignette("datamatch") comes back empty however often the package is
# reinstalled. Building first is the only way the vignette index reaches the
# library.
#
# Vignettes need pandoc. RStudio bundles one, which is often the only copy on a
# Mac, so it is added to PATH when nothing else provides it. Without pandoc the
# build falls back to skipping vignettes rather than failing: an installed
# package without a vignette beats no installed package.
echo
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

rstudio_pandoc="/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools"
if ! command -v pandoc >/dev/null 2>&1 && [[ -x "$rstudio_pandoc/pandoc" ]]; then
  PATH="$rstudio_pandoc:$PATH"
  export PATH
fi

builder="${found[0]%script}"
echo "Building the package ..."
if ! out="$(cd "$build_dir" && "$builder" CMD build "$pkg_root" 2>&1)"; then
  echo "$out" >&2
  echo "Build failed; retrying without vignettes." >&2
  if ! out="$(cd "$build_dir" && "$builder" CMD build --no-build-vignettes "$pkg_root" 2>&1)"; then
    echo "$out" >&2
    echo "FAILED to build" >&2
    exit 1
  fi
  echo "Built without vignettes. Install pandoc for vignette(\"datamatch\")." >&2
fi

tarball="$(ls "$build_dir"/*.tar.gz | head -1)"

for rscript in "${found[@]}"; do
  r="${rscript%script}"          # /path/to/Rscript -> /path/to/R
  version="$("$rscript" --vanilla -e 'cat(paste0(R.version$major, ".", R.version$minor))' 2>/dev/null)"
  echo "Installing into R $version ..."
  # Output is kept unless the install fails, where it is the only thing that
  # says why.
  if ! out="$("$r" CMD INSTALL "$tarball" 2>&1)"; then
    echo "$out" >&2
    echo "FAILED for R $version" >&2
    exit 1
  fi
done

echo
echo "After:"
for rscript in "${found[@]}"; do report "$rscript"; done
