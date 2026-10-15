# Social Image Exports

Use ImageMagick 7 to derive platform variants from one saved master. Original artwork can come from `$imagegen`.
Cropping, padding, resizing, compression, text overlays, and logo placement are deterministic operations. Do not
regenerate the artwork for those iterations. Use image generation again only when the visual content needs a generative
change.

## Setup and Invocation

Check `magick -version`. On macOS, install a missing engine with `brew install imagemagick`.
[Homebrew supplies ImageMagick 7](https://formulae.brew.sh/formula/imagemagick). Reuse a working installation.

Resolve `scripts/export-images.sh` relative to this skill. The standard global installation supports these commands:

```bash
# All nine presets, with padding that keeps the complete composition.
bash ~/.agents/skills/social-media/scripts/export-images.sh master.png ./social-v1

# Only website/link cards, using the artwork's background color.
bash ~/.agents/skills/social-media/scripts/export-images.sh master.png ./cards-v1 \
  og linkedin x-card --background '#101828'

# Crop with the subject toward the right. Inspect text and logos afterward.
bash ~/.agents/skills/social-media/scripts/export-images.sh master.png ./portrait-v2 \
  portrait instagram --fit crop --gravity East

# Custom resolution and transparent padding.
bash ~/.agents/skills/social-media/scripts/export-images.sh master.png ./custom-v1 \
  1600x900 --format png --background none
```

Run `--list` for presets and `--help` for options. The output directory must be new. Use a new version directory for
each iteration. Existing files and the master remain unchanged. A failed export can leave partial results in its new
directory.

The helper accepts raster sources and exports their first frame. It applies EXIF orientation, converts to sRGB, and
removes metadata. JPEG defaults to quality 90 and a `#111111` matte. PNG preserves alpha when the background is `none`.
JPEG is opaque. The quality option applies only to JPEG. Custom sizes allow 1–8192 pixels per edge.

## Presets and Platform Mapping

These are export starting points, not a promise that every platform displays every pixel. Choose the target placement
before choosing a size. OpenGraph cards belong to linked web pages. Feed images and story covers are separate uploads.

| Preset      | Pixels      | Placement                                                                                                     |
| ----------- | ----------- | ------------------------------------------------------------------------------------------------------------- |
| `og`        | 1200 × 630  | Shared website preview baseline for Facebook, LinkedIn, Farcaster, Bluesky, Mastodon, and chat apps           |
| `linkedin`  | 1200 × 627  | LinkedIn link/Page preview when a separate upload is available                                                |
| `x-card`    | 1200 × 600  | 2:1 starting point for X large cards or landscape uploads                                                     |
| `square`    | 1080 × 1080 | Square feed attachment for Instagram, Threads, Facebook, LinkedIn, X, Farcaster, Bluesky, Mastodon, or Reddit |
| `portrait`  | 1080 × 1350 | 4:5 feed attachment, especially Instagram, Facebook, or LinkedIn                                              |
| `instagram` | 1080 × 1440 | 3:4 portrait candidate for Instagram's native composer                                                        |
| `story`     | 1080 × 1920 | 9:16 artwork for Stories, Reels, TikTok, Snapchat, or Shorts placements                                       |
| `pinterest` | 1000 × 1500 | 2:3 static Pin                                                                                                |
| `youtube`   | 3840 × 2160 | 16:9 YouTube video thumbnail                                                                                  |

For Discord, Slack, WhatsApp, Telegram, and other link unfurlers, start with `og` and inspect the actual preview. Their
display and crop depend on the client and placement. A square export is also available when the target needs one. Export
support does not expand the skill's publishing permissions. Reddit submissions remain manual.

### Evidence and Freshness

Reviewed on 2026-10-13. Refresh the relevant official source when a placement changes or rejects an export.

- [Open Graph](https://ogp.me/) defines image URLs, dimensions, and alt text. It does not mandate one image resolution.
- [LinkedIn](https://www.linkedin.com/help/linkedin/answer/a566445) specifies 1200 × 627 for a Page link-preview image.
- [X's photo help](https://help.x.com/en/using-x/posting-gifs-and-pictures) documents single-photo ratios from 2:1 to
  3:4. This is upload guidance, not proof of large-card behavior. The legacy card documentation redirected to the API
  overview during this review. Treat `x-card` as a practical preset and verify its rendered card.
- [Pinterest](https://help.pinterest.com/en/business/article/pinterest-product-specs) recommends 2:3, or 1000 × 1500,
  for standard image ads.
- [YouTube](https://support.google.com/youtube/answer/72431?hl=en) currently recommends 3840 × 2160 for video
  thumbnails. Its upload limits differ between desktop and mobile. Use custom `1280x720` or `1920x1080` for smaller
  masters.
- [Instagram photo resolution](https://help.instagram.com/1631821640426723) and
  [Meta sharing guidance](https://developers.facebook.com/docs/sharing/best-practices/) returned rate limits during this
  review. The Instagram, OG, square, portrait, and story presets are practical choices, not newly verified platform
  requirements. Check the native composer, especially for 3:4 uploads through scheduling tools.

## Iteration and Inspection

1. Inspect the master. Record the destination, requested placements, and any protected text, logo, or subject.
2. Use `pad` when the composition has baked-in text or branding. Set its background to match the artwork.
3. Use `crop` when the artwork has expendable edges. Choose gravity to keep the subject visible. Never stretch to fit.
4. Export from the master on every iteration. Resizing can upscale a small master, but it cannot recover detail.
5. Inspect each distinct aspect ratio at its final dimensions and thumbnail size. Check legibility, crop, alpha, and
   bytes.
6. Keep required branding visible. Follow project instructions for the X logo and `@PaulRBerg` in the bottom-right.
   Padding can move baked-in branding away from the output corner. If corner placement is required, composite an
   approved transparent brand lockup after resizing. Do not add a second copy over existing branding.
7. For lossless text and line art, use PNG. For smaller files, use JPEG and lower `--quality` from 90 to 82 or 75.
   Re-export into a new directory and inspect the result. The helper reports bytes but does not enforce platform limits.

For layout iterations, keep titles and logos in editable layers when possible. ImageMagick supports deterministic
[annotation and compositing](https://imagemagick.org/command-line-options/). Use a verified local font and an approved
logo asset. The preset helper changes geometry and encoding only. It cannot reflow text already baked into the source.

Inspect a batch without opening every full-resolution file:

```bash
magick montage ./social-v1/*.jpg -thumbnail 320x320 -tile 3x -geometry +12+12 ./contact-sheet-v1.jpg
magick identify -format '%f %wx%h %b\n' ./social-v1/*.jpg
```

View the contact sheet with the available image viewer, then inspect detailed exports as needed. Keep critical content
away from edges and platform UI overlays. A 9:16 still does not create a video or establish a valid Reel cover crop.

## Website Integration and Completion

For a website request, use the site's existing metadata component. Set an absolute public HTTPS `og:image` URL and the
actual `og:image:width`, `og:image:height`, MIME type, and descriptive `og:image:alt`. X can use a separate
`twitter:image` with `twitter:card=summary_large_image`. Multiple `og:image` tags do not route different sizes to named
platforms.

Use a versioned image URL when deploying a changed image. A local export alone does not update a live preview. When the
user requests cache refresh, follow [link-previews.md](link-previews.md) through the browser workflow.

Report the master, output paths, selected dimensions, fit/gravity, format, and verified byte sizes. State any crop or
legibility problem and whether website metadata or live previews were changed. Do not claim platform validation from
file dimensions alone.
