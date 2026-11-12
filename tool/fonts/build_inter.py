"""Build the app's Inter fonts, assets/fonts/Inter-*.ttf, from the console's.

The design sets everything in Inter. The Admin console already serves it
(admin-web/public/fonts in the backend repository): one variable font for the
Latin letters, its weight free from 100 to 900, as a .woff2. Flutter picks a
weight from the font files a family lists, so the app carries a static
instance of each weight it draws with, 300 to 900, made from that same file:
the console and the app set the same letters.

Usage (from the repository root):

    python -m pip install fonttools brotli
    python tool/fonts/build_inter.py "<backend>/admin-web/public/fonts/inter-v20-latin-wght.woff2"

brotli reads the .woff2. Inter is under the SIL Open Font License 1.1
(assets/fonts/Inter-OFL.txt, the console's copy), which allows bundling it in
an app, with its license beside it.
"""

import pathlib
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'fonts'

# The weights the app draws with (FontWeight.w300 to w900), by file name.
WEIGHTS = {
    300: 'Light',
    400: 'Regular',
    500: 'Medium',
    600: 'SemiBold',
    700: 'Bold',
    800: 'ExtraBold',
    900: 'Black',
}


def main(source: str) -> None:
    for weight, style in WEIGHTS.items():
        font = TTFont(source)
        static = instancer.instantiateVariableFont(
            font, {'wght': weight}, updateFontNames=True
        )
        static.flavor = None  # a plain .ttf, not a .woff2
        path = OUT / f'Inter-{style}.ttf'
        static.save(path)
        print(f'{path.relative_to(ROOT)}: {path.stat().st_size // 1024} KB')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
