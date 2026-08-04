# Go / no-go: unofficial Data Hub pull for SwimTracker

## Verdict

**Conditional GO for a personal-bests-only import.**  
**NO-GO for full meet-history sync** until athlete login (or another authorized path) is solved.

Anonymous `times-api` access is real and sufficient to import an athlete’s current SWIMS personal bests (with meet name, date, and often splits). It is **not** sufficient to rebuild a full season log the way Meet Mobile / a Hy-Tek file would.

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

### Ship next (if you want Data Hub at all)

1. **In-app “Import personal bests from Data Hub”** (unofficial)
   - User searches name / pastes `memberId`
   - Preview PB rows → merge into `SwimTime` + `Meet` (do **not** use backup replace)
   - Copy must say these are **bests only**, source is unofficial, and USA Swimming may break it
2. Keep a **paste/CSV** path for non-PB swims and for when the API changes

### Do not ship yet

- Branding as “SWIMS sync” or “official USA Swimming”
- Full-history sync via scraping / stolen session cookies without a clear athlete login UX
- Vendor API application solely for a personal tracker (wrong product fit)

### Later option: authenticated full history

If full history becomes the goal:

1. Use `ASWebAuthenticationSession` (or similar) against `dhy-prod.usaswimming.org`
2. Capture `Usas-Sub-Id` / `Usas-Session-Id` the SPA uses after `/bff/userinfo`
3. Call `GetAllTimesForFilters` + meet endpoints
4. Re-validate App Review / ToS risk before release

Flags that would flip full-history to GO: documented athlete OAuth that yields those headers, stable all-times JSON, and acceptance of unofficial-client maintenance.

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
