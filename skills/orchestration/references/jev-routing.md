# Jev Configuration Routing

Before each new research or implementation brief launches, use this workflow to select its worker configuration. The
parent retains the worker family selected in `SKILL.md`. Jev rates the brief against an ordered ladder of allowed model
and effort pairs. User instructions take precedence over this workflow.

## Allowed Candidates and Local Fallback

1. Read the selected adapter. Classify the brief with its existing work tiers and retain that configuration as the local
   fallback.
2. Build candidates from the adapter's supported configurations. Apply explicit user model, custom-agent, and effort
   constraints first.
3. Preserve research-only restrictions, model ceilings, host permissions, and verified model and effort support.
4. For a fixed dimension, give every candidate the same value. Never offer Jev an override of that dimension.

Use these default candidates unless explicit constraints narrow them:

| Adapter       | Research pairs                                     | Implementation pairs                                           |
| ------------- | -------------------------------------------------- | -------------------------------------------------------------- |
| Native Codex  | Luna/high, Sol/medium, Sol/high                    | Luna/high, Sol/medium, Sol/high, Sol/xhigh, Astra/xhigh        |
| Codex CLI     | Luna/high, Sol/medium                              | Luna/high, Sol/medium, Sol/high, Sol/xhigh, Astra/xhigh        |
| Native Claude | Sonnet/medium, Sonnet/high, Opus/medium, Opus/high | Sonnet/medium, Sonnet/high, Opus/medium, Opus/high, Opus/xhigh |
| Claude CLI    | Sonnet/medium, Sonnet/high, Opus/medium, Opus/high | Sonnet/medium, Sonnet/high, Opus/medium, Opus/high, Opus/xhigh |

Expand Codex names to `gpt-6-luna`, `gpt-6.1-sol`, and `gpt-6-astra`. Use the Claude aliases `sonnet` and `opus`. For
Claude, include only pairs verified as supported by the selected tool or CLI and model. Add Opus/xhigh to research only
when support and the investigation justify it. Never infer pair support from the flag alone.

For Native Claude, determine per-call effort support as [the native adapter](native-claude.md#configuration) describes.
If the tool lacks effort control, replace explicit efforts with `inherited` and deduplicate candidates. Forked subagents
inherit the parent's effort, so do not offer an effort override for them. For a custom Claude agent, preserve its
configured model and effort unless the user explicitly overrides them. If host-controlled settings leave no choice, skip
Jev.

An explicit model can expose supported efforts beyond the default table. Verify those pairs before offering them. An
explicit effort can narrow supported models. If the route cannot honor a requested value, report the adapter
incompatibility. Do not use Jev to replace an incompatible user request.

If only one configuration remains, skip the network request. Use it directly and record `selection: fixed` in the brief.
For either Claude route's fallback, preserve configured effort unless the user specified one. Keep CLI timeouts under
the adapter's local rules.

## Candidate Order and Descriptions

List candidates from the cheapest pair to the strongest pair, in the table order above. Jev rates the brief on that
ladder, and the acceptance rule treats neighbouring positions as interchangeable. A wrong order breaks both.

Give each candidate the description below. Replace a description only when a user constraint changes what the pair is
for. Thin or overlapping descriptions, such as "bounded survey" against "bounded survey, more careful", leave Jev
nothing to separate the tiers with. When effort is `inherited`, omit the effort phrase.

| Pair          | Description                                                                                                                                                     |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Luna/high     | Fast small model at deep effort. Bounded, well-specified routine work: lookups, mechanical edits, focused tests, short summaries.                               |
| Sol/medium    | Capable mid-tier model at default effort. Moderate work: several files, some ambiguity, routine debugging, careful surveys across sources.                      |
| Sol/high      | Capable mid-tier model at deep effort. Involved work that needs judgment: unfamiliar subsystems, design trade-offs, cross-cutting changes, noisy sources.       |
| Sol/xhigh     | Capable mid-tier model at maximum effort. Hard, ambiguous work with high error cost: interacting invariants, concurrency, strict verification.                  |
| Astra/xhigh   | Strongest model at maximum effort. The hardest implementation work: broad blast radius, many interacting invariants, mistakes that are expensive to undo.       |
| Sonnet/medium | Fast mid-tier model at default effort. Bounded, well-specified work in familiar territory: lookups, mechanical edits, focused tests, summaries of a few files.  |
| Sonnet/high   | Fast mid-tier model at deep effort. Moderate work that needs care but not frontier judgment: several files, some ambiguity, routine debugging, careful surveys. |
| Opus/medium   | Strongest model at default effort. Involved work that needs strong judgment: unfamiliar subsystems, design trade-offs, cross-cutting changes, noisy sources.    |
| Opus/high     | Strongest model at deep effort. Hard, ambiguous work with high error cost: interacting invariants, concurrency, security-sensitive logic, deep investigation.   |
| Opus/xhigh    | Strongest model at maximum effort. The hardest implementation work: broad blast radius, many interacting invariants, mistakes that are expensive to undo.       |

## Request

Before sending data to Vercel, review the task summary and context for external disclosure. Remove secrets, unrelated
personal or customer data, unsuitable private paths or repository names, and unrelated transcript material. Send only
the brief's outcome, complexity, authority boundary, verification needs, and relevant configuration constraints. Never
send repository contents or the full parent conversation by default.

Resolve `../scripts/select-model.py` relative to this reference. Run it with Python 3 through the host's available
shell. Use the target project's Python command convention when present. Supply a JSON object on stdin, with candidates
in ladder order:

```json
{
  "task": "Correct a bounded parser bug and add a focused regression test.",
  "context": "Implementation. Native Codex. Two files. No external writes.",
  "candidates": [
    {
      "id": "luna_high",
      "model": "gpt-6-luna",
      "effort": "high",
      "description": "Fast small model at deep effort. Bounded, well-specified routine work: lookups, mechanical edits, focused tests, short summaries."
    },
    {
      "id": "sol_medium",
      "model": "gpt-6.1-sol",
      "effort": "medium",
      "description": "Capable mid-tier model at default effort. Moderate work: several files, some ambiguity, routine debugging, careful surveys across sources."
    }
  ]
}
```

Read `AI_GATEWAY_API_KEY` from the environment. Do not read credential files, print the key, or write it into artifacts.
The helper makes one POST to `https://ai-gateway.vercel.sh/v1/evaluate` with model `typesafe-ai/jev`. It asks a single
[Score question](https://docs.typesafe.ai/api) whose ordered levels are the candidates, so the answer is a probability
per ladder position. It does not use a chat endpoint. Use the
[Vercel Decision HTTP API](https://vercel.com/docs/ai-gateway/modalities/decision#http-api) request format. Its
[native decision response](https://vercel.com/docs/ai-gateway/models-and-providers/decision-fallbacks#use-the-http-decision-api)
includes provider confidence. It disables redirects and environment-configured proxies. It bounds the response to 64 KiB
and the complete request to eight seconds. If the host cannot enforce that deadline, the helper returns fallback without
sending the request. The helper accepts at most ten candidates, which is Jev's level limit.

## Accept or Fall Back

Accept only `status: selected` with an exact allowed candidate ID and its unchanged model and effort. The helper
requires a complete finite probability distribution over every ladder position, approximately summing to one, with a
unique maximum. The selected candidate is that maximum. It recomputes
[Jev's Score confidence formula](https://docs.typesafe.ai/confidence#score), which discounts probability on distant
levels more than probability on neighbouring levels, and checks the returned confidence against it.

Observed live responses and [Jev's published examples](https://docs.typesafe.ai/api) are consistent with independent
rounding to hundredths. The local tolerance permits this rounding without assuming guaranteed wire precision. Under this
rounding, each probability can differ by `0.005` from its unrounded value. For `n` levels, the helper permits a
distribution sum error of `n * 0.005`. For the confidence check, it scales the probability rounding by the total level
distance over the uniform spread and adds `0.005` for confidence rounding. A small floating-point allowance covers
numerical representation error. The helper does not normalize probabilities or raise confidence.

The helper accepts a selection under either rule:

- `rule: confidence`. Both provider confidence and recomputed confidence reach `0.6`.
- `rule: adjacent_tiers`. The runner-up level is a neighbour of the maximum, no distant level ties with the runner-up,
  and the two levels hold at least `0.8` of the probability together. A split between neighbouring tiers means either
  tier would do, so the helper takes the more probable one. With two candidates, every split is adjacent, so only a tie
  abstains.

The result reports the rule and the provider confidence. An `adjacent_tiers` result also reports `top_two_mass`. On 81
recorded briefs, the earlier unordered Choice question with a `0.6` confidence floor accepted 34 percent. The Score
ladder with the standard descriptions and the adjacency rule accepted 93 percent, and still abstained on every split
between distant tiers. These rates are a local measurement, not a calibrated accuracy guarantee. A `low_confidence`
result is an expected abstention, not an API malfunction. The parent must still reject a selection that conflicts with
the task, constraints, or verified runtime support.

On any failure, uncertainty, dubious selection, unavailable Python or shell, missing key, malformed output, or nonzero
helper exit, use the local fallback. Do not retry, ask for approval, stop the handoff, or substitute a worker family
because Jev is unavailable.

The helper returns a safe reason code on failure. An `invalid_response` result can include a fixed validation `detail`
code. A `low_confidence` result includes provider `confidence` and the `threshold`. It also includes
`recomputed_confidence` when only that value falls below the threshold. Never expose raw API errors, response bodies, or
credentials.

Record `selection: jev; rule: <rule>; confidence: <value>` or `selection: fallback; reason: <safe code>` in the manifest
brief. For a parent rejection, use `parent_rejected`. Include optional safe `detail` codes and numeric confidence
diagnostics when present. Keep this record concise. Do not explain an abstention in user-facing prose. The local
fallback is the normal path, not an incident.

Continue through the selected adapter's normal launch mechanics. Reuse the selected configuration for same-agent
continuation. Route each genuinely new brief again.
