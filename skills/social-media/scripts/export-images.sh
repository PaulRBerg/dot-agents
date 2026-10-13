#!/bin/bash
set -euo pipefail

presets() {
  cat <<'PRESETS'
og 1200x630
linkedin 1200x627
x-card 1200x600
square 1080x1080
portrait 1080x1350
instagram 1080x1440
story 1080x1920
pinterest 1000x1500
youtube 3840x2160
PRESETS
}

usage() {
  cat <<'USAGE'
Usage: export-images.sh SOURCE NEW_OUTPUT_DIR [PRESET ...] [OPTIONS]
       export-images.sh --list

Exports all presets when none are named. Custom WIDTHxHEIGHT is also accepted.
The output directory must not exist. The source is never changed.

Options:
  --fit pad|crop       Preserve the whole image (default: pad), or crop to fill
  --gravity POSITION  Center (default), North, SouthEast, etc.
  --background COLOR  Padding and JPEG matte color (default: #111111)
  --format jpg|png    Default: jpg; PNG can preserve transparency
  --quality 1..100    JPEG quality (default: 90); ignored for PNG
  --list              List preset names and dimensions
  --help              Show this help

Use --format png --background none for transparent padding.
USAGE
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --list) presets; exit 0 ;;
esac
[[ $# -ge 2 ]] || { usage >&2; exit 1; }
source_image=$1
output_dir=$2
shift 2
fit=pad
gravity=Center
background='#111111'
format=jpg
quality=90
selected=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fit|--gravity|--background|--format|--quality)
      [[ $# -ge 2 ]] || fail "Missing value for $1"
      case "$1" in
        --fit) fit=$2 ;;
        --gravity) gravity=$2 ;;
        --background) background=$2 ;;
        --format) format=$2 ;;
        --quality) quality=$2 ;;
      esac
      shift 2 ;;
    -*) fail "Unknown option: $1" ;;
    *) selected+=("$1"); shift ;;
  esac
done

case "$fit" in pad|crop) ;; *) fail 'Fit must be pad or crop' ;; esac
case "$format" in jpg|png) ;; *) fail 'Format must be jpg or png' ;; esac
case "$gravity" in
  Center|North|NorthEast|East|SouthEast|South|SouthWest|West|NorthWest) ;;
  *) fail 'Use an ImageMagick compass gravity, such as Center or SouthEast' ;;
esac
[[ "$quality" =~ ^([1-9][0-9]?|100)$ ]] || fail 'Quality must be 1..100'
[[ -f "$source_image" ]] || fail "Source file not found: $source_image"
[[ ! -e "$output_dir" && ! -L "$output_dir" ]] || fail 'Use a new output directory for each iteration'
command -v magick >/dev/null || fail 'ImageMagick 7 is required: brew install imagemagick'

if [[ ${#selected[@]} -eq 0 ]]; then
  while read -r preset dimensions; do selected+=("$preset"); done < <(presets)
fi
sizes=()
for preset in "${selected[@]}"; do
  dimensions=$(presets | awk -v name="$preset" '$1 == name {print $2}')
  if [[ -z "$dimensions" ]]; then
    [[ "$preset" =~ ^[1-9][0-9]{0,3}x[1-9][0-9]{0,3}$ ]] || fail "Unknown preset: $preset (see --list)"
    dimensions=$preset
    [[ ${dimensions%x*} -le 8192 && ${dimensions#*x} -le 8192 ]] || fail 'Custom dimensions must be at most 8192 per edge'
  fi
  sizes+=("$dimensions")
done

# Absolute paths prevent leading dashes and coder-like relative names being options.
[[ "$source_image" = /* ]] || source_image="$PWD/$source_image"
[[ "$output_dir" = /* ]] || output_dir="$PWD/$output_dir"
source_format=$(magick identify -ping -format '%m' "${source_image}[0]")
case "$source_format" in
  PNG|JPEG|WEBP|AVIF|HEIC|GIF|TIFF) ;;
  *) fail "Use a raster source (PNG, JPEG, WebP, AVIF, HEIC, GIF, or TIFF), got: $source_format" ;;
esac
mkdir -p "$(dirname "$output_dir")"
mkdir "$output_dir"

for ((i=0; i<${#selected[@]}; i++)); do
  dimensions=${sizes[$i]}
  resize=$dimensions
  [[ "$fit" != crop ]] || resize="${dimensions}^"
  destination="$output_dir/${selected[$i]}.$format"
  magick_args=("${source_image}[0]" -auto-orient -colorspace sRGB -filter Lanczos
    -resize "$resize" -background "$background" -gravity "$gravity" -extent "$dimensions" +repage)
  if [[ "$format" = jpg ]]; then
    magick_args+=(-alpha remove -alpha off -sampling-factor 4:4:4 -quality "$quality")
  fi
  magick "${magick_args[@]}" -strip "$destination"
  magick identify -format '%f %wx%h %b\n' "$destination"
done
