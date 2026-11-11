"""Generate synthetic game telemetry as JSONL files, one file per day of arrival.

The output is reproducible: the same seed always gives the same files.
See docs/events.md for the schema and the deliberate data quality problems.
"""

import argparse
import json
import random
import uuid
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

MILESTONES = [
    "tutorial_completed",
    "cleared_level_1",
    "cleared_level_2",
    "cleared_level_3",
    "cleared_level_4",
    "cleared_level_5",
    "boss_defeated",
    "credits_ended",
]

# Share of registered players who reach each milestone (see docs/events.md).
FUNNEL = [0.80, 0.68, 0.55, 0.45, 0.38, 0.30, 0.18, 0.15]

# Chance that a player plays on day d (d >= 1): D1 = 40 %, D7 = about 20 %.
RETURN_D1 = 0.40
RETURN_DECAY = 0.891

# Deliberate dirt.
DUPLICATE_RATE = 0.01
LATE_RATE = 0.03
MISSING_RATE = 0.02
UPGRADE_SHARE = 0.70  # share of players who install version 1.3.0 once released
CRASH_RATE = 0.03

COUNTRIES = ["FR", "US", "DE", "GB", "BR", "JP", "ES", "CA"]
CHANNELS = ["organic", "store_feature", "social", "friend_referral"]
DEVICES = {
    "pc": ["desktop_low", "desktop_mid", "desktop_high", "laptop"],
    "console": ["console_a", "console_b", "handheld"],
}


def iso(moment: datetime) -> str:
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def draw_target(rng: random.Random) -> int:
    """How many milestones this player will ever reach."""
    u = rng.random()
    return sum(1 for share in FUNNEL if u < share)


def build_events(rng, event_type, event_time, player, session_id, payload, release):
    """Build one event, plus an optional duplicate. Applies the dirt rules."""
    new_format = player["upgrades"] and event_time >= release
    payload = dict(payload)

    # Schema change from version 1.3.0: renamed field and a unit change.
    if new_format:
        if "milestone" in payload:
            payload["milestone_id"] = payload.pop("milestone")
        if "duration_s" in payload:
            payload["duration_ms"] = payload.pop("duration_s") * 1000

    # Missing fields.
    for key in ("country", "device_model"):
        if key in payload and rng.random() < MISSING_RATE:
            del payload[key]

    # Late events arrive hours or days after they happened.
    if rng.random() < LATE_RATE:
        delay = rng.uniform(3600, 3 * 86400)
    else:
        delay = rng.uniform(1, 30)
    received = event_time + timedelta(seconds=delay)

    event = {
        "event_id": str(uuid.UUID(int=rng.getrandbits(128), version=4)),
        "event_type": event_type,
        "event_time": iso(event_time),
        "received_at": iso(received),
        "schema_version": 2 if new_format else 1,
        "player_id": player["id"],
    }
    if session_id:
        event["session_id"] = session_id
    event["platform"] = player["platform"]
    event["app_version"] = "1.3.0" if new_format else "1.2.0"
    event["payload"] = payload

    events = [event]
    if rng.random() < DUPLICATE_RATE:
        copy = dict(event)
        copy["received_at"] = iso(received + timedelta(seconds=rng.uniform(60, 3600)))
        events.append(copy)
    return events


def simulate_player(rng, number, start, days, release):
    end = start + timedelta(days=days)
    registered = start + timedelta(
        days=rng.randrange(days), seconds=rng.uniform(0, 86399)
    )
    player = {
        "id": f"p_{number:06d}",
        "platform": "pc" if rng.random() < 0.85 else "console",
        "target": draw_target(rng),
        "upgrades": rng.random() < UPGRADE_SHARE,
    }
    events = build_events(
        rng, "player_registered", registered, player, None,
        {"country": rng.choice(COUNTRIES), "acquisition_channel": rng.choice(CHANNELS)},
        release,
    )

    reached = 0
    first_day = registered.replace(hour=0, minute=0, second=0, microsecond=0)
    day = 0
    while True:
        if day == 0:
            begin = registered + timedelta(seconds=rng.uniform(60, 600))
        else:
            begin = first_day + timedelta(days=day, seconds=rng.uniform(8 * 3600, 23 * 3600))
        if begin >= end:
            break
        plays = day == 0 or rng.random() < RETURN_D1 * RETURN_DECAY ** (day - 1)
        if plays:
            reached = simulate_session(rng, player, begin, reached, release, events)
        day += 1
    return events


def simulate_session(rng, player, begin, reached, release, events):
    session_id = f"s_{rng.getrandbits(48):012x}"
    remaining = player["target"] - reached
    new_milestones = min(remaining, rng.choice([1, 1, 2, 3])) if remaining > 0 else 0
    duration = int(rng.uniform(120, 600) + 480 * new_milestones)

    events += build_events(
        rng, "session_start", begin, player, session_id,
        {"device_model": rng.choice(DEVICES[player["platform"]])}, release,
    )
    offsets = sorted(rng.uniform(0.2, 0.95) for _ in range(new_milestones))
    for offset in offsets:
        events += build_events(
            rng, "milestone_reached", begin + timedelta(seconds=duration * offset),
            player, session_id, {"milestone": MILESTONES[reached]}, release,
        )
        reached += 1
    events += build_events(
        rng, "session_end", begin + timedelta(seconds=duration), player, session_id,
        {
            "duration_s": duration,
            "reason": "crash" if rng.random() < CRASH_RATE else "quit",
            "last_milestone": MILESTONES[reached - 1] if reached > 0 else None,
        },
        release,
    )
    return reached


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--players", type=int, default=100_000)
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--start", default="2026-10-01")
    parser.add_argument("--out", default="data/raw_events")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    start = datetime.fromisoformat(args.start).replace(tzinfo=timezone.utc)
    release = start + timedelta(days=args.days // 2)  # version 1.3.0 ships mid-window

    by_arrival_day = defaultdict(list)
    for number in range(args.players):
        for event in simulate_player(rng, number, start, args.days, release):
            by_arrival_day[event["received_at"][:10]].append(event)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("events_*.jsonl"):
        old.unlink()

    total = 0
    for day, events in sorted(by_arrival_day.items()):
        events.sort(key=lambda e: e["received_at"])
        with open(out / f"events_{day}.jsonl", "w", encoding="utf-8") as f:
            for event in events:
                f.write(json.dumps(event, separators=(",", ":")) + "\n")
        total += len(events)
    print(f"{total} events written to {out}/ in {len(by_arrival_day)} files (seed {args.seed})")


if __name__ == "__main__":
    main()
