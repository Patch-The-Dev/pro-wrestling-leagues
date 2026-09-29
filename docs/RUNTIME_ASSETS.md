# Runtime asset contract

Studio-managed presentation assets stay outside the application architecture.

## ReplicatedStorage

Optional folders:

```text
ReplicatedStorage/
└── Assets/
    ├── Animations/
    ├── Audio/
    ├── Customization/
    └── Effects/
```

Combat presentation resolves animations from `ReplicatedStorage/Assets/Animations`. A move can be either:

- an `Animation` named exactly after the move ID, used for the attacker
- a Folder named after the move ID containing `Attacker` and optional `Victim` Animation objects

Actions without a move ID use their action name. Weapon attacks use the configured `WeaponId`.

The client creates the pin timing prompt in `PinPromptView`. No authored `PinPrompt` GUI is required. Strike impact times are configured in `MovesConfig`; attacker animation starts when the server accepts the strike, and victim presentation follows the server impact event.

## Arenas

Tag each arena model with `WrestlingArena` and set:

- `ArenaId` string attribute
- `RequiredPlayers` number attribute

Optional children:

- `Spawns` folder containing BaseParts. Use a numeric name or a numeric `SpawnIndex` attribute to define order.

Match placement records each character's position before moving it into the arena and returns that same character there before the arena is released. Queue entry points should therefore be outside the ring's playable area. A character that respawns during the match uses normal Roblox spawning and is not moved by the old match.

## Weapons

Tag each Tool with `WrestlingWeapon`. Supported attributes are:

- `WeaponId` string
- `Damage` number
- `PoiseDamage` number
- `MaxDurability` number
- `Durability` number for an optional initial value
- `UseCooldown` number in seconds

The server assigns each registered Tool a `WeaponNetworkId` attribute at runtime. `WeaponId` identifies the weapon definition; `WeaponNetworkId` identifies that specific Tool instance and is the value used by client requests. Do not author `WeaponNetworkId` in Studio.

Weapon ownership, target validation, hit application, cooldown, and durability are server-owned. Do not put executable handler scripts inside each Tool.

## Turnbuckles

Tag climbable turnbuckle parts with `Turnbuckle`. Arena interaction code discovers them without copied scripts.

## Entrance presentation

Tag entrance pyro roots or ParticleEmitters with `EntrancePyro` and place them under the arena model they belong to. Pyro and lighting presets are configured in `shared/Config/EntranceConfig.luau`. Entrance camera focus is resolved from the entrant character, so no executable camera script is required in the arena.
