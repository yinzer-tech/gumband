#!/bin/bash

# Install Gumband on top of an installed Omarchy.
#
#   curl -fsSL https://raw.githubusercontent.com/yinzer-tech/gumband/main/install.sh | bash
#
# or from a checkout: ./install.sh
#
# GUMBAND_DEFAULTS=0 skips the web app / vini prompt (for unattended installs).

set -euo pipefail

GUMBAND_REPO=${GUMBAND_REPO:-https://github.com/yinzer-tech/gumband.git}
GUMBAND_PATH=${GUMBAND_PATH:-$HOME/.local/share/gumband}

if [[ -z ${OMARCHY_PATH:-} ]] || ! command -v omarchy-theme-set >/dev/null; then
  echo "Gumband needs Omarchy installed first: https://omarchy.org" >&2
  exit 1
fi

# Run from a checkout: use it in place. Piped from curl: clone.
here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [[ -n $here && -x $here/bin/gumband ]]; then
  GUMBAND_PATH=$here
elif [[ -d $GUMBAND_PATH/.git ]]; then
  git -C "$GUMBAND_PATH" pull --ff-only
else
  git clone --depth 1 "$GUMBAND_REPO" "$GUMBAND_PATH"
fi
export GUMBAND_PATH

"$GUMBAND_PATH/bin/gumband" apply
"$GUMBAND_PATH/bin/gumband" theme

if [[ ${GUMBAND_DEFAULTS:-1} == "1" && -t 0 ]]; then
  "$GUMBAND_PATH/bin/gumband" defaults
fi

echo
echo "Gumband is on. Try: gumband theme light | gumband doctor | gumband update"
