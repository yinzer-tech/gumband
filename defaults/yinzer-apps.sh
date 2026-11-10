#!/bin/bash

# Offer Yinzer Tech's apps as Omarchy web apps, plus the vini CLI.
# Each is opt-in; nothing here runs without a yes.

set -euo pipefail

# name|url — the icon is each app's PWA icon.
APPS=(
  "YinzAI|https://ai.yinzer.tech"
  "Yinz Sports Management|https://sm.yinzer.tech"
  "Yinz Sports Video|https://sv.yinzer.tech"
  "YinzMusic|https://ym.yinzer.tech"
  "Notes|https://notes.yinzer.tech"
)

choices=()
for app in "${APPS[@]}"; do
  choices+=("${app%%|*}")
done

mapfile -t picked < <(gum choose --no-limit --header "Add Yinzer Tech web apps" --selected "$(IFS=,; echo "${choices[*]}")" "${choices[@]}" || true)

for name in "${picked[@]}"; do
  for app in "${APPS[@]}"; do
    if [[ ${app%%|*} == "$name" ]]; then
      url=${app#*|}
      omarchy-webapp-install "$name" "$url" "$url/icon.512.png"
    fi
  done
done

if command -v bun >/dev/null; then
  if gum confirm "Install the vini CLI?"; then
    bun add -g @yinzer-tech/vini
  fi
else
  echo "Skipping vini: it needs Bun (https://bun.sh)."
fi
