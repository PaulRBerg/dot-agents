---
argument-hint:
  <text> [image or video paths] [link] | images <source> <new-output-dir> [presets] | refresh-preview <page-url>
  [platform] [post-url]
compatibility:
  Image exports require ImageMagick 7 and Bash. Publishing and preview refresh require the chromium-browser skill and
  its Chrome DevTools MCP attached to the user's shared, logged-in Chromium browser.
disable-model-invocation: true
name: social-media
skill-dependencies:
  - chromium-browser
description:
  Post one user-supplied text, with optional images, video, or link, to X, LinkedIn, Farcaster, and Facebook (in
  Romanian), and to Hacker News when it suits that audience. Resize source artwork into OpenGraph and social image
  presets with ImageMagick. Also refresh stale link previews or find subreddits. Publishing uses shared Chromium.
---

# Social Media

Prepare social images locally, or publish one post across the user's social accounts through shared Chromium. User
instructions take precedence over this skill. For example, drafts only, a different platform set, or no translation
replaces the matching default below. Image writes inside Git worktrees require the normal coordination gate. Browser
actions and exports outside Git worktrees do not.

## Routes

- **Images**: for OpenGraph images, social size variants, cropping, padding, or compression, follow
  [references/images.md](references/images.md). Use [scripts/export-images.sh](scripts/export-images.sh) with a saved
  source image. This local route does not require post text, a browser, publishing, or subreddit discovery.
- **Publish**: follow the inputs and posting workflow below.
- **Refresh preview**: when the user requests an updated link preview or uses `refresh-preview`, follow
  [references/link-previews.md](references/link-previews.md). Use Browser Setup below. This route accepts a page URL and
  the target platform or existing post URL. It does not require new post text, cross-posting, or subreddit discovery.

## Inputs

These inputs apply to publishing.

- **Text**: required. Treat it as final copy. Post it verbatim on every platform except Facebook. Do not rewrite,
  shorten, add hashtags, or add emoji.
- **Media**: optional images or one video, as absolute file paths on the browser host. Before you open the browser,
  confirm that each file exists and has an image or video type. If the user attached media without a usable path, ask
  for the path before you post anywhere.
- **Link**: optional URL. If the text does not already contain the link, append it on a new line at the end of the post
  text.

If a publishing request has no text, ask for it. Do not ask other questions when the defaults below cover the case.

## Authority

A request to prepare images authorizes local exports. It does not authorize posting, deployment, or preview refresh.

A publishing request authorizes the posts. Post directly. Do not add a confirmation gate. A preview-refresh request
authorizes the cache refresh and requested URL edits on the specified posts. It does not authorize deletion or
replacement posts unless the user requests them. Never post to Reddit. Reddit work is discovery only.

Keep each composer's existing audience, visibility, and account selection. Do not change account settings, follow
accounts, or engage with other posts.

## Browser Setup

Load `chromium-browser` before you use the browser. Follow its page-ownership, live-tool, human-gate, and cleanup rules
for every page in this workflow. Do all website lookups and posts in that browser. Do not use WebFetch, curl, site APIs,
or other browsers.

Open one owned background page per platform and record each `pageId`. Calls to one MCP server run serially. Thus,
complete each platform before you start the next one.

## Workflow

1. **Read the platform notes.** Read [references/platforms.md](references/platforms.md) completely.
2. **Decide on Hacker News.** Apply the suitability test in
   [references/platforms.md](references/platforms.md#hacker-news). Record the decision and a one-sentence reason.
3. **Check logins.** Open the home page of X, LinkedIn, Farcaster, and Facebook. If step 2 selected Hacker News, also
   open its home page. Take a snapshot of each page and look for a logged-in signal, such as a compose control or an
   account menu. A login form, a "Sign in" control, or a redirect to a login URL means that the user is logged out.
4. **Ask for logins in one message.** If one or more selected sites are logged out, name all of them in one message. Ask
   the user to log in on those pages. Do not end the turn.
5. **Translate for Facebook.** Translate the text into Romanian with the rules in
   [references/platforms.md](references/platforms.md#facebook). If the text is already in Romanian, use it unchanged.
6. **Post.** Post on the logged-in platforms in this order: X, LinkedIn, Farcaster, Facebook, and Hacker News when
   selected. For each platform, follow the composer procedure below.
7. **Discover subreddits.** Read [references/reddit-discovery.md](references/reddit-discovery.md) and follow it.
8. **Clear the login gates.** For each logged-out page, follow the `chromium-browser` human-gate procedure. When the
   gate clears, post on that platform.
9. **Clean up.** Close only the pages that this task created.

## Composer Procedure

Do these steps for each platform:

1. Open the composer. Take a fresh snapshot. Use the identifiers from that snapshot.
2. Enter the platform text. For a contenteditable composer, use `type_text` or `fill`. Then take a snapshot and confirm
   that the composer shows the full text. Paragraph breaks must be intact, and the composer must not show duplicated or
   missing characters.
3. Attach the media with `upload_file`. Wait until each upload finishes processing and the post button is enabled.
4. If the composer shows an over-limit counter or rejects the length, use the platform's overflow rule in
   [references/platforms.md](references/platforms.md). If a link preview is stale, follow
   [references/link-previews.md](references/link-previews.md) before submission. Preserve the supplied URL unless the
   user requested a preview refresh or authorized a URL change.
5. Submit the post. Then read it back. Open the new post from the confirmation notice or from the user's own profile
   feed. Confirm that the text and media appear and record the post URL.

The live composer is authoritative for limits, controls, and labels. Platform interfaces change. Thus, when a named
control is absent, find the equivalent control in a fresh snapshot. Do not guess from memory.

## Failure and Retry

- If a submit result is uncertain, do not submit again first. Look for the post on the user's own profile feed. Retry
  only after you confirm that the post does not exist. A duplicate public post is worse than a missing post.
- If a platform shows a captcha, a 2FA prompt, or a verification step, follow the `chromium-browser` human-gate
  procedure for that page.
- If a platform rejects the post after one retry, stop work on that platform. Record the exact error and continue with
  the other platforms.

## Final Report

For images, use the completion report in [references/images.md](references/images.md). The report below applies to
publishing.

Lead with one outcome line, such as "Posted on 4 of 5 platforms". Then give these sections:

- **Posts**: a table with these columns: platform, status, and verified post URL. For a skipped or failed platform, give
  the reason. Show the Romanian Facebook text in full.
- **Hacker News**: the decision and its reason. Give the item URL, or the existing item URL if Hacker News redirected to
  an earlier submission.
- **Reddit**: the ranked subreddit table from [references/reddit-discovery.md](references/reddit-discovery.md).
- **Other places**: optional. From your own knowledge, you may suggest other sites, communities, newsletters, or
  aggregators that suit this post. Give each suggestion one reason. Label the section as unverified suggestions from
  general knowledge. Do not visit those sites.

Completion requires a verified post URL or a recorded reason for each platform, a completed Reddit discovery, and closed
task pages.
