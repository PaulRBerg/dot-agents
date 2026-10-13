# Platform Notes

Use these notes with the composer procedure in `SKILL.md`. The live composer is authoritative. When these notes and the
live interface disagree, follow the interface and report the difference.

## Contents

- [Shared rules](#shared-rules)
- [X](#x)
- [LinkedIn](#linkedin)
- [Farcaster](#farcaster)
- [Facebook](#facebook)
- [Hacker News](#hacker-news)

## Shared Rules

- **Media limits**: if a composer refuses a media item, keep the items that it accepts in the user's order. Report each
  omitted item.
- **Overflow split**: split at paragraph boundaries first, then at sentence boundaries. Do not change, drop, or reorder
  words. Do not add numbering such as "1/3". Attach all media to the first part.
- **Rich-text editors**: most composers are contenteditable editors that keep their own state. Click into the editor,
  then use `type_text`. If the post button stays disabled after `fill`, clear the editor and use `type_text`.

## X

- Composer: `https://x.com/compose/post`, or the "Post" control on `https://x.com/home`.
- Length: the limit depends on the account tier. The composer counts each URL as a fixed short length.
- Overflow: use the shared overflow split as a thread. Add each part with the composer's add-post control. Then post the
  whole thread in one submit.
- Readback: open the post from the "Your post was sent" notice, or from the user's profile. Record the
  `https://x.com/<handle>/status/<id>` URL.

## LinkedIn

- Composer: the "Start a post" control on `https://www.linkedin.com/feed/`. Post as the personal profile that the
  composer selects.
- Link: keep the URL in the text. When no media is attached, wait for the link preview card before you submit.
- Overflow: use the shared overflow split. Put the parts that fit in the post. Then post the remaining parts as the
  first comment on that post.
- Readback: open the post from the "View post" notice, or from the profile activity page. Record the post URL.

## Farcaster

- Composer: `https://farcaster.xyz`. Do not use `farcaster.com`, which is an unrelated company. The `warpcast.com`
  domain redirects to `farcaster.xyz`.
- Channel: post to the home feed. Select a channel only when the user names one.
- Embeds: a cast holds a small number of embeds, and a link in the text can use one of them. Keep the link first. Then
  apply the shared media-limit rule to the media.
- Overflow: the byte limit depends on the account tier. Use the shared overflow split. Post the remaining parts as
  replies to the user's own cast, in order.
- Readback: open the cast from the user's profile. Record the cast URL.

## Facebook

- Composer: the "What's on your mind" control on `https://www.facebook.com/`. Post on the user's personal profile.
- Audience: keep the audience that the composer selects.
- Link: keep the URL in the text. Wait for the link preview before you submit.
- Readback: open the user's profile. Open the post from its timestamp link and record that permalink.

### Romanian Translation

- Write natural Romanian, as a native speaker would write a social post. Do not translate word for word.
- Keep the meaning, tone, register, and paragraph breaks. Match the source formality. Use informal address for casual
  text.
- Use the comma-below letters `ș`, `ț`, `Ș`, and `Ț` (U+0219, U+021B, U+0218, U+021A). Do not use the cedilla letters
  `ş` and `ţ`. Use all diacritics: `ă`, `â`, and `î`.
- Keep URLs, @handles, hashtags, product names, brand names, code, numbers, and tickers unchanged. Translate an English
  technical term only when Romanian has a common equivalent.
- Do not add notes, explanations, or a translation label.

## Hacker News

### Suitability Test

Select Hacker News only when all of these conditions are true:

- The post has a URL, or the text is a real question for discussion (Ask HN).
- The subject interests technical readers: software, hardware, science, startups, security, or original research. It can
  also be another subject that gives a new insight.
- The content is not mainly politics, crime, sports, celebrity news, memes, or marketing copy.
- The linked page has its own substance. A sign-up page, a press release with no technical depth, or an engagement post
  does not pass.

If you are not sure, skip Hacker News and give the reason. A poor submission harms the user's Hacker News reputation. An
explicit user request to post or to skip replaces this test.

### Submission

- Form: `https://news.ycombinator.com/submit`.
- Title: open the link and use the page's original title. Remove the site name, clickbait, gratuitous adjectives,
  uppercase emphasis, and exclamation marks. Keep it at 80 characters or fewer. Rewrite the title only when the original
  title is misleading or clickbait.
- Show HN: add the `Show HN: ` prefix only when the user made the linked thing and other people can try it. A blog post,
  newsletter, list, sign-up page, or landing page is not a Show HN.
- Text field: leave it empty for a URL submission, except for Show HN. For Show HN, put the user's text in the text
  field. For Ask HN, use `Ask HN: ` plus a title that states the question, and put the user's text in the text field.
- Media: Hacker News does not accept media. Ignore the images and video.
- Duplicate: if Hacker News opens an existing item for the URL, do not submit again. Record that item URL.
- Rate limit: if Hacker News says that you are posting too fast, record the message and stop work on Hacker News.
- Readback: open `https://news.ycombinator.com/submitted?id=<username>`. Find the new item and record its
  `https://news.ycombinator.com/item?id=<id>` URL.
