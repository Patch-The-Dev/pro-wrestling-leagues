# Refactor notes

## Source organization

The repository organizes game logic into shared contracts, server services, application coordinators, focused domain modules, and client presentation. Runtime tags replace handlers copied into individual arenas, weapons, turnbuckles, and entrance assets. Wally manages third-party libraries outside the project-owned source tree.

## Preserved gameplay concepts

The refactor keeps the original game's main systems: matchmaking, entrances, three-hit striking, running attacks, grapples, running grapples, directional grapple moves, finisher charge, reversals, pins, turnbuckle attacks, weapon durability, customization, moves, currency, progression, and match rewards.

## Intentional redesigns

- Client hit reports were removed. The server performs target selection and applies damage.
- Workspace scripts were replaced with tagged components and centralized services.
- ProfileService source was removed from the repository and replaced by ProfileStore through Wally.
- Copied utility libraries were removed in favor of package-managed dependencies or small project-owned modules.
- Backup and test scripts are not included in production source.
- Character attributes are now replication mirrors of domain state instead of the primary state store.
- Persistence no longer updates UI or applies customization directly.
- UI controllers do not mutate profile tables.

## Asset integration

The [live game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) and [portfolio page](https://www.patchthedev.com/work/pro-wrestling-leagues) show the player-facing project. The code in this repository connects to Studio-authored presentation assets through the tags and attributes in [the runtime asset contract](RUNTIME_ASSETS.md).
