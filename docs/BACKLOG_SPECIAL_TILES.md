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
| Rubble | Blocks like a rock, but a Catapult/blast can clear it into an empty square. | |

Open questions for later: whether tiles are part of encounter data (fixed for elites/boss)
or rolled per battle like rocks; how the enemy AI values them.
