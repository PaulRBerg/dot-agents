---
name: sablier-icon
argument-hint: <color> [--flat] [--format png|jpg]
description: This skill should be used when the user asks to "recolor the Sablier icon", "Sablier icon in orange", "Sablier logo in primary color", "generate Sablier hourglass variant", "change Sablier icon color", or "export Sablier icon as PNG". Generates a gradient or flat Sablier icon SVG in any color using brand palette names, hex values, or CSS color names, with optional PNG/JPG raster export.
---

Recolor the Sablier icon SVG to a user-specified color with an analogous gradient, and optionally export to PNG or JPG.

## Source

The base icon is at `assets/icon.svg` (relative to this skill directory). It is a two-path SVG with `viewBox="0 0 189.9 236.73"`
(aspect ratio ~0.802:1). Two CSS classes (`.cls-1`, `.cls-2`) reference two `<linearGradient>` elements in `<defs>`:

- `<linearGradient id="linear-gradient">` — contains two `<stop>` elements:
  - `offset="0"` → `stop-color="#f77423"` (top / darker)
  - `offset="1"` → `stop-color="#fbce5b"` (bottom / lighter)
- `<linearGradient id="linear-gradient-2">` — inherits stops from the first via `xlink:href="#linear-gradient"`

To recolor, replace the two `stop-color` values inside `<linearGradient id="linear-gradient">`. Always preserve the original
viewBox and aspect ratio — never add or change `width`/`height` attributes on the SVG.

A flat variant is at `assets/icon-white.svg` — a single-path SVG with `fill="white"` and `viewBox="0 0 386 480"` (aspect
ratio ~0.804:1). Used only when `--flat` is passed.

## Color Resolution

Resolve the user's color input using this priority (first match wins):

1. **Exact alias** — `primary`, `secondary`, `orange`, `blue` (see aliases in palette below)
2. **Exact palette name** — e.g. `primary-start`, `dark-300`, `gray-400`
3. **Raw hex** — accept `#RRGGBB` or `RRGGBB` (6-digit only, reject 3/8-digit). Normalize to lowercase `#rrggbb`
4. **CSS color name** — standard CSS named colors (e.g. `red`, `teal`, `cornflowerblue`)

If multiple palette entries match a prefix (e.g. `dark` matches `dark`, `dark-100`, `dark-300`), prefer the exact match.
If no exact match exists, ask the user to be more specific.

### Sablier Brand Palette

Source: [sablier-labs/branding](https://github.com/sablier-labs/branding)

| Name                  | Hex       | Notes                           |
| --------------------- | --------- | ------------------------------- |
| primary-start         | `#ff7300` | Orange gradient start           |
| primary-end           | `#ffb800` | Orange gradient end             |
| primary / orange      | `#ff9c00` | Median orange (default primary) |
| secondary-start       | `#003dff` | Blue gradient start             |
| secondary-end         | `#00b7ff` | Blue gradient end               |
| secondary / blue      | `#0063ff` | Median blue (default secondary) |
| secondary-desaturated | `#266cd9` | Desaturated blue                |
| dark                  | `#14161f` | Darkest background              |
| dark-100              | `#1e212f` | App background                  |
| dark-300              | `#2a2e41` | Card borders                    |
| dark-400              | `#30354a` | Input borders                   |
| gray-100              | `#e1e4ea` | Body text                       |
| gray-400              | `#8792ab` | Labels                          |
| red                   | `#e52e52` | Error / destructive             |
| white                 | `#ffffff` | Original icon color             |
| black                 | `#000000` | Pure black (rarely used)        |

## Gradient Generation

### Brand gradient pairs

Use these exact hex pairs — no computation needed:

| Alias            | Start (offset=0, top) | End (offset=1, bottom) |
| ---------------- | --------------------- | ---------------------- |
| primary / orange | `#f77423`             | `#fbce5b`              |
| secondary / blue | `#003dff`             | `#00b7ff`              |

When the user says "primary" or "orange", the output is identical to `icon.svg` (no stop-color changes needed).
When the user says "secondary" or "blue", replace the two stop-colors with the blue pair.

### Arbitrary colors — piecewise HSL algorithm

For any color not in the brand gradient pairs above, generate an analogous two-stop gradient:

1. Convert the resolved hex to HSL `(h, s%, l%)`
2. Branch by saturation:
   - **Achromatic** (`s < 10`): keep `s = 0` for both stops, vary only lightness
     - Start: `hsl(h, 0%, max(l - 8, 10)%)`
     - End: `hsl(h, 0%, min(l + 12, 90)%)`
   - **Chromatic** (`s >= 10`): keep hue constant, adjust lightness and gently reduce end saturation
     - Start: `hsl(h, s%, max(l - 8, 15)%)`
     - End: `hsl(h, floor(s * 0.9)%, min(l + 12, 88)%)`
3. Ensure `endL > startL` after clamps; if not, set `startL = endL - 10`
4. Convert both HSL values back to 6-digit lowercase hex

## SVG Generation

### Gradient mode (default)

1. Read `assets/icon.svg`
2. Resolve gradient start/end colors:
   - If the color matches a brand gradient pair alias, use the exact hex pair
   - Otherwise, apply the piecewise HSL algorithm
3. Find the two `<stop>` elements inside `<linearGradient id="linear-gradient">` and replace their `stop-color` values:
   - `offset="0"` → start hex
   - `offset="1"` → end hex
4. Structural checks:
   - Exactly two `stop-color` replacements occurred
   - `xlink:href="#linear-gradient"` on `linear-gradient-2` is still intact
   - `viewBox="0 0 189.9 236.73"` preserved, no `width`/`height` attributes added
5. Write to `sablier-icon-<color-name>.svg`

### Flat mode (`--flat` flag)

1. Read `assets/icon-white.svg`
2. Resolve the color to a single hex value:
   - If the color matches a brand gradient pair alias (`primary`, `secondary`), use the median palette hex (`#ff9c00`, `#0063ff`)
   - Otherwise, use the resolved hex directly
3. Replace `fill="white"` on the `<path>` element only — never touch `fill="none"` on the root `<svg>` element
4. Verify exactly one replacement occurred
5. Verify `viewBox="0 0 386 480"` preserved, no `width`/`height` attributes added
6. Write to `sablier-icon-<color-name>.svg`

### Filenames

Use the brand alias when matched by name (e.g. `primary`), otherwise strip the `#` prefix and lowercase the hex value
(e.g. `#E52E52` → `e52e52`). If the color cannot be resolved, ask the user to provide a valid hex code.

## PNG / JPG Export

If the user passes `--format png` or `--format jpg`:

1. Generate the recolored SVG first
2. Verify `magick` is available: `command -v magick >/dev/null 2>&1 || { echo "Error: ImageMagick not found. Install with: brew install imagemagick"; exit 1; }`
3. Use `magick` to convert:

**Gradient mode** (from `icon.svg`, viewBox 189.9×236.73):

```bash
# PNG (transparent background, 1024px height, auto-compute width from aspect ratio ≈822px)
magick -background none "<input>.svg" -resize x1024 "<output>.png"

# JPG (dark background since JPG has no transparency)
magick -background "#14161f" "<input>.svg" -resize x1024 -flatten "<output>.jpg"
```

**Flat mode** (from `icon-white.svg`, viewBox 386×480):

```bash
# PNG (transparent background, explicit dimensions from 386:480 ratio)
magick -background none "<input>.svg" -resize 824x1024 "<output>.png"

# JPG (dark background)
magick -background "#14161f" "<input>.svg" -resize 824x1024 -flatten "<output>.jpg"
```

Verify the exported file's dimensions match the expected aspect ratio.

The output filename follows the same `sablier-icon-<color-name>.<ext>` pattern.

## Examples

- `primary` → `sablier-icon-primary.svg` with brand orange gradient (identical to `icon.svg`)
- `secondary` → `sablier-icon-secondary.svg` with blue gradient `#003dff` / `#00b7ff`
- `#e52e52` → `sablier-icon-e52e52.svg` with red gradient (piecewise HSL algorithm)
- `white` → `sablier-icon-white.svg` with achromatic subtle lightness gradient
- `#00d395 --flat` → `sablier-icon-00d395.svg` with flat `fill="#00d395"`
- `red --format jpg` → `sablier-icon-red.svg` + `sablier-icon-red.jpg`
- `secondary --format png` → `sablier-icon-secondary.svg` + `sablier-icon-secondary.png` (blue gradient + raster export)
