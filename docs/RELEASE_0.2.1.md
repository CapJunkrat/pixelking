# PixelKing 0.2.1

## Changes

- War King moves/captures along all eight rays up to two squares and permanently receives up to two same-piece actions each turn, independently of captures. The existing End Turn control forfeits the second action; extra-action relics do not exceed the shared two-action cap.
- Shadow King blinks along eight rays up to three squares and permanently uses a returning melee strike. It crosses intervening blockers, returns to its origin after an attack if alive, respects ordinary protection, and requires the real final state to be safe. Safety includes enemy turn-start egg hatching and does not mutate real state or instance IDs.
- Shield King moves/captures along all eight rays up to two squares. Its once-per-battle first-checkmate removal remains unchanged and is explicitly described.
- All pieces now share structured summaries, trait labels, full rules and exceptions. Recruit/shop details are independent of recruit/buy actions. The Codex uses compact cards; shared scrollable details are reused across the Codex, recruit/shop, opening draft, roster, pre-battle and battle long-press.
- Key long movement descriptions no longer repeat separately listed passive rules. Chinese and English text were updated together; live statuses remain separate from base rules.
- Diagrams show the full three-square range and continuation arrows for longer rays. Shadow strike animation blinks back rather than sliding home.

## Verification

- Previous content was committed first as `3183ab9`; its working tree was empty before feature implementation.
- Final complete automated manifest: **74 test files passed, 0 failed**.
- Layout coverage: **50 piece definitions, 2 locales, 320/360/414 logical widths; 300 combinations** across recruit, shop, Codex and shared details. Tests check card-internal vertical containment and that inspecting does not submit rewards or purchases.
- Actual War King End Turn UI path separately exercised: first ordinary move grants a second action, the button becomes enabled after presentation, clicking forfeits it and hands the turn to the enemy.
- New King actions and replays, returning-strike presentation, and due/delayed egg safety regressions exercised.
- Native Godot rendering inspected for recruit, Stone Giant detail and Codex at 360×640. Screenshots and independent final re-review are local delivery artifacts, not shipped game resources.
- Independent UI review passed; independent core review found an omitted turn-start hatch, fixed with a failing regression and passing targeted re-review. Final targeted re-review passed with no blocking security or logic findings.
- Baseline-style ObjectDB/resource cleanup diagnostics still occur on passing runs; this is not a warning-free release.

## Android delivery

- Version name `0.2.1`, version code `3`, package `com.johnz.pixelking`, arm64 debug APK.
- Export uses the installed Godot 4.7.2 Android debug template and existing signing identity. Verify the final APK signature and compare the signer to the previous build before sending.
- No Android device/emulator was attached for installation testing; desktop native rendering and automated Godot tests are not an Android device smoke test.
