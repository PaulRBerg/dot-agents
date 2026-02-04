# Sentry API Reference

Complete API reference for managing Sentry issues programmatically.

## Authentication

All requests require an authentication token in the `Authorization` header:

```
Authorization: Bearer {SENTRY_AUTH_TOKEN}
```

## Base URL

```
https://sentry.io/api/0
```

## Project Endpoints

### List Project Issues

```
GET /projects/{organization_slug}/{project_slug}/issues/
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | string | Search query (e.g., `is:unresolved`, `is:resolved`, `is:ignored`) |
| `statsPeriod` | string | Time period for stats (e.g., `24h`, `14d`, `30d`) |
| `cursor` | string | Pagination cursor |
| `limit` | integer | Number of results (max 100) |
| `sort` | string | Sort order: `date`, `new`, `priority`, `freq`, `user` |

**Example:**

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://sentry.io/api/0/projects/sablier-labs/portal/issues/?query=is:unresolved&statsPeriod=14d&limit=100"
```

**Response:**

```json
[
  {
    "id": "12345",
    "shortId": "PORTAL-123",
    "title": "TypeError: Cannot read properties of undefined",
    "culprit": "StreamCard.tsx in renderAmount",
    "permalink": "https://sablier-labs.sentry.io/issues/12345/",
    "level": "error",
    "status": "unresolved",
    "isPublic": false,
    "platform": "javascript",
    "project": {
      "id": "67890",
      "name": "portal",
      "slug": "portal"
    },
    "type": "error",
    "metadata": {
      "value": "Cannot read properties of undefined (reading 'amount')",
      "type": "TypeError",
      "filename": "StreamCard.tsx",
      "function": "renderAmount"
    },
    "count": "45",
    "userCount": 12,
    "firstSeen": "2024-01-15T10:30:00Z",
    "lastSeen": "2024-01-20T14:22:00Z"
  }
]
```

### Bulk Update Issues

```
PUT /projects/{organization_slug}/{project_slug}/issues/
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | string | Issue IDs (can be repeated) |

**Body:**

```json
{
  "status": "resolved" | "unresolved" | "ignored",
  "statusDetails": {
    "inRelease": "latest",
    "ignoreCount": 100,
    "ignoreDuration": 60,
    "ignoreUserCount": 10,
    "ignoreUserWindow": 60
  }
}
```

## Issue Endpoints

### Get Issue Details

```
GET /issues/{issue_id}/
```

**Response includes:**
- Full issue metadata
- Statistics
- Tags
- Activity

### Update Issue

```
PUT /issues/{issue_id}/
```

**Body:**

```json
{
  "status": "resolved" | "unresolved" | "ignored",
  "assignedTo": "user:123" | "team:456",
  "hasSeen": true,
  "isBookmarked": false,
  "isSubscribed": true
}
```

### Delete Issue

```
DELETE /issues/{issue_id}/
```

### List Issue Events

```
GET /issues/{issue_id}/events/
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `full` | boolean | Include full event details |

### Get Latest Event

```
GET /issues/{issue_id}/events/latest/
```

**Response includes:**
- Full exception details
- Stack traces
- Breadcrumbs
- Context (browser, device, user)
- Tags

### Get Specific Event

```
GET /issues/{issue_id}/events/{event_id}/
```

## Event Data Structure

### Exception Object

```json
{
  "exception": {
    "values": [
      {
        "type": "TypeError",
        "value": "Cannot read properties of undefined (reading 'amount')",
        "stacktrace": {
          "frames": [
            {
              "filename": "StreamCard.tsx",
              "function": "renderAmount",
              "lineno": 78,
              "colno": 23,
              "absPath": "webpack://portal/./src/components/StreamCard.tsx",
              "module": "src/components/StreamCard",
              "inApp": true
            }
          ]
        }
      }
    ]
  }
}
```

### Contexts Object

```json
{
  "contexts": {
    "browser": {
      "name": "Chrome",
      "version": "120.0.0"
    },
    "os": {
      "name": "macOS",
      "version": "14.2"
    },
    "device": {
      "family": "Desktop"
    }
  }
}
```

### Tags Object

```json
{
  "tags": [
    {"key": "browser", "value": "Chrome 120.0"},
    {"key": "url", "value": "https://app.sablier.com/stream/1"},
    {"key": "environment", "value": "production"}
  ]
}
```

## Status Values

| Status | Description |
|--------|-------------|
| `unresolved` | Issue is active and needs attention |
| `resolved` | Issue has been fixed |
| `ignored` | Issue is archived/ignored |

## Status Details (for ignored)

```json
{
  "statusDetails": {
    "ignoreCount": 100,        // Ignore until N more events
    "ignoreDuration": 60,       // Ignore for N minutes
    "ignoreUserCount": 10,      // Ignore until N more users affected
    "ignoreUserWindow": 60,     // User count window in minutes
    "ignoreUntil": "2024-02-01" // Ignore until specific date
  }
}
```

## Pagination

Sentry uses cursor-based pagination. Check response headers:

```
Link: <https://sentry.io/api/0/.../?cursor=abc>; rel="next"; results="true"
```

Parse the `cursor` parameter and use it in subsequent requests.

## Rate Limits

Check response headers:

```
X-Sentry-Rate-Limit-Limit: 100
X-Sentry-Rate-Limit-Remaining: 95
X-Sentry-Rate-Limit-Reset: 1640000000
```

## Search Query Syntax

### Status Filters

| Query | Description |
|-------|-------------|
| `is:unresolved` | Unresolved issues |
| `is:resolved` | Resolved issues |
| `is:ignored` | Ignored/archived issues |
| `is:muted` | Muted issues |

### Time Filters

| Query | Description |
|-------|-------------|
| `firstSeen:-24h` | First seen in last 24 hours |
| `lastSeen:-7d` | Last seen in last 7 days |
| `age:-30d` | Created in last 30 days |

### Assignment Filters

| Query | Description |
|-------|-------------|
| `assigned:me` | Assigned to current user |
| `assigned:none` | Unassigned |
| `assigned:#team-name` | Assigned to team |

### Other Filters

| Query | Description |
|-------|-------------|
| `level:error` | Error level |
| `level:warning` | Warning level |
| `platform:javascript` | JavaScript platform |
| `browser:Chrome` | Chrome browser |
| `has:user` | Has user context |

### Combining Queries

```
is:unresolved level:error lastSeen:-24h
```

## Error Handling

### Common HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad request (invalid parameters) |
| 401 | Unauthorized (invalid/missing token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not found |
| 429 | Rate limited |

### Error Response Format

```json
{
  "detail": "Authentication credentials were not provided."
}
```
