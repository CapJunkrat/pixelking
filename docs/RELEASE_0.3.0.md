# PixelKing 0.3.0

## Difficulty
- New journeys start by choosing a difficulty; it is saved with the journey (older saves play as Easy).
  - Easy: the enemy AI as before.
  - Medium: the enemy checks every capturing reply before it moves, so it stops leaving its King
    to be taken, uncovering pieces to discovered attacks, or standing in a Shadow King's reach.
  - Hard: the enemy searches several moves ahead (alpha-beta with every exchange played out),
    thinking up to 2 s a move on a background thread, so the screen never freezes; faster phones
    look deeper. The web version gives it 0.7 s.

## Balance
- Shadow King: blinks and strikes 1-3 squares along ranks, files and diagonals (24 squares),
  instead of anywhere in the 7x7 area (48 squares).
- Gorgon: slides on Bishop diagonals instead of Queen rays; value 8 -> 6.
- Enemy armies get a rarity floor: no Commons from Act 2, no Rares from Act 4 (guards, elite
  captains and Boss armies included; the strength budget is unchanged, so armies field fewer,
  rarer pieces).
- Fused pieces join enemy armies: the Epic ones (Lancer) from Act 3, all of them (Swift Courier,
  Blast Catapult, Sky Archer, Flame Phoenix, Thousand Faces) from Act 5. Fused Kings do not.

## Rewards and rules
- A drawn battle is fought again for free: no failure counted, the retry kept.
- Every battle reward can be taken as gold instead: 12 (normal) or 20 (elite and Boss), plus 3 per
  act past the first.

## Interface
- Piece cards (codex and in-battle long-press) show the fusion path of fused pieces.
- Chinese names: 鹰隼猎手 (Falconer) and 天鹰射手 (Sky Archer).

## Fixes
- The first launch follows the device language (Chinese devices start in Chinese); it always
  started in English before.
- Opening draft: releasing a long-press no longer switches to the card underneath.
