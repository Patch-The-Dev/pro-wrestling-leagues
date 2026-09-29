# Refactor notes

## Source audit

The Studio export contained 327 Luau scripts and about 63,000 lines. Exact-content analysis found 209 duplicate file instances beyond their originals. The largest sources of duplication were per-arena weapon handlers, announcer table handlers, turnbuckle interaction scripts, matchmaker displays, backup scripts, and copied default character animation scripts.

The original implementation also mixed production code with tests and notes, embedded third-party libraries directly into game folders, relied on many direct RemoteEvents and RemoteFunctions, and concentrated major behavior in manager scripts above 1,000 lines.

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

## Compatibility

This is a portfolio implementation, not a drop-in replacement for the original place. Runtime assets should be tagged and organized according to `docs/RUNTIME_ASSETS.md` before connecting the code to a place file.
