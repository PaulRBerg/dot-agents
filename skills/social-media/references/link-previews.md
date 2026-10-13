# Refresh Link Previews

Use this workflow when a shared page has a new Open Graph image but a social post still shows the old image. Load
`chromium-browser` and follow Browser Setup in `SKILL.md`.

## Scope and Limits

Distinguish the shared page URL, the image URL in its metadata, and the social post URL. Each has a different role.
Refreshing metadata or changing a shared URL does not guarantee that an existing post will replace its stored card. An
uploaded photo is separate from a link preview. This workflow does not replace attached media.

Identify the page URL and target platform from the request or existing post. Ask only for missing inputs that prevent
the requested action. If the user requests only a check or instructions, do not save post edits or publish anything.
Preserve the post text, media, audience, and account, except for the requested URL change.

## Choose the Platform Action

| Platform                    | Action                                                                                                                                           | Existing-post limit                                                                                                                                                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X (Twitter)                 | Try a versioned page URL when the original URL still produces an old card. Check the actual X composer.                                          | Use **Edit post** only when available for that post and account. Editing has eligibility and time limits. A URL edit may still retain the old card.                   |
| LinkedIn                    | Open [Post Inspector](https://www.linkedin.com/post-inspector/), enter the page URL, and click **Inspect**.                                      | LinkedIn says this refresh affects new posts. Existing posts keep their preview. Editing the post text does not establish that the card changed.                      |
| Facebook                    | Open [Sharing Debugger](https://developers.facebook.com/tools/debug/), enter the page URL, and click **Debug**. Use **Scrape Again** when shown. | Inspect the original post afterward. Use a refresh-share control only if the live interface offers it. Do not promise that a new scrape changes every existing share. |
| Farcaster and other clients | Check the live composer or post for a supported embed-refresh control. Otherwise, test a versioned URL in an authorized draft or edit.           | Do not assume that a published embed can be replaced. Report the observed client limit.                                                                               |

Prefer the platform's refresh tool before changing the page URL. A third-party preview checker does not clear a social
platform's cache. On X, treat URL versioning as a workaround to verify, not a guaranteed cache-purge operation. Do not
rely on the legacy Twitter Card Validator to render a preview or refresh an existing post.

## X Trailing-Slash URLs

On X (Twitter), a trailing `/` in the shared page URL can prevent the Open Graph preview image from appearing. Prefer
`https://example.com/post` over `https://example.com/post/` when sharing on X. Apply the supplied-URL rule in `SKILL.md`
before removing the slash. Confirm that the URL without the slash serves the same page and shows the intended image in
the X composer.

## Version the Shared URL

Add one unused query parameter, or increment an existing parameter used only for preview versioning. For a page without
a query, use `?v=2`. With an existing query, append `&v=2`. Put the query before any fragment.

| Original URL                            | Versioned URL                               |
| --------------------------------------- | ------------------------------------------- |
| `https://example.com/post`              | `https://example.com/post?v=2`              |
| `https://example.com/post?utm_source=x` | `https://example.com/post?utm_source=x&v=2` |
| `https://example.com/post?v=2#section`  | `https://example.com/post?v=3#section`      |

Preserve existing query values and the fragment. If `v` already controls site behavior, use an unused name such as
`ogv`. Do not append a second `?` or duplicate the version key. A fragment such as `#v2` is not a cache-busting query.
Do not alter signed URLs. Request a public share URL instead.

Open the candidate URL and confirm that it serves the same intended page. Check whether a redirect strips the parameter.
Inspect `og:url` and `rel="canonical"` when the platform still reuses the old card. Canonicalization may merge URL
variants. Do not change the site's canonical identity merely to defeat a preview cache. Reuse one verified version per
image revision. Do not generate new random URLs on every retry.

## Chromium Workflow

1. **Inspect the source.** Open the shared page in an owned background tab. Check `og:image` and, for X, `twitter:image`
   and `twitter:card`. Open the declared image URL and confirm that it shows the intended image. If `twitter:image`
   still names the old image, changing only `og:image` is insufficient for X.
2. **Check fetched metadata.** Open [OpenGraph.xyz](https://www.opengraph.xyz/) in another owned background tab. Submit
   only a public URL without credentials or private access tokens. Take a snapshot, fill **Paste your URL**, and click
   **Scan & Preview**. After results load, take a fresh snapshot. Inspect the platform preview and **HTML tags**. Use
   **Rescan** when needed. The image generator below the results does not change the source website or social post.
3. **Refresh the platform cache.** Use the matching action in the platform table for the exact page URL to be shared.
   Follow `chromium-browser` for login or verification gates. Confirm the fetched image and metadata in the result.
4. **Test a versioned URL when needed.** If the platform still shows the old card, construct a URL with the rules above.
   Recheck that URL in OpenGraph.xyz and, when available, the platform tool. In the target composer, remove the old URL
   and stale card, then insert the versioned URL. For an existing post, do this only when its editor supports card
   replacement. Wait for the new preview and inspect it before saving.
5. **Apply the authorized change.** Save the requested edit or submit an already-authorized new post only after the
   preview shows the intended image. If the editor cannot replace the card, leave the original post intact. Prepare the
   exact replacement URL and report whether a new post is required. Ask before publishing a replacement unless the user
   already authorized it. Never delete the original as an automatic fallback.
6. **Verify and clean up.** Reopen the saved post and visually confirm its image and link destination. A correct checker
   result proves only the checker result. Report separately whether the original post, a new post, or only a
   draft/checker shows the new image. Close all task-created tabs under `chromium-browser` cleanup rules.

Use fresh snapshot identifiers and explicit `pageId` values for every browser action. Take a screenshot when the
snapshot does not establish which image appears. If the composer offers no preview, report that verification limit
before any public submission that would serve only as a test.

## If the Image Is Still Old

- **Source or CDN cache:** confirm that the deployed page's fetched metadata and image bytes are current. A correct
  browser rendering alone does not prove that a crawler receives the same metadata. Check crawler errors and blocked
  requests reported by the inspector.
- **Separate image cache:** changing the page URL may leave the image cached under its old URL. If site edits are
  authorized, give the image a new filename, such as `cover-v2.jpg`, and update `og:image` and any `twitter:image`. An
  image query such as `cover.jpg?v=2` is another option only if the host/CDN honors it. Then repeat the page refresh.
  Otherwise, report the exact image URL that the site owner must update.
- **Stored post card:** if the inspectors show the new image but the existing post does not, report that distinction.
  Avoid repeated public edits or duplicate posts as cache probes.

For this route, report the original and final shared URLs, target platform, verified post URL, and preview result.
Include any remaining edit restriction or source change required. Do not use the cross-posting final-report checklist.

## Sources

- [LinkedIn: Use Post Inspector to refresh URL](https://www.linkedin.com/help/linkedin/answer/a6233775)
- [X: About Edit Post](https://help.x.com/en/using-x/edit-post)
- [Meta: Sharing for Webmasters](https://developers.facebook.com/documentation/sharing/webmasters)
- [Open Graph protocol](https://ogp.me/)

Platform limits and checker controls were checked on 2026-10-13. Use the live interface when labels or eligibility
change.
