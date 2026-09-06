# App images

Drop the RepLiT logo here as **`logo.png`** (this exact filename, lowercase).

`AppLogo` (lib/widgets/app_logo.dart) renders `assets/images/logo.png` on every
screen (top bars, login, register, splash). A transparent-background PNG works
best on the dark theme. Until the file exists, a "LOGO" placeholder box shows.

After adding/replacing `logo.png`, run `flutter pub get` and restart the app
(adding a new file to an already-declared asset folder needs a rebuild, not just
hot reload).
