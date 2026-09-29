# Engineering notes

## Source organization

The repository organizes game logic into shared contracts, server services, application coordinators, focused domain modules, and client presentation. CollectionService tags connect arenas, weapons, turnbuckles, and entrance assets to central handlers. Wally manages third-party libraries outside the project-owned source tree.

## Gameplay systems

The code covers matchmaking, entrances, three-hit striking, running attacks, grapples, running grapples, directional grapple moves, finisher charge, reversals, pins, turnbuckle attacks, weapon durability, customization, moves, currency, progression, and match rewards.

## Design decisions

- Clients send action intent; the server selects targets and applies damage at the configured impact time.
- Tagged components and central services own world interactions.
- ProfileStore and other third-party libraries are installed through Wally.
- The game project excludes tests and local test runners. The separate test project includes them.
- Character attributes mirror domain state for presentation.
- Persistence, UI updates, and customization have separate owners.
- UI controllers do not mutate profile tables.

## Asset integration

The [live game](https://www.roblox.com/games/125171795730320/PRO-WRESTLING-LEAGUES) and [portfolio page](https://www.patchthedev.com/work/pro-wrestling-leagues) show the player-facing project. The code in this repository connects to Studio-authored presentation assets through the tags and attributes in [the runtime asset contract](RUNTIME_ASSETS.md).
