# App icons

Every icon in the app is a glyph from `assets/fonts/app_symbols.ttf`, drawn
through `AppIcons` in `lib/widgets/app_icons.dart`. Both files are generated
here from `icons.txt`.

The design (Figma REPLIT (MAIN), 03 · pass 3) draws every icon from one
family: **Material Symbols Rounded, Fill 1, weight 400, grade 0, optical size
24**, with check, close, add and the two chevrons kept as 2 px strokes.
Flutter's built-in `Icons` are the older Material Icons set, so their shapes
differ, and the `material_symbols_icons` package bundles three variable fonts
(about 35 MB); Flutter's icon tree shaker only cuts down a font family the app
actually uses, so the two unused styles would ship whole in every release APK.
The app therefore carries a static instance of the one style, cut down to the
icons it draws (about 26 KB).

## Adding an icon

1. Find its name at <https://fonts.google.com/icons> (Material Symbols,
   Rounded).
2. Add the name to `icons.txt`.
3. Get the variable font — `variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf`
   from <https://github.com/google/material-design-icons>, or `lib/fonts/MaterialSymbolsRounded.ttf`
   from the `material_symbols_icons` package archive on pub.dev.
4. From the repository root:

   ```bash
   python -m pip install fonttools
   python tool/symbols/build_font.py path/to/MaterialSymbolsRounded.ttf
   ```

5. Use it as `Icon(AppIcons.yourIcon)` (the snake_case name in camelCase).

The script refuses a name the font does not have, and stops if a line icon's
filled and unfilled glyphs ever stop matching. The font is Apache 2.0 —
`assets/fonts/LICENSE-material-symbols.txt`.
