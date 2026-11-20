# PixelKing 0.2.2

## Kings (from 0.2.1, kept)

- War King: up to 2 squares in all eight directions, two actions every turn (End Turn gives up the second).
- Shadow King: blinks up to 3 squares along the eight lines, over pieces, onto a safe square; strikes an
  enemy up to 3 squares away in melee (it can hit Gargoyles and guarded Kings) and returns home.
- Shield King: up to 2 squares in all eight directions; the first checkmate removes every checking piece.

## Changed in 0.2.2

- The 0.2.1 piece-introduction screens are rolled back: recruit/shop cards, opening draft, roster,
  pre-battle and the battle long-press card are the 0.2.0 ones again.
- Codex: every card has the same size and shows both portraits, the name, the rarity (also the border
  colour) and a few one-word traits ("Shell", "Rock smash", "Extra action"...). Tapping a card (not
  dragging) opens the same one-page card used in battle, with the rarity in place of the side.
- King descriptions rewritten short.
- Shadow King safety is judged like a ranged shot: after the blink or the strike-and-return, is the King's
  final square under attack (eggs due at the enemy's turn start included)? Results are cached per
  position. Marking a piece's targets with an enemy Shadow King on the board went from ~260 ms to ~70 ms
  on the first tap and ~20 ms after (desktop).
- Battle codes no longer report a false mismatch after an egg is laid or a pawn promotes.
