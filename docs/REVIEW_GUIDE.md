# Review guide

This repository presents the Luau application code for Pro Wrestling Leagues. The most useful review path is:

1. `src/server/Services/CombatService.luau` for the network/application boundary.
2. `src/server/Application/CombatCoordinator.luau` and `StrikeResolver.luau` for combat orchestration.
3. `src/server/Domain/Combat/Combatant.luau` and the coordinators for state ownership and lifecycle.
4. `src/server/Persistence/PlayerRepository.luau` and `ProfileMigrations.luau` for persistence boundaries.
5. `src/shared/Network/Contracts.luau`, `RequestGateService.luau`, and `RequestGuard.luau` for trust boundaries.
6. `src/server/Services/MatchService.luau`, `Application/MatchCoordinator.luau`, and `Domain/Match/MatchSession.luau` for match lifecycle.

## Invariants worth checking

- Client requests carry intent, not authoritative results.
- Resource costs are committed only after an action is fully validated.
- Match rewards are issued only from an active match.
- Match rewards also require sufficient active time and a shared opponent cooldown claim.
- A reward retry uses the same match ID and cannot mutate the same profile twice while that ID remains in its ledger.
- Grapples revalidate the original target after the reversal window; stale or out-of-range targets take no damage.
- Incapacitating combat states lock default movement and temporarily request server physics ownership.
- A poise break from a taunt, turnbuckle action, grapple, pin, or standing-up state reaches `Grounded`; lesser stuns do not release `Grounded` or `Pinned` fighters.
- Clients receive match completion before the shared reward claim runs; a pending claim still blocks requeue and profile release through the bounded settlement wait.
- A departing player's profile waits for the match reward claim and both profile updates, up to the configured settlement deadline.
- Queueing retries when an arena becomes available.
- Persisted equipped moves cannot grant their own unlocks.
- A cancelled countdown cannot begin combat, and stale entrance cues cannot play after match activation.
- Running actions require plausible sampled travel, not velocity alone.
- Persistence is accessed through one repository boundary.
- Stateful objects own cleanup through Trove.
- Timed interactions use server time.
- Delayed recovery work is generation-checked so stale timers cannot mutate a later combat state.
- Arena weapons are tied to their origin arena and reset when the owning match closes.
- Runtime world objects use tags instead of copied scripts.
- Configuration and player-data schemas are separate from implementation.

## Play and assets

The [live Roblox game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) and [project page with footage](https://www.patchthedev.com/work/pro-wrestling-leagues) show the player experience. [Runtime assets](RUNTIME_ASSETS.md) explains how the application code binds to arenas, weapons, animations, UI, sounds, and entrance effects.
