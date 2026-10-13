# Reddit Discovery

Find the subreddits where the post fits best and where the rules permit it. This work is read-only. Do not post,
comment, vote, join, or send messages on Reddit. A logged-out session is sufficient. If Reddit shows a captcha or a
block page, follow the `chromium-browser` human-gate procedure.

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
   flair, weekly threads such as "Showoff Saturday", and minimum karma or account age.
5. **Rank.** Exclude a subreddit when its rules forbid this post type or forbid self-promotion. Rank the rest by topic
   fit first, then by recent activity, then by size. Prefer an active niche subreddit to a large generic one.

## Output

Give at most 10 rows, sorted by rank:

| Column       | Content                                                                    |
| ------------ | -------------------------------------------------------------------------- |
| Rank         | 1 is the best fit                                                          |
| Subreddit    | `r/<name>` linked to `https://www.reddit.com/r/<name>/`                    |
| Members      | Subscriber count from step 3                                               |
| Why it fits  | One sentence about the topic match or similar successful posts             |
| Post as      | Link, image, or text post, as the rules permit                             |
| Rule caveats | Flair, self-promotion limits, required weekly threads, or account minimums |

After the table, list each excluded subreddit that a reader can expect to see, with the rule that excludes it.
