# PixelKing 0.2.4

- Battle screen: fits 360-wide phones in both languages. The top bar and the board used to be
  wider than the screen, so the whole battle layout was clipped on both sides (badly in Chinese,
  a few pixels in English).
  - Top bar: shorter act/layer text ("Act 1 · 1/5", "第1幕 · 1/5层"), the turn pill sized to its
    own text, and the enemy name ends in "…" when it is too long.
  - Board: minimum width 344 (it already fits itself to the space it gets).
- Web version: playable in the browser, including iPhone and iPad
  (https://capjunkrat.github.io/pixelking/).
- Android: release builds are a signed App Bundle (AAB) for Google Play, targeting Android 16 (API 36).
