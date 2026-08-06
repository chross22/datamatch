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

echo
for rscript in "${found[@]}"; do
  r="${rscript%script}"          # /path/to/Rscript -> /path/to/R
  version="$("$rscript" --vanilla -e 'cat(paste0(R.version$major, ".", R.version$minor))' 2>/dev/null)"
  echo "Installing into R $version ..."
  # Output is kept unless the install fails, where it is the only thing that
  # says why.
  if ! out="$("$r" CMD INSTALL "$pkg_root" 2>&1)"; then
    echo "$out" >&2
    echo "FAILED for R $version" >&2
    exit 1
  fi
done

echo
echo "After:"
for rscript in "${found[@]}"; do report "$rscript"; done
