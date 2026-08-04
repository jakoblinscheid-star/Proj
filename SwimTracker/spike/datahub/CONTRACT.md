# Data Hub `times-api` contract (spike capture)

Captured 2026-08-04 from the Data Hub SPA bundle (`index-BDY-hwIE.js`) and live anonymous calls against `https://times-api.usaswimming.org`.

Public UI entry: [Individual Times Search](https://data.usaswimming.org/datahub/usas/individualsearch) → redirects to `/search/athlete`.

## Auth headers (every request)

The SPA helper `be()` always sends:

| Header | Anonymous value | Logged-in value |
|--------|-----------------|-----------------|
| `AppName` | `DataHub` | `DataHub` |
| `Device-Id` | see below | same algorithm, persisted in `localStorage` |
| `Usas-Sub-Id` | `Anonymous` | IdP `sub` from `/bff/userinfo` |
| `Usas-Session-Id` | omitted | IdP `sid` when present |
| `Content-Type` | `application/json` | `application/json` |

### `Device-Id` format

```
raw = base64(`${platform} - ${vendor} - ${fingerprint|unknown} - ${Date.now()}`)
deviceId = raw.slice(0,15) + raw.slice(0,5) + raw.slice(15)
```

Fallback used by this spike (works):

```
base64("platform - vendor - unknown - <millis>")
```

then the same slice rearrange. Arbitrary strings / plain base64 **without** the rearrange return `400 Invalid Device-Id format`.

### Identity bootstrap

- `GET https://dhy-prod.usaswimming.org/bff/userinfo` (`credentials: include`) → IdP claims; on failure SPA uses Anonymous.
- `POST https://security-api.usaswimming.org/security/auth/GetDataHubSecurityInfoForIdp` body `{sub, sid}` → `appRoutes` permissions.

Anonymous security info observed:

```json
{
  "identityProviderId": "Anonymous",
  "appRoutes": [{"permissionType": "read", "routePath": "/"}]
}
```

## Response encoding quirk

Many `times-api` responses are **JSON strings containing JSON** (double-encoded). Clients must `json.loads` twice when the first parse yields a `str`.

## Endpoints exercised

### 1. Find athlete — works anonymously

`POST /swims/TimesSearch/GetMembersForFilters`

```json
{"name": "Smith", "isCurrent": 1, "lscCode": "AD", "orgCode": null}
```

Notes:

- `name` is a free-text search (last name works best; `"First Last"` often 404s when `isCurrent: 1`).
- `isCurrent: 1` = current season members; `0` includes historical.
- Defaults in SPA: `{name:"", isCurrent:1, lscCode:null, orgCode:null}`.

Sample member fields: `memberId`, `fullName`, `shortName`, `clubName`, `lscCode`, `swimmerAge`, `profilePicUrl`, `isNcaa`.

### 2. Member header — works anonymously

`GET /swims/TimesSearch/GetMember/{memberId}`

Same shape as a members-list row.

### 3. Best-times summary — works anonymously

`GET /swims/TimesSearch/GetBestTimesForMember/{memberId}`

Sample row:

```json
{
  "swimTimeRecognitionId": 225672313,
  "strokeName": "Freestyle",
  "strokeAbbreviation": "FR",
  "distance": 50,
  "courseCode": "SCY",
  "swimTime": "26.07"
}
```

One row per best event/course; **no meet or date**.

### 4. Best-times detail (chosen pull path) — works anonymously

`POST /swims/TimesSearch/BestTimes`

```json
{"memberId": "<id>", "distance": 100, "strokeAbbreviation": "FR"}
```

Returns the PB row(s) for that distance/stroke (typically one per course) **with meet + date + splits**:

```json
{
  "courseId": 1,
  "distance": 100,
  "strokeAbbreviation": "FR",
  "courseCode": "SCY",
  "meetName": "2026 AD Section 2 Div 2 Boys Championships",
  "eventCode": "100 FR SCY",
  "swimDate": "Feb 14, 2026",
  "fullName": "Owen Smith",
  "swimmerAge": 17,
  "lscCode": "AD",
  "clubName": "Unattached",
  "swimTime": "26.07",
  "timeDrop": null,
  "finishPosition": 8,
  "timeStandard": "B",
  "splits": [
    {"cumulativeDistance": 50.0, "cumulativeSplitTime": "33.04", "splitTime": "33.04"},
    {"cumulativeDistance": 100.0, "cumulativeSplitTime": "1:11.63", "splitTime": "38.59"}
  ]
}
```

**Important:** this is a **personal-best** surface, not full career history. Ledecky-sized athletes still return ~1 row per distance/stroke/course (dozens of PBs), not every swim.

### 5. Full history / meets — blocked for Anonymous

These returned **HTTP 403** with empty body under `Usas-Sub-Id: Anonymous`:

| Endpoint | Purpose |
|----------|---------|
| `POST /swims/TimesSearch/GetAllTimesForFilters` | All swims for filters |
| `GET /swims/TimesSearch/GetSwimmerMeets/{memberId}` | Meet list |
| `GET /swims/TimesSearch/GetSwimmerMeetTimes/{memberId}/{meetId}` | Times in a meet |
| `GET /swims/SearchFilter/GetSwimmerEvents/{id}` | Event filter options |
| `GET /swims/SearchFilter/GetSwimmerSeasons/{id}` | Season filter options |
| `GET /swims/TimesSearch/GetSwimmerCourses/{id}` | Course filter options |
| `GET /swims/TimesSearch/SwimmerMeets/SwimTime/{id}` | Meet swim detail |

`GetAllTimesForFilters` SPA payload shape (for a future authenticated client):

```json
{
  "memberId": "<id>",
  "events": null,
  "course": null,
  "seasonKey": null,
  "startDate": null,
  "endDate": null,
  "minAge": null,
  "maxAge": null,
  "timeStandardType": null,
  "sortBy": null
}
```

(When the UI has selected events/standards it joins ids into comma-separated strings instead of arrays.)

## SwimTracker mapping (PB pull path)

| API field | SwimTracker |
|-----------|-------------|
| `distance` | `SwimTime.distance` |
| `strokeAbbreviation` `FR/BK/BR/FL/IM` | `Stroke` `Free/Back/Breast/Fly/IM` |
| `courseCode` `SCY/SCM/LCM` | `Course` (same raw values) |
| `swimTime` (`26.07`, `1:11.63`, `14:59.62`) | `seconds` via `MM:SS.hh` / `SS.hh` parse |
| `swimDate` (`Feb 14, 2026`) | `date` |
| `meetName` | `Meet.name` (group by name+date; course from row) |
| `splits[].splitTime` at 50-interval `cumulativeDistance` | `splits: [Double]` (50-yard/meter splits only; skip 25m SCM mid-splits) |
| — | `round` not present → omit |
| — | `isRelay` → always `false` for this path |

Out of scope unless authenticated all-times lands: prelim/final, non-PB swims, relay legs.

## Sample files

Under `samples/`:

- `GetMember.json`, `GetBestTimesForMember.json`, `BestTimes_history.json`
- `pull_example.json` — full anonymous PB pull for one public athlete
