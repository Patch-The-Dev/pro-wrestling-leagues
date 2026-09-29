# Pro Wrestling Leagues

[![Source checks](https://github.com/Patch-The-Dev/pro-wrestling-leagues/actions/workflows/ci.yml/badge.svg)](https://github.com/Patch-The-Dev/pro-wrestling-leagues/actions/workflows/ci.yml)

**A Roblox wrestling game by PatchTheDev.** This repository presents its Luau application code as a Rojo project for technical review.

[Play Pro Wrestling Leagues on Roblox](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) · [View the project and gameplay footage](https://www.patchthedev.com/work/pro-wrestling-leagues) · [PatchTheDev portfolio](https://www.patchthedev.com)

Pro Wrestling Leagues is a full-stack, solo-developed wrestling game with multiplayer matches, combat, reversals, entrances, progression, and wrestler customization. The live game and footage show the player experience. The code here shows how the gameplay rules, network boundaries, persistent data, and client presentation are organized.

## What to review

| Area | Implementation | What it demonstrates |
| --- | --- | --- |
| Combat | [`CombatService`](src/server/Services/CombatService.luau), [`CombatCoordinator`](src/server/Application/CombatCoordinator.luau), [`StrikeResolver`](src/server/Application/StrikeResolver.luau) | Validated player intent, server-selected targets, action costs, strikes, and weapon damage |
| Grapples and pins | [`GrappleCoordinator`](src/server/Domain/Combat/GrappleCoordinator.luau), [`PinCoordinator`](src/server/Domain/Combat/PinCoordinator.luau), [`PinPromptView`](src/client/UI/PinPromptView.luau) | Timed reversals, visible pin timing, directional moves, and state transitions |
| Matches | [`MatchCoordinator`](src/server/Application/MatchCoordinator.luau), [`MatchSession`](src/server/Domain/Match/MatchSession.luau) | Two-player queueing, arena reservation, countdowns, results, disconnects, and cleanup |
| Player data | [`PlayerRepository`](src/server/Persistence/PlayerRepository.luau), [`ProfileMigrations`](src/server/Persistence/ProfileMigrations.luau) | A single persistence boundary with schema migration and Studio mock storage |
| Economy | [`EconomyService`](src/server/Services/EconomyService.luau), [`RewardCooldown`](src/server/Domain/Economy/RewardCooldown.luau) | Server-owned match rewards, cross-server opponent limits, prices, balances, and unlocks |
| Presentation | [`src/client`](https://github.com/Patch-The-Dev/pro-wrestling-leagues/tree/main/src/client), [`EntranceService`](src/server/Services/EntranceService.luau) | Inputs, HUD, animation, cameras, audio, lighting, and entrances kept apart from authoritative rules |

Start with the [review guide](docs/REVIEW_GUIDE.md) for a short reading order, or read the [architecture notes](docs/ARCHITECTURE.md) for the dependency and ownership rules.

## Gameplay systems in this code

The match flow pairs two eligible players, reserves an arena, places their characters, runs both entrances, then starts an active session. The countdown is derived from the entrance timing and checks that both original characters are alive and loaded before activation. A session records pin, knockout, forfeit, or vote results. Queued players are retried when an occupied arena is released or a new arena is registered. The arena and combat state are cleaned up when the session closes.

Combat includes a three-hit strike chain, running attacks, directional grapples, finishers, reversals, pins, stamina, health, poise, and finisher charge. `Combatant` owns the state of each fighter. `CombatMovement` locks walking and jumping during incapacitating and committed move states, temporarily requests server network ownership of the character root where the engine permits it, and restores movement on recovery. Damage can interrupt taunts, turnbuckle actions, grapples, pins, and standing up; a poise break is consumed only when the knockdown transition succeeds. `ActionBudget` checks cooldowns and resources. Strike animations start when the server accepts an action; the server checks range, facing, line of sight, and match state again at the move's configured impact time before applying damage. Grapples recheck the original target after the reversal window and cancel if the match, movement, distance, facing, or line of sight is no longer valid. Timed interactions and delayed recovery are owned by the corresponding session or scheduler so old work cannot change a later combat state. Pin input uses a visible client timing bar and a capped allowance derived from server-measured round-trip latency.

The server also manages arena weapons and turnbuckle interactions. Weapon instances are tracked by identity and arena, with ownership, cooldown, and durability checks. CollectionService tags bind world behavior without copying a handler script into every asset.

Eligible match rewards feed persistent Cash, Tickets, experience, fame, and win/loss records. A match must last at least 30 seconds to pay out. The match-complete event and combat cleanup do not wait for reward storage. A MemoryStore claim prevents the same opponent pair from earning another payout across servers for 10 minutes. If the shared claim fails, the match ends without a payout and the failure is logged. Early forfeits also pay nothing. A pending settlement blocks requeueing; normal departure and shutdown both attempt to finish it before profile release, with a bounded wait during an infrastructure stall. Each profile records a bounded set of recent match IDs, so a retry cannot apply the same result twice. Failed updates get short in-session retries and are logged if they still fail. The two profile updates are separate writes, so this is not a cross-profile transaction. The shop checks item prices and ownership on the server. Saved move loadouts are checked against owned unlocks before use; an unowned move falls back to its default slot. Client controllers handle the interface and audiovisual response to events; they do not decide combat outcomes or write profile data.

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

Clients send bounded requests such as an action name, grapple direction, pin input, purchase, or loadout change. They do not choose a damage amount, report a successful hit, award currency, or submit a match result. [`Contracts.luau`](src/shared/Network/Contracts.luau) validates network values at runtime, and [`RequestGateService`](src/server/Services/RequestGateService.luau) applies per-player throttling. Character attributes mirror selected state for presentation; combat rules read the server-owned `Combatant` instead. Because Roblox character movement can be client owned, [`MovementHistory`](src/server/Domain/Combat/MovementHistory.luau) also checks sampled travel and blocks combat after implausible jumps. This is a plausibility check, not a claim of complete movement authority.

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

The [source checks workflow](.github/workflows/ci.yml) installs the pinned packages, checks that the lockfile stays unchanged, runs formatting and lint, type-checks the persistence boundary and selected core rules, and builds both Rojo projects. The Luau analyzer uses versioned Roblox definitions with a checked checksum. The type gate covers the files named in the workflow; it does not claim full-project type analysis. To run the format, lint, and build checks locally:

```sh
git diff --exit-code -- wally.lock
stylua --check src tests
selene src tests
rojo build default.project.json -o ProWrestlingLeagues.rbxlx
rojo build test.project.json -o ProWrestlingLeaguesTests.rbxlx
```

The isolated TestEZ place covers match state, queue retries, slow reward claims, shutdown settlement, duplicate-safe rewards, damage reactions, combat movement locks, grapple validation, movement plausibility, strike impact timing, weapon rollback, reversals, pin timing, player data ownership, and recovery cancellation. On Windows, the checked-in runner builds the test place, runs it in Studio, and fails if the passing result is missing:

```powershell
.\tests\RunStudioTests.ps1
```

The same runner can check that all server services initialize together in the built game place:

```powershell
.\tests\RunStudioTests.ps1 -Bootstrap
```

You can also open `ProWrestlingLeaguesTests.rbxlx` in Studio and run the specs manually from the command bar:

```lua
local TestEZ = require(game.ReplicatedStorage.DevPackages.TestEZ)
local result = TestEZ.TestBootstrap:run({ game.ServerScriptService.Tests }, TestEZ.Reporters.TextReporter)
assert(result.failureCount == 0)
```

The hosted source checks build and lint the tests; the TestEZ suite and bootstrap run in Roblox Studio through the script above.

The source tree is the reviewable application layer; the [live Roblox game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) is the playable project. Studio-authored arenas, UI, animation, sound, and cosmetic assets connect through the documented runtime contract.

## Further reading

- [Architecture](docs/ARCHITECTURE.md): module boundaries, state ownership, and cleanup.
- [Review guide](docs/REVIEW_GUIDE.md): suggested reading order and invariants to check.
- [Runtime assets](docs/RUNTIME_ASSETS.md): arena, weapon, animation, and entrance contracts.
- [Engineering notes](docs/ENGINEERING_NOTES.md): source organization and design decisions.

**Note:** This repository presents the Pro Wrestling Leagues code as a code portfolio. My day-to-day contribution history is tied to a different GitHub account for organizational clarity and client privacy. The source here is the result of that work, so this account's commit history does not represent the game's full development history. You can [play the full Pro Wrestling Leagues game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES).
