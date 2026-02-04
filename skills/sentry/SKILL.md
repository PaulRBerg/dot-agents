---
name: sentry
description: This skill should be used when the user asks to "fetch Sentry issues", "check Sentry errors", "triage Sentry", "categorize Sentry issues", "resolve Sentry issue", "archive Sentry issue", "ignore Sentry issue", "mark issue resolved", or mentions Sentry API, Sentry project issues, error monitoring, or issue triage.
---

# Sentry Issue Management

Manage Sentry issues for the sablier-labs/portal project. Fetch, categorize, resolve, and archive issues using the Sentry API.

## Authentication

Authenticate using `SENTRY_AUTH_TOKEN` from `portal/.env.local`:

```bash
source <(grep SENTRY_AUTH_TOKEN portal/.env.local)
```

Use the token in API requests:

```bash
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/..."
```

## API Configuration

- **Organization**: `sablier-labs`
- **Project**: `portal`
- **Base URL**: `https://sentry.io/api/0`

## Fetching Issues

### List All Unresolved Issues

```bash
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/sablier-labs/portal/issues/?query=is:unresolved"
```

### List Issues with Details

```bash
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/sablier-labs/portal/issues/?query=is:unresolved&statsPeriod=14d"
```

### Get Issue Details

```bash
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/issues/{issue_id}/"
```

### Get Latest Event for Issue

```bash
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/issues/{issue_id}/events/latest/"
```

## Issue Categorization

Categorize each issue into one of four categories:

### 1. Valid

Genuine application errors requiring investigation and fixes.

**Indicators:**
- Stack trace points to application code (e.g., `portal/`, `@/`, `src/`)
- Error originates from application logic, not external code
- Reproducible user-facing issues
- API errors from application endpoints

### 2. False Positives

Errors that appear as issues but are not actual problems.

**Indicators:**
- Network errors from user connectivity issues (timeouts, DNS failures)
- Browser-specific quirks not affecting functionality
- Expected errors (e.g., 401 for unauthenticated users, 404 for deleted resources)
- Errors from automated bots/crawlers

### 3. Already Resolved

Issues that have been fixed in subsequent deployments.

**Indicators:**
- Last seen date predates a known fix
- No recent occurrences (check `lastSeen` field)
- Related code has been refactored or removed
- Issue matches a closed GitHub issue or merged PR

### 4. Third Party

Errors originating from browser extensions or external scripts not under our control.

**Indicators:**
- Stack trace contains extension paths:
  - `chrome-extension://`
  - `moz-extension://`
  - `safari-extension://`
- Error from injected scripts (common patterns):
  - `inpage.js` (wallet extensions)
  - `content.js` (browser extensions)
  - `inject.js`
- Known extension error messages:
  - `ResizeObserver loop` (common extension issue)
  - `Extension context invalidated`
  - `Cannot read properties of undefined` from extension code
- Stack trace mentions known extensions:
  - MetaMask, Phantom, Coinbase Wallet
  - Ad blockers (uBlock, AdBlock)
  - Password managers (LastPass, 1Password)
  - Grammarly, Honey, etc.

## Triage Workflow

1. **Fetch all unresolved issues**
2. **For each issue:**
   - Fetch the latest event to inspect the stack trace
   - Check the `culprit`, `title`, and `metadata` fields
   - Examine the stack trace for extension paths or application code
   - Check `lastSeen` and event count
3. **Categorize** into Valid, False Positive, Already Resolved, or Third Party
4. **Present results** in a summary table

### Example Output Format

```markdown
## Sentry Issue Triage Report

### Valid (3 issues)
| Issue | Title | Events | Last Seen |
|-------|-------|--------|-----------|
| PORTAL-123 | TypeError in StreamCard | 45 | 2h ago |
| PORTAL-124 | API timeout in fetchStreams | 12 | 1d ago |
| PORTAL-125 | Missing translation key | 8 | 3h ago |

### Third Party (5 issues)
| Issue | Title | Source | Events |
|-------|-------|--------|--------|
| PORTAL-126 | ResizeObserver loop | Browser Extension | 234 |
| PORTAL-127 | Cannot read 'ethereum' | MetaMask | 89 |

### False Positives (2 issues)
| Issue | Title | Reason |
|-------|-------|--------|
| PORTAL-128 | Network Error | User connectivity |
| PORTAL-129 | 401 Unauthorized | Expected for guests |

### Already Resolved (1 issue)
| Issue | Title | Last Seen | Notes |
|-------|-------|-----------|-------|
| PORTAL-130 | Hydration mismatch | 14d ago | Fixed in v2.3.1 |
```

## Managing Issues

### Resolve an Issue

```bash
curl -X PUT -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "resolved"}' \
  "https://sentry.io/api/0/issues/{issue_id}/"
```

### Archive (Ignore) an Issue

```bash
curl -X PUT -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "ignored"}' \
  "https://sentry.io/api/0/issues/{issue_id}/"
```

### Ignore with Reason

```bash
curl -X PUT -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "ignored", "statusDetails": {"ignoreCount": 100}}' \
  "https://sentry.io/api/0/issues/{issue_id}/"
```

### Bulk Update Issues

```bash
curl -X PUT -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "ignored"}' \
  "https://sentry.io/api/0/projects/sablier-labs/portal/issues/?id=123&id=456&id=789"
```

## Codebase Integration

### Core Sentry Files

| File | Purpose |
|------|---------|
| `core/isomorphic/configs/sentry.ts` | Base Sentry config factory, `sampleExpectedErrors` beforeSend handler |
| `core/isomorphic/constants/sentry.ts` | Shared constants: sample rates, ignored/sampled patterns, extension patterns |
| `core/client/configs/sentry.ts` | Client-side Sentry initialization |
| `core/server/configs/sentry.ts` | Server-side Sentry initialization |
| `core/server/configs/next/with-sentry.ts` | Next.js config wrapper for Sentry integration |

### Portal-Specific Files

| File | Purpose |
|------|---------|
| `portal/instrumentation.ts` | Server instrumentation entry point |
| `portal/instrumentation-client.ts` | Client instrumentation entry point |
| `portal/lib/errors/sentry-consent.ts` | User consent check for Sentry (GDPR compliance) |
| `portal/lib/errors/use-sentry-capture.ts` | React hook for manual error capture |
| `portal/lib/errors/telemetry.ts` | Client-side telemetry utilities |
| `portal/lib/errors/telemetry.server.ts` | Server-side telemetry utilities |

### Key Constants

The codebase already filters many extension/wallet errors. See `core/isomorphic/constants/sentry.ts`:

- `SENTRY_IGNORED_ERROR_PATTERNS` - Fully ignored errors (user rejections, proxy traps)
- `SENTRY_SAMPLED_ERROR_PATTERNS` - Sampled at 5% (expected domain errors)
- `INJECTED_SCRIPT_PATTERNS` - Known wallet extension scripts
- `PROVIDER_PROXY_ERROR_PATTERNS` - Wallet proxy failures
- `EXTENSION_COMMUNICATION_PATTERNS` - Extension communication errors

### When Triaging

Cross-reference Sentry issues with these constants. If an error matches existing patterns but is still appearing:

1. Check if the pattern needs to be more specific
2. Consider adding to `SENTRY_IGNORED_ERROR_PATTERNS` for full ignore
3. Consider adding to `SENTRY_SAMPLED_ERROR_PATTERNS` for 5% sampling

## Additional Resources

### Reference Files

- **`references/api-reference.md`** - Complete Sentry API documentation
- **`references/extension-patterns.md`** - Comprehensive list of browser extension error patterns

### Scripts

- **`scripts/fetch-issues.sh`** - Fetch and display all unresolved issues
- **`scripts/categorize-issue.sh`** - Analyze a single issue and suggest category
