#!/usr/bin/env bats

# Runs bin/gumband and install.sh against a fake Omarchy: a fixture
# OMARCHY_PATH and stub commands that log how they were called. CI points
# OMARCHY_FIXTURE at a real upstream checkout to catch drift.

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  export HOME="$BATS_TEST_TMPDIR/home"
  export OMARCHY_PATH="$BATS_TEST_TMPDIR/omarchy"
  export LOG="$BATS_TEST_TMPDIR/calls.log"
  STUBS="$BATS_TEST_TMPDIR/stubs"

  mkdir -p "$HOME" "$STUBS"
  cp -R "${OMARCHY_FIXTURE:-$ROOT/test/fixtures/omarchy}" "$OMARCHY_PATH"
  : >"$LOG"

  for command in omarchy-theme-set omarchy-plymouth-set omarchy-plymouth-reset omarchy-webapp-install; do
    cat >"$STUBS/$command" <<'EOF'
#!/bin/bash
echo "$(basename "$0") $* headless=${OMARCHY_THEME_HEADLESS:-0}" >>"$LOG"
EOF
    chmod +x "$STUBS/$command"
  done

  # Passwordless sudo unless a test takes it away.
  printf '#!/bin/bash\nexit 0\n' >"$STUBS/sudo"
  chmod +x "$STUBS/sudo"

  export PATH="$STUBS:$PATH"
  unset WAYLAND_DISPLAY GUMBAND_PATH
}

gumband() {
  "$ROOT/bin/gumband" "$@"
}

snapshot() {
  (cd "$HOME" && find . -print0 | sort -z | xargs -0 ls -ld | awk '{print $1, $NF}'; find . -type f -print0 | sort -z | xargs -0 cat | sha256sum)
}

@test "apply refuses to run without Omarchy" {
  rm "$STUBS/omarchy-theme-set"
  run gumband apply
  [ "$status" -eq 1 ]
  [[ $output == *"needs Omarchy"* ]]
  [ ! -e "$HOME/.config/omarchy/themes/gumband" ]
}

@test "apply links themes, copies branding, installs the hook and sets the boot splash" {
  run gumband apply
  [ "$status" -eq 0 ]

  [ "$(readlink "$HOME/.config/omarchy/themes/gumband")" == "$ROOT/themes/gumband" ]
  [ "$(readlink "$HOME/.config/omarchy/themes/gumband-light")" == "$ROOT/themes/gumband-light" ]
  cmp "$ROOT/branding/about.txt" "$HOME/.config/omarchy/branding/about.txt"
  cmp "$ROOT/branding/screensaver.txt" "$HOME/.config/omarchy/branding/screensaver.txt"
  [ -x "$HOME/.config/omarchy/hooks/post-update.d/gumband" ]
  grep -q "$ROOT/bin/gumband\" apply --quiet" "$HOME/.config/omarchy/hooks/post-update.d/gumband"
  [ "$(readlink "$HOME/.local/bin/gumband")" == "$ROOT/bin/gumband" ]
  grep -qx "omarchy-plymouth-set #09090b #fbbf24 $ROOT/branding/logo.png headless=0" "$LOG"
}

@test "apply is idempotent and only sets the boot splash once" {
  gumband apply
  before=$(snapshot)
  gumband apply
  [ "$(snapshot)" == "$before" ]
  [ "$(grep -c omarchy-plymouth-set "$LOG")" -eq 1 ]
}

@test "quiet apply without sudo leaves an outdated boot splash alone and says so" {
  printf '#!/bin/bash\nexit 1\n' >"$STUBS/sudo"
  run gumband apply --quiet
  [ "$status" -eq 0 ]
  [[ $output == *"gumband plymouth"* ]]
  ! grep -q omarchy-plymouth-set "$LOG"
}

@test "apply moves a theme directory of the same name aside" {
  mkdir -p "$HOME/.config/omarchy/themes/gumband"
  touch "$HOME/.config/omarchy/themes/gumband/mine"
  gumband apply
  [ -L "$HOME/.config/omarchy/themes/gumband" ]
  ls "$HOME"/.config/omarchy/themes/gumband.bak.*/mine
}

@test "doctor passes after apply" {
  gumband apply
  run gumband doctor
  [ "$status" -eq 0 ]
  [[ $output != *FAIL* ]]
}

@test "doctor fails when Omarchy themes gain a key Gumband lacks" {
  gumband apply
  echo 'new_key = "#000000"' >>"$OMARCHY_PATH/themes/matte-black/colors.toml"
  run gumband doctor
  [ "$status" -eq 1 ]
  [[ $output == *"FAIL  gumband defines new_key"* ]]
  [[ $output == *"FAIL  gumband-light defines new_key"* ]]
}

@test "theme sets dark by default, light on request, headless outside a session" {
  gumband theme
  gumband theme light
  WAYLAND_DISPLAY=wayland-1 gumband theme
  grep -qx "omarchy-theme-set gumband headless=1" "$LOG"
  grep -qx "omarchy-theme-set gumband-light headless=1" "$LOG"
  grep -qx "omarchy-theme-set gumband headless=0" "$LOG"
}

@test "remove restores Omarchy branding and the boot splash" {
  gumband apply
  mkdir -p "$HOME/.local/state/omarchy/current"
  echo gumband >"$HOME/.local/state/omarchy/current/theme.name"

  run gumband remove
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/omarchy/themes/gumband" ]
  [ ! -e "$HOME/.config/omarchy/hooks/post-update.d/gumband" ]
  [ ! -e "$HOME/.local/bin/gumband" ]
  cmp "$OMARCHY_PATH/icon.txt" "$HOME/.config/omarchy/branding/about.txt"
  cmp "$OMARCHY_PATH/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"
  grep -q "omarchy-theme-set tokyo-night" "$LOG"
  grep -q "omarchy-plymouth-reset" "$LOG"
}

@test "install.sh from a checkout applies in place and sets the theme" {
  run bash "$ROOT/install.sh" </dev/null
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/omarchy/themes/gumband")" == "$ROOT/themes/gumband" ]
  grep -q "omarchy-theme-set gumband" "$LOG"
  ! grep -q omarchy-webapp-install "$LOG"
  [ ! -d "$HOME/.local/share/gumband" ]
}

@test "both themes define every stock key with hex colors and ship their images" {
  for theme in gumband gumband-light; do
    dir="$ROOT/themes/$theme"
    while read -r key; do
      grep -qE "^$key = \"#[0-9a-f]{6}\"$|^mode = \"(dark|light)\"$" "$dir/colors.toml" || {
        echo "$theme: $key missing or not hex"
        return 1
      }
    done < <(sed -nE 's/^([a-z_]+) *=.*/\1/p' "$OMARCHY_PATH/themes/matte-black/colors.toml")

    for file in icons.theme unlock.png preview.png preview-unlock.png backgrounds/1-the-point.png; do
      [ -s "$dir/$file" ] || { echo "$theme: missing $file"; return 1; }
    done
  done
}
