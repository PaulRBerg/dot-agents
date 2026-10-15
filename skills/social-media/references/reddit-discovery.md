# Reddit Discovery

Find the subreddits where the post fits best and where the rules permit it. Prepare drafts with minimal changes to the
user's text. Discovery is read-only, and submissions remain manual. The only permitted write is an authorized link
comment under [Links After Post Approval](#links-after-post-approval). Do not vote, join, or send messages on Reddit. A
logged-out session is sufficient for discovery. If Reddit shows a captcha or a block page, follow the `chromium-browser`
human-gate procedure.

## Procedure

1. **Get the topic.** Take three to six search terms from the text. If the post has a link, open it on an owned page and
   take terms from its title and main content.
2. **Find candidates.** On an owned `https://www.reddit.com` page, search for communities with each term at
   `https://www.reddit.com/search/?q=<term>&type=communities`. Also search for posts at
   `https://www.reddit.com/search/?q=<term>&type=posts&sort=top&t=year`. Record the subreddits where similar posts got
   strong engagement. Collect 10 to 20 candidates.
3. **Inspect each candidate.** From the Reddit page, call `evaluate_script` with a same-origin `fetch` of
   `/r/<name>/about.json` and `/r/<name>/about/rules.json`. Return only these fields: subscriber count, a short public
   description, whether link, image, and text posts are allowed, and the rule titles. Bound each result to a short
   summary. If a fetch fails, read the subreddit's sidebar and rules page from a snapshot.
4. **Check recent activity.** Open `https://www.reddit.com/r/<name>/new/` for the strongest candidates. Confirm that the
   subreddit has recent posts and that similar posts stay up. Look for these limits: self-promotion ratios, required
   flair, weekly threads such as "Showoff Saturday", and minimum karma or account age. Read the full relevant rules and
   linked wiki guidance. Check whether links are allowed in titles, bodies, or comments, and whether moderator approval
   is required.
5. **Rank.** Exclude a subreddit when its rules forbid this post type or forbid self-promotion. Rank the rest by topic
   fit first, then by recent activity, then by size. Prefer an active niche subreddit to a large generic one.
6. **Tailor drafts.** For the three strongest matches, make only the necessary edits under the drafting rules below. Use
   all matches when fewer than three qualify. If the user names target subreddits, prepare a draft for each permitted
   target.

## Drafting Rules

- Start from the supplied text, not from the linked article. Preserve its wording, voice, structure, meaning, and
  factual claims. Keep approximately the same length or shorter. A short source must remain a short post.
- Change only what the subreddit rules or a clear mismatch with its topic require. Reuse the same draft where it fits.
  If a title is missing, derive a short, factual title from the source.
- Do not expand the source into an essay, article summary, feature list, or explanation of the user's workflow. Do not
  add background, disclaimers, promotional framing, or feedback questions unless the user requests them or a rule
  requires them. Put the subreddit-fit explanation in the recommendation table, not in the post.
- Do not invent capabilities, personal experience, or community membership. Preserve supplied links except where the
  link-placement rules below require moving them. Do not ask for upvotes.
- Before returning each draft, compare it with the source and remove unnecessary additions. If compliance requires a
  substantial rewrite or expansion, explain the requirement instead of silently rewriting the post.
- If the community prohibits AI-written or AI-edited text, provide editorial suggestions for the user instead of a
  draft.

## Links After Post Approval

Some subreddits forbid links in the title and body but allow them in comments. For those communities:

1. Prepare a text-only draft without URLs or Markdown hyperlinks in the title or body. Preserve the surrounding copy
   with minimal edits. Prepare the supplied URL separately as a comment. Do not say the link is already in a comment.
2. Confirm that the rules allow the link comment. A comment is not a workaround for a ban on self-promotion or links
   everywhere. If comments are also restricted, report the restriction instead.
3. After the user submits the post, open its URL and confirm subreddit approval before commenting. Check public
   visibility and any moderation notices. When explicit moderator approval is required, verify it. A submission
   confirmation or the user's approval of the draft does not establish subreddit approval.
4. If approval is pending, the post is removed, or approval cannot be verified, keep the comment pending. Report the
   missing post URL or approval evidence. Do not repost automatically.
5. For an authorized publishing request, post the link comment once approval is verified. Use the supplied URL, with at
   most a short label. Do not add another pitch or article summary. Follow the browser login and human-gate rules when
   needed. For drafts-only requests, return the comment draft instead.
6. Before posting or retrying, check the user's existing comments for the same link. Reuse an existing comment rather
   than duplicate it. After submission, read the comment back and record its permalink.

## Output

Give at most 10 rows, sorted by rank:

| Column       | Content                                                                                                  |
| ------------ | -------------------------------------------------------------------------------------------------------- |
| Rank         | 1 is the best fit                                                                                        |
| Subreddit    | `r/<name>` linked to `https://www.reddit.com/r/<name>/`                                                  |
| Members      | Subscriber count from step 3                                                                             |
| Why it fits  | One sentence about the topic match or similar successful posts                                           |
| Post as      | Link, image, or text post, as the rules permit                                                           |
| Rule caveats | Link placement, approval requirements, flair, self-promotion limits, weekly threads, or account minimums |

After the table, list each excluded subreddit that a reader can expect to see, with the rule that excludes it.

Then give the tailored drafts under their subreddit names. Include the title and body, or an introductory comment when
the selected post format has no body and the rules permit one. Label each as a draft for manual posting. Report any
editorial-only suggestions with the rule that prevents drafting. For links allowed only in comments, separate the post
draft from the comment draft. Label the comment "After subreddit approval". Report its verified permalink or why it
remains pending.
