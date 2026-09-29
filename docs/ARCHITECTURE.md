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
- `CombatMovement` connects incapacitating states to Humanoid movement and short-lived server network ownership. It captures and restores the character's movement settings when a lock begins and ends.
- `PinCoordinator` owns server-timed pin prompts and match resolution. `PinPromptView` renders the target time, while the server accepts only bounded latency compensation measured through `Player:GetNetworkPing()`.
- `Targeting` resolves opponents from the active match, distance, health, facing, and line of sight.
- `StrikeResolver` owns strike and weapon-hit resolution after the coordinator validates the use case. Strikes use configured windup times, then recheck the match, attacker, and target before applying damage.

The validation order is intentional. A strike commits stamina and cooldown when it starts, then checks the target again at impact. A grapple locks default movement during its reversal window, then revalidates the original target before resolving either the move or its reversal. Weapon use reserves durability before damage and rolls it back if the attack cannot land.

Damage reactions are valid from each interruptible combat state. A poise break clears accumulated poise only after `Grounded` is accepted, and a lesser stun does not release a fighter who is already grounded or pinned.

## Match lifecycle

`MatchService` is a transport facade over `Application/MatchCoordinator`. `MatchSession` owns lifecycle state while the coordinator owns queueing, arena placement, rewards, disconnect handling, and delayed cleanup. Matches do not enter `Active` unless the configured arena provides enough spawn points and both original characters remain ready through the entrance countdown. An aborted countdown releases the arena and requeues eligible players. Arena release and arena registration both retry waiting players.

When a match finishes, clients receive `Complete` and combat cleanup is triggered without waiting for the deferred MemoryStore claim and profile reward updates. A pending settlement survives arena cleanup and prevents the same players from requeueing until it resolves. The settlement keeps both profiles owned while either participant departs. Server shutdown applies that same departure callback to every loaded profile. A bounded wait prevents a stalled external call from consuming the entire shutdown window; if the deadline expires, the failure is logged and reward completion cannot be guaranteed.

The countdown is calculated from entrance lead-in, entrant spacing, presentation duration, and a short buffer. Entrance cues carry the match ID; the client discards stale cues and restores camera, lighting, music, and pyro on match state changes.

## Persistence

`PlayerRepository` is the only module that knows ProfileStore. Services receive typed player data through `DataService`. Migrations run before reconciliation so legacy Studio-era profiles can be normalized into the current schema. `PlayerDeparture` calls match settlement before releasing a departing player's profile, including during shutdown. Both participants wait on the same pending settlement if they leave while the shared reward claim is in progress, up to the configured shutdown budget. Each profile keeps the most recent 64 rewarded match IDs so in-session retries are idempotent. Failed reward updates are logged; the two profile writes are not one atomic transaction. Profile sanitization keeps an equipped move only when its unlock is owned; otherwise the slot returns to a default move.

Studio uses ProfileStore mock storage by default. This keeps local testing away from live player data.

## Networking

Knit supplies transport. `shared/Network/Contracts.luau` defines the accepted request vocabulary and runtime validators. `RequestGateService` centralizes per-player request throttling, backed by `RequestGuard`.

Clients send intent such as attack, grapple direction, pin input, purchase, or loadout change. Clients never report damage values, target identity, successful hits, currency changes, or persistence mutations as authority.

Roblox may give clients network ownership of their characters. `MovementHistory` samples server-observed positions, rejects large jumps, and requires sampled travel plus bounded velocity for running actions. Target selection also excludes candidates temporarily blocked by this check. This constrains obvious movement spoofing; it does not make replicated transforms fully authoritative. The thresholds in `CombatConfig` should be tuned against live latency and movement data.

Rewards require a minimum active duration and an atomic MemoryStore cooldown claim for the same opponent pair across servers. This reduces quick forfeit, rematch, and server-hop farming. A shared-store failure withholds the payout and is logged rather than silently falling back to a local limit. Studio tests use an in-memory claim. Failed profile updates and balance notifications are reported separately, avoiding a false failure after a successful balance mutation.

## State ownership

`Combatant` owns health, stamina, poise, finisher charge, and combat state. Selected values are mirrored to character attributes for presentation only.

`MatchSession` owns the match lifecycle. It distinguishes `Starting` from `Active`, so a cancelled countdown cannot accidentally award match rewards.

Profile state belongs to `PlayerRepository`. UI controllers hold presentation state only.

## Cleanup and asynchronous work

Trove represents ownership. Connections, session objects, and promises are attached to the object that owns their lifetime.

Promise is limited to real asynchronous boundaries such as profile loading, entrance sequencing, countdowns, reversal windows, pin timing, and delayed state recovery. Pure calculations return values directly.

## Framework maintenance

Knit 1.7.0 is pinned in Wally for this codebase. Its use is confined to service and controller facades; domain rules, coordinators, and persistence do not depend on Knit APIs. A future framework migration can replace those facades and signals while preserving the underlying gameplay modules. Dependency updates should be tested in the isolated Studio test place and against the live asset contract before release.

## Runtime tags

World behavior is discovered through CollectionService instead of scripts copied into assets:

- `WrestlingArena`
- `WrestlingWeapon`
- `Turnbuckle`
- `EntrancePyro`

Tagged objects can be cloned without cloning executable handler scripts.
