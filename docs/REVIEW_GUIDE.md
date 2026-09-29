# Review guide

This repository is a portfolio refactor of a Studio-first Roblox project. The most useful review path is:

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
- Persistence is accessed through one repository boundary.
- Stateful objects own cleanup through Trove.
- Timed interactions use server time.
- Delayed recovery work is generation-checked so stale timers cannot mutate a later combat state.
- Arena weapons are tied to their origin arena and reset when the owning match closes.
- Runtime world objects use tags instead of copied scripts.
- Configuration and player-data schemas are separate from implementation.

## Scope

The original place contained Studio-managed arenas, animations, UI, sounds, tools, and cosmetic assets. This repository focuses on application code and documents the runtime asset contract separately. It is not intended to reproduce the original place file byte for byte.
