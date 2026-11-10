# Gumband

Yinzer Tech's take on [Omarchy](https://omarchy.org). Gumband is a layer that sits on top of a stock Omarchy install instead of a fork. Omarchy keeps updating normally, and Gumband re-applies itself after each update.

![Gumband](themes/gumband/preview.png)

## What it changes

- **Themes:** `gumband` (dark) and `gumband-light`. Each is a `colors.toml` that Omarchy expands into the terminal, Hyprland, Waybar/shell, btop, Neovim, Helix, Chromium, VS Code and Obsidian configs. The palette follows the Catalyst UI kit used in Yinzer Tech's apps: zinc surfaces and a blue-500 focus accent (blue-600 on light). Both also include Yaru-blue icons, three monochrome zinc wallpapers (the Point at night, the three rivers, and the bridge mark), and the gold bridge on the lock screen.
- **Boot and login:** the Plymouth splash and SDDM login screen keep the brand black and gold: the gold bridge on zinc-950, via `omarchy plymouth set`.
- **About and screensaver:** the About screen shows the bridge mark and the screensaver shows a `GUMBAND` wordmark, both in `~/.config/omarchy/branding/`.
- **Optional:** the Yinzer Tech apps (YinzAI, Sports Management, Sports Video, YinzMusic, Notes) as Omarchy web apps, plus the vini CLI.

## Install

Install [Omarchy](https://omarchy.org) first, then:

```bash
curl -fsSL https://raw.githubusercontent.com/yinzer-tech/gumband/main/install.sh | bash
```

or from a checkout:

```bash
git clone https://github.com/yinzer-tech/gumband.git ~/.local/share/gumband
~/.local/share/gumband/install.sh
```

When piped from curl, the installer skips the web app prompt. Run `gumband defaults` afterwards to get it.

## Use

```
gumband theme [light]   switch to the Gumband theme
gumband update          pull the latest Gumband and re-apply
gumband plymouth        re-apply the boot splash (needs sudo)
gumband defaults        add the Yinzer Tech web apps / vini
gumband doctor          check Omarchy still offers what Gumband uses
gumband remove          back to stock Omarchy branding
```

Both themes also appear in Omarchy's own theme picker (`Super + Ctrl + T`), and `Super + Ctrl + W` cycles their wallpapers.

## How it stays out of Omarchy's way

| Gumband part | Omarchy extension point it uses |
|---|---|
| themes | `~/.config/omarchy/themes/<name>`, symlinked to this checkout. Omarchy only strips Lua and terminal configs from themes that carry their own `.git`, so a symlink keeps everything. |
| boot splash | `omarchy-plymouth-set`. It only re-runs when the logo or colors change, because it needs sudo. |
| About / screensaver | `~/.config/omarchy/branding/{about,screensaver}.txt` |
| re-apply after updates | `~/.config/omarchy/hooks/post-update.d/gumband`, which `omarchy update` runs |

## Editing the look

The palettes are in `themes/*/colors.toml`. The wallpapers, unlock image and previews are rendered from the SVG templates in `assets/`, with `{{key}}` tokens filled from each theme's palette:

```bash
script/render-assets   # macOS uses sips, Linux uses rsvg-convert
```

`branding/about.txt` was converted from the bridge mark. `branding/screensaver.txt` is `omarchy ascii GUMBAND`.

`preview.png` is currently the first wallpaper. Replace it with a real desktop screenshot once Gumband is running on hardware.

## Tests

```bash
bats test/                                       # against a stub Omarchy
OMARCHY_FIXTURE=~/src/omarchy bats test/         # against a real upstream checkout
```

CI runs both every week, and also checks that upstream still ships every command and hook Gumband calls.

## Raspberry Pi

Pi images are built in the sibling repo [gumband-pi](https://github.com/yinzer-tech/gumband-pi). They boot into Omarchy with Gumband already applied.

## License

MIT. Omarchy is © its authors and is also MIT. Gumband doesn't contain or modify Omarchy code.
