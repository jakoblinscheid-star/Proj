#!/usr/bin/env python3
"""Spike: pull USA Swimming Data Hub personal bests into SwimTracker-shaped structs.

Anonymous path (no athlete login):
  1) POST GetMembersForFilters  → memberId
  2) GET  GetBestTimesForMember → PB event keys
  3) POST BestTimes per (distance, stroke) → rows with meet/date/splits

Usage:
  python3 pull_times.py --name Smith --lsc AD
  python3 pull_times.py --member-id 7F23E4EC26C844
  python3 pull_times.py --name Ledecky --include-historical --json out.json

This is research code. The API is unofficial and may change without notice.
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Any, Optional

TIMES_API = "https://times-api.usaswimming.org"
STROKE_MAP = {
    "FR": "Free",
    "BK": "Back",
    "BR": "Breast",
    "FL": "Fly",
    "IM": "IM",
}


@dataclass
class SwimTrackerMeet:
    name: str
    date: str  # ISO date
    course: str
    team: str = ""
    location: str = ""


@dataclass
class SwimTrackerTime:
    distance: int
    stroke: str
    course: str
    seconds: float
    date: str  # ISO date
    meet_name: str
    splits: list[float] = field(default_factory=list)
    note: str = ""
    is_relay: bool = False
    event_code: str = ""
    source: str = "datahub-best-times"


@dataclass
class PullResult:
    member_id: str
    full_name: str
    club_name: str
    lsc_code: str
    meets: list[SwimTrackerMeet]
    times: list[SwimTrackerTime]
    raw_history_count: int
    warnings: list[str] = field(default_factory=list)


def make_device_id() -> str:
    """Match Data Hub SPA Device-Id rearrange (see CONTRACT.md)."""
    raw = f"platform - vendor - unknown - {int(time.time() * 1000)}"
    n = base64.b64encode(raw.encode()).decode()
    return n[:15] + n[:5] + n[15:]


def decode_body(raw: str) -> Any:
    if not raw:
        return None
    data = json.loads(raw)
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except json.JSONDecodeError:
            pass
    return data


class DataHubClient:
    def __init__(self, sub_id: str = "Anonymous", session_id: Optional[str] = None):
        self.device_id = make_device_id()
        self.sub_id = sub_id
        self.session_id = session_id

    def _headers(self) -> dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "AppName": "DataHub",
            "Usas-Sub-Id": self.sub_id,
            "Device-Id": self.device_id,
            "Origin": "https://data.usaswimming.org",
            "User-Agent": "SwimTrackerDataHubSpike/0.1",
        }
        if self.session_id:
            headers["Usas-Session-Id"] = self.session_id
        return headers

    def request(self, method: str, path: str, body: Optional[dict] = None) -> Any:
        url = path if path.startswith("http") else TIMES_API + path
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(url, data=data, headers=self._headers(), method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return decode_body(resp.read().decode())
        except urllib.error.HTTPError as e:
            raw = e.read().decode()
            detail = raw[:300] if raw else "(empty body)"
            raise RuntimeError(f"{method} {path} → HTTP {e.code}: {detail}") from e

    def search_members(
        self,
        name: str,
        *,
        is_current: int = 1,
        lsc_code: Optional[str] = None,
    ) -> list[dict]:
        result = self.request(
            "POST",
            "/swims/TimesSearch/GetMembersForFilters",
            {
                "name": name,
                "isCurrent": is_current,
                "lscCode": lsc_code,
                "orgCode": None,
            },
        )
        if not isinstance(result, list):
            raise RuntimeError(f"Unexpected members payload: {type(result).__name__}")
        return result

    def get_member(self, member_id: str) -> dict:
        result = self.request("GET", f"/swims/TimesSearch/GetMember/{member_id}")
        if not isinstance(result, dict):
            raise RuntimeError("Unexpected GetMember payload")
        return result

    def get_best_times_summary(self, member_id: str) -> list[dict]:
        result = self.request(
            "GET", f"/swims/TimesSearch/GetBestTimesForMember/{member_id}"
        )
        if not isinstance(result, list):
            raise RuntimeError("Unexpected best-times summary payload")
        return result

    def get_best_times_detail(
        self, member_id: str, distance: int, stroke_abbreviation: str
    ) -> list[dict]:
        result = self.request(
            "POST",
            "/swims/TimesSearch/BestTimes",
            {
                "memberId": member_id,
                "distance": distance,
                "strokeAbbreviation": stroke_abbreviation,
            },
        )
        if result is None:
            return []
        if not isinstance(result, list):
            raise RuntimeError(f"Unexpected BestTimes payload: {result!r}")
        return result

    def try_all_times(self, member_id: str) -> tuple[bool, Any]:
        """Probe authenticated-only endpoint; useful when session headers are supplied."""
        try:
            data = self.request(
                "POST",
                "/swims/TimesSearch/GetAllTimesForFilters",
                {
                    "memberId": member_id,
                    "events": None,
                    "course": None,
                    "seasonKey": None,
                    "startDate": None,
                    "endDate": None,
                    "minAge": None,
                    "maxAge": None,
                    "timeStandardType": None,
                    "sortBy": None,
                },
            )
            return True, data
        except RuntimeError as e:
            return False, str(e)


def parse_swim_time(text: str) -> float:
    """Parse Data Hub swimTime strings like '26.07', '1:11.63', '14:59.62'."""
    text = text.strip()
    if not text:
        raise ValueError("empty swimTime")
    parts = text.split(":")
    if len(parts) == 1:
        return round(float(parts[0]), 2)
    if len(parts) == 2:
        minutes, seconds = parts
        return round(int(minutes) * 60 + float(seconds), 2)
    if len(parts) == 3:
        hours, minutes, seconds = parts
        return round(int(hours) * 3600 + int(minutes) * 60 + float(seconds), 2)
    raise ValueError(f"unrecognized swimTime: {text!r}")


def parse_swim_date(text: str) -> str:
    """Parse 'Feb 14, 2026' → ISO date."""
    return datetime.strptime(text.strip(), "%b %d, %Y").date().isoformat()


def map_stroke(abbr: str) -> str:
    try:
        return STROKE_MAP[abbr.upper()]
    except KeyError as e:
        raise ValueError(f"unknown strokeAbbreviation: {abbr!r}") from e


def map_splits(distance: int, splits: Optional[list[dict]]) -> list[float]:
    """Keep 50-interval split times matching SwimTracker SwimSplits expectations."""
    if not splits:
        return []
    interval = 50
    expected = distance // interval
    if expected <= 0 or distance % interval != 0:
        return []
    by_cum = {
        int(s["cumulativeDistance"]): parse_swim_time(s["splitTime"])
        for s in splits
        if s.get("cumulativeDistance") is not None and s.get("splitTime")
    }
    # Prefer exact 50/100/... marks; ignore 25m SCM mid-splits.
    values = []
    for i in range(1, expected + 1):
        mark = i * interval
        if mark not in by_cum:
            return []
        values.append(by_cum[mark])
    return values


def rows_to_swimtracker(member: dict, history: list[dict]) -> PullResult:
    warnings: list[str] = []
    times: list[SwimTrackerTime] = []
    meets_by_key: dict[tuple[str, str, str], SwimTrackerMeet] = {}

    for row in history:
        try:
            stroke = map_stroke(row["strokeAbbreviation"])
            course = row["courseCode"]
            if course not in {"SCY", "SCM", "LCM"}:
                warnings.append(f"skip unknown course {course!r}")
                continue
            seconds = parse_swim_time(row["swimTime"])
            date_iso = parse_swim_date(row["swimDate"])
            meet_name = (row.get("meetName") or "Unknown meet").strip()
            splits = map_splits(int(row["distance"]), row.get("splits"))
            if row.get("splits") and not splits:
                warnings.append(
                    f"splits omitted for {row.get('eventCode')} (non-50 interval)"
                )
        except (KeyError, ValueError, TypeError) as e:
            warnings.append(f"skip row: {e}")
            continue

        key = (meet_name, date_iso, course)
        if key not in meets_by_key:
            meets_by_key[key] = SwimTrackerMeet(
                name=meet_name,
                date=date_iso,
                course=course,
                team=row.get("clubName") or "",
            )

        times.append(
            SwimTrackerTime(
                distance=int(row["distance"]),
                stroke=stroke,
                course=course,
                seconds=seconds,
                date=date_iso,
                meet_name=meet_name,
                splits=splits,
                event_code=row.get("eventCode") or "",
            )
        )

    return PullResult(
        member_id=member["memberId"],
        full_name=member.get("fullName") or "",
        club_name=member.get("clubName") or "",
        lsc_code=member.get("lscCode") or "",
        meets=list(meets_by_key.values()),
        times=times,
        raw_history_count=len(history),
        warnings=warnings,
    )


def pull_personal_bests(
    client: DataHubClient,
    *,
    member_id: Optional[str] = None,
    name: Optional[str] = None,
    lsc_code: Optional[str] = None,
    is_current: int = 1,
    pick: int = 0,
) -> PullResult:
    if member_id:
        member = client.get_member(member_id)
    else:
        if not name:
            raise SystemExit("Provide --name or --member-id")
        members = client.search_members(name, is_current=is_current, lsc_code=lsc_code)
        if not members:
            raise SystemExit(f"No members found for name={name!r}")
        if pick >= len(members):
            raise SystemExit(f"--pick {pick} out of range ({len(members)} matches)")
        if len(members) > 1:
            print(f"Found {len(members)} matches; using index {pick}:", file=sys.stderr)
            for i, m in enumerate(members[:15]):
                marker = "->" if i == pick else "  "
                print(
                    f"{marker} [{i}] {m.get('fullName')} | {m.get('clubName')} | "
                    f"{m.get('lscCode')} | age {m.get('swimmerAge')} | {m.get('memberId')}",
                    file=sys.stderr,
                )
        member = members[pick]
        member_id = member["memberId"]

    summary = client.get_best_times_summary(member_id)
    pairs = sorted({(int(r["distance"]), r["strokeAbbreviation"]) for r in summary})
    history: list[dict] = []
    for distance, stroke in pairs:
        history.extend(client.get_best_times_detail(member_id, distance, stroke))

    ok, all_times = client.try_all_times(member_id)
    result = rows_to_swimtracker(member, history)
    if ok:
        result.warnings.append(
            f"GetAllTimesForFilters unexpectedly allowed ({type(all_times).__name__}); "
            "prefer that path for full history in a future authenticated client."
        )
    else:
        result.warnings.append(
            "GetAllTimesForFilters blocked (expected for Anonymous). "
            "Imported rows are personal bests only, not full meet history."
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", help="Athlete name search (last name works best)")
    parser.add_argument("--member-id", help="Data Hub memberId if already known")
    parser.add_argument("--lsc", dest="lsc_code", help="Optional LSC code filter, e.g. AD")
    parser.add_argument(
        "--include-historical",
        action="store_true",
        help="Search with isCurrent=0 (includes non-current members)",
    )
    parser.add_argument("--pick", type=int, default=0, help="Index into search results")
    parser.add_argument("--json", help="Write full PullResult JSON to this path")
    parser.add_argument(
        "--usas-sub-id",
        default="Anonymous",
        help="Optional Usas-Sub-Id from a logged-in Data Hub session",
    )
    parser.add_argument(
        "--usas-session-id",
        default=None,
        help="Optional Usas-Session-Id from a logged-in Data Hub session",
    )
    args = parser.parse_args()

    client = DataHubClient(sub_id=args.usas_sub_id, session_id=args.usas_session_id)
    result = pull_personal_bests(
        client,
        member_id=args.member_id,
        name=args.name,
        lsc_code=args.lsc_code,
        is_current=0 if args.include_historical else 1,
        pick=args.pick,
    )

    print(f"{result.full_name} ({result.member_id}) — {result.club_name} / {result.lsc_code}")
    print(f"meets: {len(result.meets)}  times: {len(result.times)}  raw rows: {result.raw_history_count}")
    for t in result.times:
        split_note = f" splits={len(t.splits)}" if t.splits else ""
        print(
            f"  {t.date}  {t.distance} {t.stroke} {t.course}  "
            f"{t.seconds:.2f}s  @ {t.meet_name}{split_note}"
        )
    if result.warnings:
        print("\nwarnings:", file=sys.stderr)
        for w in result.warnings:
            print(f"  - {w}", file=sys.stderr)

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(asdict(result), f, indent=2)
            f.write("\n")
        print(f"\nWrote {args.json}", file=sys.stderr)


if __name__ == "__main__":
    main()
