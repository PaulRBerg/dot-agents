---
name: sablier-icon
argument-hint: <color> [--format png|jpg]
description: This skill should be used when the user asks to "recolor the Sablier icon", "Sablier icon in orange", "Sablier logo in primary color", "generate Sablier hourglass variant", "change Sablier icon color", or "export Sablier icon as PNG". Converts the Sablier white SVG icon to any color using brand palette names, hex values, or CSS color names, with optional PNG/JPG raster export.
---

Recolor the Sablier icon SVG to a user-specified color and optionally export to PNG or JPG.

## Source

The base icon is at `assets/white-icon.svg` (relative to this skill directory). It is a single-path SVG with
`fill="white"` and `viewBox="0 0 386 480"` (aspect ratio ~0.804:1). To recolor, replace the `fill` attribute value
with the target hex color. Always preserve the original viewBox and aspect ratio — never add or change `width`/`height`
attributes on the SVG.

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

When the user says "primary", use `#ff9c00`. When they say "secondary", use `#0063ff`.

## SVG Generation

1. Read `assets/white-icon.svg`
2. Replace `fill="white"` on the `<path>` element only — never touch `fill="none"` on the root `<svg>` element
3. Verify exactly one replacement occurred. Zero means the SVG structure changed; more than one means multi-path — both
   require investigation before proceeding
4. Verify the output preserves `viewBox="0 0 386 480"` and contains no `width`/`height` attributes
5. Write the result to the user's working directory as `sablier-icon-<color-name>.svg`

For filenames: use the brand alias when matched by name (e.g. `primary`), otherwise strip the `#` prefix and lowercase
the hex value (e.g. `#E52E52` → `e52e52`). If the color cannot be resolved, ask the user to provide a valid hex code.

## PNG / JPG Export

If the user passes `--format png` or `--format jpg`:

1. Generate the recolored SVG first
2. Verify `magick` is available: `command -v magick >/dev/null 2>&1 || { echo "Error: ImageMagick not found. Install with: brew install imagemagick"; exit 1; }`
3. Use `magick` to convert:

```bash
# PNG (transparent background, 1024px height, preserves aspect ratio)
magick -background none "<input>.svg" -resize 824x1024 "<output>.png"

# JPG (dark background since JPG has no transparency, preserves aspect ratio)
magick -background "#14161f" "<input>.svg" -resize 824x1024 -flatten "<output>.jpg"
```

Prefer explicit pixel dimensions derived from the 386:480 viewBox ratio (e.g. 824x1024, 412x512) for predictable
output. Verify the exported file's dimensions match the expected aspect ratio.

The output filename follows the same `sablier-icon-<color-name>.<ext>` pattern.

## Examples

- `primary` → `sablier-icon-primary.svg` with `fill="#ff9c00"`
- `secondary --format png` → `sablier-icon-secondary.svg` + `sablier-icon-secondary.png`
- `#e52e52` → `sablier-icon-e52e52.svg` with `fill="#e52e52"`
- `red --format jpg` → `sablier-icon-red.svg` + `sablier-icon-red.jpg`
