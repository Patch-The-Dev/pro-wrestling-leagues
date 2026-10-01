# Pro Wrestling Leagues

[![Source checks](https://github.com/Patch-The-Dev/pro-wrestling-leagues/actions/workflows/ci.yml/badge.svg)](https://github.com/Patch-The-Dev/pro-wrestling-leagues/actions/workflows/ci.yml)

**A Roblox wrestling game by PatchTheDev.** This repository contains its Luau systems, organized with Rojo for development and code review.

[Play Pro Wrestling Leagues on Roblox](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) · [View the project and gameplay footage](https://www.patchthedev.com/work/pro-wrestling-leagues) · [PatchTheDev portfolio](https://www.patchthedev.com)

Pro Wrestling Leagues is a full-stack, solo-developed wrestling game with multiplayer matches, combat, reversals, entrances, progression, and wrestler customization. The live game and footage show the player experience. The code here shows how the gameplay rules, network boundaries, persistent data, and client presentation are organized.

## What to review

| Area | Implementation | What it demonstrates |
| --- | --- | --- |
| Combat | [`CombatService`](src/server/Services/CombatService.luau), [`CombatCoordinator`](src/server/Application/CombatCoordinator.luau), [`StrikeResolver`](src/server/Application/StrikeResolver.luau) | Validated player intent, server-selected targets, action costs, strikes, and weapon damage |
| Grapples and pins | [`GrappleCoordinator`](src/server/Domain/Combat/GrappleCoordinator.luau), [`PinCoordinator`](src/server/Domain/Combat/PinCoordinator.luau), [`PinPromptView`](src/client/UI/PinPromptView.luau) | Timed reversals, visible pin timing, directional moves, and state transitions |
| Matches | [`MatchCoordinator`](src/server/Application/MatchCoordinator.luau), [`MatchPlacement`](src/server/Domain/Match/MatchPlacement.luau), [`MatchSession`](src/server/Domain/Match/MatchSession.luau) | Two-player queueing, arena reservation, character return, results, disconnects, and cleanup |
| Player data | [`PlayerRepository`](src/server/Persistence/PlayerRepository.luau), [`ProfileMigrations`](src/server/Persistence/ProfileMigrations.luau) | A single persistence boundary with schema migration and Studio mock storage |
| Economy | [`EconomyService`](src/server/Services/EconomyService.luau), [`MatchSettlementJournal`](src/server/Persistence/MatchSettlementJournal.luau) | Server-owned match rewards, cross-server opponent limits, prices, balances, and unlocks |
| Presentation | [`src/client`](https://github.com/Patch-The-Dev/pro-wrestling-leagues/tree/main/src/client), [`EntranceService`](src/server/Services/EntranceService.luau) | Inputs, HUD, animation, cameras, audio, lighting, and entrances kept apart from authoritative rules |

Start with the [review guide](docs/REVIEW_GUIDE.md) for a short reading order, or read the [architecture notes](docs/ARCHITECTURE.md) for the dependency and ownership rules.

## Gameplay systems in this code

The match flow pairs two eligible players, reserves an arena, records both characters' starting positions, places them at ring spawns, runs both entrances, then starts an active session. Placement validates both characters before moving either one and rolls back a partial placement. Startup rolls back the reservation, player mappings, and placement if a notification or entrance dependency fails. The countdown is derived from the entrance timing and checks that both original characters are alive and loaded before activation. A session records pin, knockout, forfeit, or vote results. After the match or a cancelled start, each original character still owned by its player returns to its recorded position before the arena is released. A respawned character is never moved by an old session. Queued players are retried when an occupied arena is released or a new arena is registered.

Combat includes a three-hit strike chain, running attacks, directional grapples, finishers, reversals, pins, stamina, health, poise, and finisher charge. `Combatant` owns the state of each fighter. `CombatMovement` locks walking and jumping during incapacitating and committed move states, temporarily requests server network ownership of the character root where the engine permits it, and restores movement on recovery. Damage can interrupt taunts, turnbuckle actions, grapples, pins, and standing up; a poise break is consumed only when the knockdown transition succeeds. `ActionBudget` checks cooldowns and resources. Strike animations start when the server accepts an action; the server checks range, facing, line of sight, and match state again at the move's configured impact time before applying damage. Grapples recheck the original target after the reversal window and cancel if the match, movement, distance, facing, or line of sight is no longer valid. Timed interactions and delayed recovery are owned by the corresponding session or scheduler so old work cannot change a later combat state. Pin input uses a visible client timing bar and a capped allowance derived from server-measured round-trip latency.

The server also manages arena weapons and turnbuckle interactions. Weapon instances are tracked by identity and arena, with ownership, cooldown, and durability checks. Pickup and drop requests require a plausible current character position; pickup also checks the active match, arena, availability, and range. Default touch pickup and backpack dropping are disabled for registered weapons so those paths cannot bypass service validation. Reset returns each weapon to its recorded arena parent and spawn position. CollectionService tags bind world behavior without copying a handler script into every asset.

The client reuses animation tracks for repeated actions on the same Animator and releases them when that character is removed.

### Durable match rewards

Eligible matches pay Cash, Tickets, experience, fame, and win/loss records after at least 30 seconds of active play. Match completion and combat cleanup run immediately; storage work follows separately.

1. **Persist the result.** A result record contains the match ID, participants, finish time, and fixed reward amounts. The coordinator retries until this handoff succeeds. Requeue and departure wait for that handoff within the configured shutdown budget.
2. **Claim the pair sequence.** One atomic DataStore update checks the 10-minute opponent cooldown and records the next sequence together with both unpaid participants. Another match cannot replace an unfinished pair settlement.
3. **Apply and confirm each payout.** The profile repository changes balances once per opponent sequence, requests a ProfileStore save, and waits for saved data containing that sequence. Each side has its own acknowledgement.
4. **Recover unfinished work.** A bounded background scan resumes pending records when either participant has a loaded profile. A player who was offline receives the outstanding payout after returning. A replacement server uses the same durable records.
5. **Retire completed results.** The result record is removed only after both profile saves are confirmed. The pair sequence and each profile's opponent watermark remain, so pruning the 64 recent match IDs cannot make an old result payable again.

An unavailable store leaves the result pending. A save timeout, failed acknowledgement, or restart does not silently turn a partial payout into a completed settlement. Studio uses mock profile and settlement stores. [Settlement protocol and operations](docs/SETTLEMENTS.md) explains retry ordering, recovery, and storage limits.

The shop checks prices and ownership on the server. Saved move loadouts require owned unlocks; unowned moves fall back to their default slots. Controllers render results without writing authoritative player data.

The server records match outcomes, reasons, and duration for connected participants through Roblox analytics in the live experience. Reward update failures are logged separately so missing profile updates are visible during operation.

## Trust boundary

```text
Player input
    ↓
Knit client method → request throttle → runtime contract
    ↓
Server service → application coordinator → domain rules
    ↓
Authoritative state / persistence → replicated events and presentation
```

Clients send bounded requests such as an action name, grapple direction, pin input, purchase, or loadout change. They do not choose a damage amount, report a successful hit, award currency, or submit a match result. [`Contracts.luau`](src/shared/Network/Contracts.luau) validates network values at runtime, and [`RequestGateService`](src/server/Services/RequestGateService.luau) applies per-player throttling. Character attributes mirror selected state for presentation; combat rules read the server-owned `Combatant` instead. Because Roblox character movement can be client owned, [`MovementHistory`](src/server/Domain/Combat/MovementHistory.luau) checks horizontal and vertical travel between samples and over a rolling window. Match placement seeds the first trusted position. An implausible move is rejected and the character is returned to its last valid position; waiting at the destination does not make it valid. Combat and weapon requests also check the current position. These limits are a plausibility check and should be tuned against live movement and network conditions.

## Controls

Keyboard and mouse, gamepad, and touch feed the same client action signals. Gamepad bindings cover strikes, grapples, reversals, pins, running attacks, turnbuckle actions, taunts, and dashes. Touch provides buttons for strike, grapple, finisher, counter, pin, and dash. Directional grapples use movement direction; neutral grapple defaults to forward. Finisher has its own binding: `G` on keyboard, left stick press on gamepad, and a touch button. All three input paths request actions through the same validated server methods.

## Repository layout

```text
src/
├── shared/              Config, types, network contracts, state helpers
├── server/
│   ├── Services/         Knit transport and lifecycle boundaries
│   ├── Application/      Combat and match use cases
│   ├── Domain/           Stateful combat, match, and reward rules
│   ├── Persistence/      ProfileStore repository, schema, migrations
│   ├── Components/       Tagged arenas and weapons
│   ├── Adapters/         Roblox character and customization changes
│   └── Networking/       Request throttling
└── client/
    ├── Controllers/      Input, HUD, match, data, and shop flows
    ├── Systems/          Animation, camera, audio, lighting, pyro
    └── UI/               Interface lookup and pin timing prompt
```

Knit handles service and controller lifecycle. Gameplay rules sit outside the framework-facing methods. Wally manages Knit, Promise, Trove, Signal, and ProfileStore; Rokit pins the development tools. Rojo maps the filesystem into the Roblox DataModel. The [runtime asset contract](docs/RUNTIME_ASSETS.md) documents the tags, attributes, and presentation assets that connect this code to a Studio place.

## Working with the project

Install [Rokit](https://github.com/rojo-rbx/rokit), then run the pinned tools from the repository root:

```sh
rokit install
wally install
rojo serve
```

Connect Roblox Studio to the Rojo server to sync the source tree. For an XML place build, run:

```sh
rojo build default.project.json -o ProWrestlingLeagues.rbxlx
```

### Verification

The [source checks workflow](.github/workflows/ci.yml) verifies the package lock, formatting, lint, **all runtime Luau source**, and the game, unit, and multiplayer Rojo builds. Application coordinators and every service are included in analysis. Roblox definitions and Actions are pinned to checked versions.

On Windows with Roblox Studio installed and signed in:

```powershell
./tests/RunStudioTests.ps1 -ReportPath "$env:TEMP/wrestling-runtime.json"
# Select a suite when investigating a failure:
./tests/RunStudioTests.ps1 -Suite Unit
./tests/RunStudioTests.ps1 -Suite Bootstrap
./tests/RunStudioTests.ps1 -Suite Integration
```

| Suite | What it exercises |
| --- | --- |
| Unit | Combat states, delayed impact, reversals, pins, movement bounds, weapon ownership, arena replacement, startup rollback, profile cleanup, shutdown, durable settlement recovery, partial payouts, lost acknowledgements, paginated recovery, and permanent replay protection. |
| Bootstrap | All server services initialize together with the pinned dependencies. |
| Multiplayer | Two actual Studio clients run the production server and client entrypoints. The test verifies controller startup, loads profiles, rejects a malformed combat request, queues both players, starts a real match, waits through the real reward-duration gate, finishes it, and confirms both saved payouts, duplicate-safe replay, and replicated match completion in both client controllers. Unhandled application errors fail the suite on both clients and the server. |

The tests use isolated fixtures and mock data stores. They do not publish a place or change live player data. The production project excludes test scripts and TestEZ. Each runtime report records the commit, whether the working tree was dirty, completion time, suite totals, and pass/fail status. Missing results, skipped tests, and timeouts fail the command.

The [Studio runtime workflow](.github/workflows/studio.yml) runs these same suites after successful source checks on trusted `main` pushes, once a dedicated Windows runner is enabled. It does not execute pull requests or forks on the signed-in machine. [Studio CI setup](docs/STUDIO_CI.md) covers installation and the opt-in repository variable. A skipped workflow is not a runtime pass.

The source tree is the reviewable application layer; the [live Roblox game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) is the playable project. Studio-authored arenas, UI, animation, sound, and cosmetic assets connect through the documented runtime contract.

## Further reading

- [Settlement protocol](docs/SETTLEMENTS.md): confirmed payouts, replay protection, and recovery.
- [Studio CI](docs/STUDIO_CI.md): runtime automation and reports.
- [Architecture](docs/ARCHITECTURE.md): module boundaries, state ownership, and cleanup.
- [Review guide](docs/REVIEW_GUIDE.md): suggested reading order and invariants to check.
- [Runtime assets](docs/RUNTIME_ASSETS.md): arena, weapon, animation, and entrance contracts.
- [Engineering notes](docs/ENGINEERING_NOTES.md): source organization and design decisions.

**Note:** I built Pro Wrestling Leagues as PatchTheDev. [Roblox records the game's creation in April 2025](https://games.roblox.com/v1/games?universeIds=7587071589), and you can [play the full game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES). This repository presents the resulting game source for code review. My day-to-day contribution history is tied to a different GitHub account for organizational clarity and client privacy. The [project page](https://www.patchthedev.com/work/pro-wrestling-leagues) includes gameplay footage and further details.
