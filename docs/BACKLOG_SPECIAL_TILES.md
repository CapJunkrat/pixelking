# Backlog: special board tiles

Agreed 2026-11-18: ship plain **rocks** first (see `BoardState.blocked_squares`), add these
later. At most one or two kinds per battle so every fight feels different; tiles appear only
in the middle rows (never inside either deployment zone), placed symmetrically for fairness,
and are visible in the pre-battle preview so the player can arrange around them.

| Tile | Rule | Notes |
|---|---|---|
| Bush | A piece standing in it cannot be targeted by ranged pieces (Bowman, Catapult, Falconer...). | Melee captures still work. |
| Altar | A piece standing on it at the start of its side's turn gets a 1-turn shield. | Reuse the shield dome. |
| Powder barrel | Explodes when attacked or when a piece is captured next to it, hitting the 8 squares around. | Reuse the Powder Keg blast. |
| Portal pair | Stepping onto one portal moves the piece to the other (if empty). | Always placed as a mirrored pair. |
| Rubble | Blocks like a rock, but any shot (light ranged pieces too) clears it. | Rocks themselves already break to heavy shots (Catapult, Blast Catapult, Sky Archer). |

Open questions for later: whether tiles are part of encounter data (fixed for elites/boss)
or rolled per battle like rocks; how the enemy AI values them.

## Ranged rules (shipped 2026-11-18)

Ranged pieces (Bowman, Catapult, Ranger, Falconer, Sky Archer, Blast Catapult) use
`RangedAttackRule`: they shoot without moving (targets 2+ squares away), step one square
and capture adjacent enemies in melee, cannot shoot while an enemy stands next to them,
and cannot shoot a King that has one of its own pieces next to it (bodyguard). Heavy
shots break rocks. The Ranger's boomerang hits every enemy on its line (up to 4 squares,
turning back at a rock). The Gargoyle is a melee Rook that ranged attacks cannot touch.
Future neutral objects (powder barrels, destructible crates, neutral monsters) should
plug into `BoardState._resolve_shot`.
