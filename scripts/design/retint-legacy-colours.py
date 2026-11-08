#!/usr/bin/env python3
"""Moves the legacy colour sets onto the sun-lit palette (mobile redesign spec 2026-11-08, section 3).

Legacy screens read `R.color.color*()`; this keeps their names and changes only the sRGB values, so every
screen sits on the one neumorphic base. `FWSunlitTests` checks the asset values against `FWSunlit.Palette`.
Usage: python3 scripts/design/retint-legacy-colours.py [--check]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'fearless' / 'Assets.xcassets' / 'colors'

# name -> (0xRRGGBB, alpha). Alpha-only whites keep their value.
PALETTE = {
    'colorBlack19': (0x151831, 1.0),          # bg: page and every neumorphic surface
    'colorSemiBlack': (0x151831, 1.0),        # card fills become bg surfaces (painted Raised-1)
    'colorAlmostBlack': (0x151831, 1.0),
    'colorBlack': (0x0E1024, 1.0),            # bgDeep: wells and deep backgrounds
    'colorBlackAccentSecondary': (0x1A1E3A, 1.0),
    'colorBlack1': (0x1E2244, 1.0),
    'colorBlack02': (0x0E1024, 0.2),
    'colorBlack50': (0x0E1024, 0.5),
    'colorDarkGray': (0x2C315A, 1.0),         # strokes and neutral fills
    'colorGray': (0x7F86AA, 1.0),             # textTertiary
    'colorStrokeGray': (0x7F86AA, 1.0),
    'colorLightGray': (0xA9AECB, 1.0),        # textSecondary
    'colorWhite': (0xEEF0FA, 1.0),            # textPrimary
    'colorAlmostWhite': (0xEEF0FA, 1.0),
    'colorWhiteAccentSecondary': (0xA9AECB, 1.0),
    'colorPink': (0xEE0077, 1.0),             # brand
    'colorPink1': (0xEE0077, 1.0),
    'colorAccent': (0xEE0077, 1.0),
    'colorHighlightedPink': (0xF5046B, 1.0),
    'colorHighlightedAccent': (0xF5046B, 1.0),
    'colorAccentGradientStart': (0xF5046B, 1.0),
    'colorAccentGradientEnd': (0x78003F, 1.0),
    'colorPinkPlaceholder': (0xEE0077, 0.5),
    'colorCellSelection': (0xEE0077, 0.3),
    'colorGreen': (0x3DF2B0, 1.0),            # success / up
    'colorColdGreen': (0x3DF2B0, 1.0),
    'colorRed': (0xFF6B5E, 1.0),              # danger
    'colorCrimson': (0xFF6B5E, 1.0),
    'colorOrange': (0xFF9F57, 1.0),           # down / caution
    'colorYellow': (0xFFC452, 1.0),           # warning
    'colorSkeletonStart': (0x1B1F3D, 1.0),
    'colorSkeletonEnd': (0x2A2F57, 1.0),
    'colorScrim': (0x05060F, 0.6),
    'colorBlurOverlay': (0x05060F, 0.5),
    'colorBlurSeparator': (0xFFFFFF, 0.06),
}


def entry(hex_value, alpha):
    return {
        'color': {
            'color-space': 'srgb',
            'components': {
                'alpha': f'{alpha:.3f}',
                'blue': f'0x{hex_value & 0xFF:02X}',
                'green': f'0x{(hex_value >> 8) & 0xFF:02X}',
                'red': f'0x{(hex_value >> 16) & 0xFF:02X}',
            },
        },
        'idiom': 'universal',
    }


def main():
    check = '--check' in sys.argv
    stale = []
    for name, (value, alpha) in sorted(PALETTE.items()):
        path = ROOT / f'{name}.colorset' / 'Contents.json'
        if not path.is_file():
            raise SystemExit(f'missing colour set {path}')
        current = json.loads(path.read_text())
        wanted = dict(current)
        wanted['colors'] = [entry(value, alpha)]
        text = json.dumps(wanted, indent=2, separators=(',', ' : ')) + '\n'
        if path.read_text() != text:
            stale.append(name)
            if not check:
                path.write_text(text)
    if check and stale:
        raise SystemExit('stale colour sets: ' + ', '.join(stale))
    print(('checked ' if check else 'wrote ') + str(len(PALETTE)) + ' colour sets')


if __name__ == '__main__':
    main()
