# App images

`AppLogo` (lib/widgets/app_logo.dart) draws the RepLiT wordmark in the staff
top bars from this folder:

- **`logo.png`** — white letters with the coral signal bars and pin, for the
  dark ground (the default theme).
- **`logo-light.png`** — the same artwork with the letters in the light theme's
  ink (`#17140F`), for the light ground. Regenerate it whenever `logo.png`
  changes: every neutral (white or grey) pixel becomes the ink at the pixel's
  brightness as alpha; coloured pixels are kept as they are.

Both are transparent PNGs. After replacing either, run `flutter pub get` and
restart the app (a changed asset needs a rebuild, not just hot reload).
