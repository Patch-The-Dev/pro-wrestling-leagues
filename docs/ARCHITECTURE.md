# Architecture

## Dependency direction

```text
Client Controllers -> Knit client service proxies
Server Services -> Application -> Domain -> Adapters / Repositories
Shared Config + Types + Contracts -> Client and Server
```

Knit is the application boundary, not the gameplay model. Services validate network requests and coordinate use cases. Stateful game rules live below them so they can be reviewed without UI or transport concerns.

## Patterns used

- Repository: `PlayerRepository` isolates ProfileStore and persistence lifecycle.
- Adapter: character and customization modules isolate Roblox object mutation from game rules.
- Coordinator: application modules sequence use cases without owning transport.
- Component: arena and weapon modules bind behavior to tagged world objects.
- State machine: combat and match objects expose explicit legal transitions.
- Strategy-like rules: move definitions, reward policy, targeting, and action budgeting are replaceable rule modules.
- Observer: Knit signals and Signal modules publish state changes without direct UI coupling.

## Combat

`CombatService` is a thin Knit facade over `Application/CombatCoordinator`. The coordinator owns the live `Combatant` objects and composes focused domain objects and the `StrikeResolver`:

- `ActionBudget` validates stamina, cooldowns, and attack-chain state before committing resources.
- `RecoveryScheduler` owns delayed state recovery.
- `GrappleCoordinator` owns reversal windows and grapple resolution.
- `PinCoordinator` owns server-timed pin prompts and match resolution.
- `Targeting` resolves opponents from the active match, distance, health, facing, and line of sight.
- `StrikeResolver` owns strike and weapon-hit resolution after the coordinator validates the use case.

The validation order is intentional. An action is fully checked before stamina, cooldown, durability, or state is committed.

## Match lifecycle

`MatchService` is a transport facade over `Application/MatchCoordinator`. `MatchSession` owns lifecycle state while the coordinator owns queueing, arena placement, rewards, disconnect handling, and delayed cleanup. Matches do not enter `Active` unless the configured arena provides enough spawn points for every participant.

## Persistence

`PlayerRepository` is the only module that knows ProfileStore. Services receive typed player data through `DataService`. Migrations run before reconciliation so legacy Studio-era profiles can be normalized into the current schema.

Studio uses ProfileStore mock storage by default. This keeps local testing away from live player data.

## Networking

Knit supplies transport. `shared/Network/Contracts.luau` defines the accepted request vocabulary and runtime validators. `RequestGateService` centralizes per-player request throttling, backed by `RequestGuard`.

Clients send intent such as attack, grapple direction, pin input, purchase, or loadout change. Clients never report damage values, target identity, successful hits, currency changes, or persistence mutations as authority.

## State ownership

`Combatant` owns health, stamina, poise, finisher charge, and combat state. Selected values are mirrored to character attributes for presentation only.

`MatchSession` owns the match lifecycle. It distinguishes `Starting` from `Active`, so a cancelled countdown cannot accidentally award match rewards.

Profile state belongs to `PlayerRepository`. UI controllers hold presentation state only.

## Cleanup and asynchronous work

Trove represents ownership. Connections, session objects, and promises are attached to the object that owns their lifetime.

Promise is limited to real asynchronous boundaries such as profile loading, entrance sequencing, countdowns, reversal windows, pin timing, and delayed state recovery. Pure calculations return values directly.

## Runtime tags

World behavior is discovered through CollectionService instead of scripts copied into assets:

- `WrestlingArena`
- `WrestlingWeapon`
- `Turnbuckle`
- `EntrancePyro`

Tagged objects can be cloned without cloning executable handler scripts.
