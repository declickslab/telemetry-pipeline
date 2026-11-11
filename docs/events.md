# Event schema

This pipeline processes telemetry from a small, fictional single-player game demo. The data is synthetic and produced by a seeded generator, so every run is reproducible.

The main analysis question is where players drop off between the first launch and the end credits.

## Envelope

Every event has the same envelope. Fields specific to an event type live in `payload`.

```json
{
  "event_id": "b6c1f0a2-3d4e-4b7a-9c1e-5f2a8d7e1b30",
  "event_type": "milestone_reached",
  "event_time": "2026-11-10T14:03:22Z",
  "received_at": "2026-11-10T14:03:25Z",
  "schema_version": 1,
  "player_id": "p_004812",
  "session_id": "s_9ac1f2",
  "platform": "pc",
  "app_version": "1.2.0",
  "payload": { "milestone": "cleared_level_2" }
}
```

| Field | Meaning |
|---|---|
| `event_id` | Unique id of the event. Used to detect duplicates. |
| `event_type` | One of the four types below. |
| `event_time` | When the event happened on the player's device (UTC). |
| `received_at` | When the server received it. A large gap from `event_time` means a late event. |
| `schema_version` | Version of the payload format. |
| `player_id` | Stable id of the player. |
| `session_id` | Id of the play session. Absent on `player_registered`. |
| `platform` | `pc` or `console`. |
| `app_version` | Game build that sent the event. |

## Event types

| Type | Payload | Feeds |
|---|---|---|
| `player_registered` | `country`, `acquisition_channel` | Retention cohorts, new players per day |
| `session_start` | `device_model` | Sessions, daily active users |
| `milestone_reached` | `milestone` | Progression funnel |
| `session_end` | `duration_s`, `reason` (`quit`, `crash`), `last_milestone` | Session length, drop-off point |

## Milestones

Milestones form an ordered funnel. A player cannot reach a milestone without reaching the ones before it.

| Order | `milestone` |
|---|---|
| 1 | `tutorial_completed` |
| 2 | `cleared_level_1` |
| 3 | `cleared_level_2` |
| 4 | `cleared_level_3` |
| 5 | `cleared_level_4` |
| 6 | `cleared_level_5` |
| 7 | `boss_defeated` |
| 8 | `credits_ended` |

Adding a milestone later needs no new event type, only a new value.

## Target funnel (generator defaults)

Share of registered players who reach each step. These are starting values for the simulation and can be tuned.

| Milestone | Share |
|---|---|
| `tutorial_completed` | 80 % |
| `cleared_level_1` | 68 % |
| `cleared_level_2` | 55 % |
| `cleared_level_3` | 45 % |
| `cleared_level_4` | 38 % |
| `cleared_level_5` | 30 % |
| `boss_defeated` | 18 % |
| `credits_ended` | 15 % |

## Deliberate data quality problems

The generator injects these on purpose, so the pipeline has real work to do. Rates are defaults.

| Problem | Rate | Detail |
|---|---|---|
| Duplicates | ~1 % | The same event is sent twice with the same `event_id`. |
| Late events | ~3 % | `received_at` arrives up to 3 days after `event_time`, like a player coming back online. |
| Missing fields | ~2 % of the events that carry them | `country` or `device_model` is absent. |
| Schema change | from `app_version` 1.3.0 | `schema_version` becomes 2, `milestone` is renamed `milestone_id`, and `duration_s` becomes `duration_ms`. Both forms must be handled. Only players who updated send the new form, so both coexist after the release. |

## Files

The generator writes one JSONL file per day of arrival (`received_at`), in `data/raw_events/`. A late event therefore lands in a later file than the day it happened, which is what a daily load sees in real life.
