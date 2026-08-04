# Go / no-go: unofficial Data Hub pull for SwimTracker

## Context

Personal-only tool — not marketed or distributed to other people. That removes App Store / “official integration” product risk from the decision; remaining risk is API breakage and whatever USA Swimming ToS means for your own use.

## Verdict

**GO for personal-bests import now** (anonymous `times-api` path).  
**GO later for full meet history** if you want it — implement athlete login to unlock `GetAllTimesForFilters` / meet endpoints. Worth it for a private app; still brittle when Data Hub redeploys.

Anonymous access is enough to seed PBs (meet name, date, often splits). Full season history still needs IdP session headers (`Usas-Sub-Id` / `Usas-Session-Id`).

## Evidence

| Capability | Anonymous (`Usas-Sub-Id: Anonymous`) | Notes |
|------------|--------------------------------------|-------|
| Search athletes | Yes | `GetMembersForFilters` |
| Member profile | Yes | `GetMember/{id}` |
| Personal bests + meet/date/splits | Yes | `GetBestTimesForMember` + `BestTimes` |
| All times / meet list | **No (HTTP 403)** | `GetAllTimesForFilters`, `GetSwimmerMeets`, … |
| Official public API / ToS blessing | No | SPA reverse-engineered; can break on deploy |

Spike script: [`pull_times.py`](pull_times.py)  
Contract notes: [`CONTRACT.md`](CONTRACT.md)

## Recommendation

### Build next

1. **In-app “Import personal bests from Data Hub”**
   - Search name / paste `memberId`
   - Preview PB rows → merge into `SwimTime` + `Meet` (not backup replace)
   - Label as bests-only; expect occasional breakage when USA Swimming ships SPA/API changes
2. Optional: paste/CSV as a backup when the API is down or you need non-PB swims

### Optional follow-on (personal use makes this reasonable)

**Authenticated full history:**

1. Log in via `ASWebAuthenticationSession` (or cookie capture) against `dhy-prod.usaswimming.org`
2. Reuse SPA headers: `Usas-Sub-Id` / `Usas-Session-Id` from `/bff/userinfo`
3. Call `GetAllTimesForFilters` + meet endpoints
4. No vendor API application needed for a private tool

Skip public branding concerns; just keep the client easy to fix when endpoints move.

## Why not stop at paste/CSV only?

Paste/CSV is still the durable fallback. The anonymous PB pull is worth it because:

- Zero coach/export dependency for an athlete account
- Structured fields map cleanly to [`SwimTime` / `Meet`](../../SwimTracker/Models.swift)
- Useful cold-start (“seed my PBs”) even if season history stays manual

## App integration sketch (follow-on, not this spike)

```
Settings → Import from Data Hub
  → search / memberId
  → preview mapped times
  → store.mergeImported(meets, times)   // new API; not importBackup
```

Mapper logic can lift directly from `pull_times.py` (`parse_swim_time`, stroke map, 50-interval splits).
