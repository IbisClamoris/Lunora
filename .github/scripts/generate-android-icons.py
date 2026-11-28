#!/usr/bin/env python3
"""Generate Android launcher resources from Lunora's checked-in SVG brand mark."""
from pathlib import Path
import re
import sys

import cairosvg

ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / "android" / "app" / "src" / "main"
BRAND = ROOT / "assets" / "branding" / "lunora_icon.svg"

if not BRAND.is_file():
    raise SystemExit(f"Missing Lunora brand icon: {BRAND}")

# Legacy launcher bitmaps are required for pre-Android 8 launchers.
for density, size in {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}.items():
    target = ANDROID / "res" / f"mipmap-{density}" / "ic_launcher.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(url=str(BRAND), write_to=str(target),
                     output_width=size, output_height=size)

# Adaptive icons use a transparent foreground and a separate solid background.
# Keep the moon and stars within Android's central safe zone so OEM masks do not
# crop the artwork on circular, squircle, or teardrop launchers.
foreground_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <g transform="translate(25.6 25.6) scale(.8)">
    <path d="M159 43c-37 10-61 49-53 89 8 41 48 67 89 59-17 18-42 28-69 24-48-7-81-52-74-100 7-47 52-80 100-72 2 0 5 0 7 0z" fill="#fff3c4"/>
    <path d="m185 56 8 18 19 8-19 8-8 19-8-19-19-8 19-8z" fill="#fff0bd"/>
    <circle cx="67" cy="81" r="4" fill="#fff0bd"/>
    <circle cx="194" cy="157" r="3" fill="#d9c6ff"/>
    <path d="m65 169 5 11 12 5-12 5-5 12-5-12-12-5 12-5z" fill="#d9c6ff"/>
  </g>
</svg>"""
drawable = ANDROID / "res" / "drawable-nodpi"
drawable.mkdir(parents=True, exist_ok=True)
cairosvg.svg2png(bytestring=foreground_svg.encode(), 
                 write_to=str(drawable / "lunora_launcher_foreground.png"),
                 output_width=432, output_height=432)

adaptive_dir = ANDROID / "res" / "mipmap-anydpi-v26"
adaptive_dir.mkdir(parents=True, exist_ok=True)
(adaptive_dir / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\\n'
    '    <background android:drawable="@color/lunora_launcher_background" />\\n'
    '    <foreground android:drawable="@drawable/lunora_launcher_foreground" />\\n'
    '</adaptive-icon>\\n',
    encoding="utf-8",
)
colors = ANDROID / "res" / "values" / "lunora_launcher_colors.xml"
colors.parent.mkdir(parents=True, exist_ok=True)
colors.write_text(
    '<?xml version="1.0" encoding="utf-8"?>\\n'
    '<resources>\\n'
    '    <color name="lunora_launcher_background">#292044</color>\\n'
    '</resources>\\n',
    encoding="utf-8",
)

manifest = ANDROID / "AndroidManifest.xml"
if not manifest.is_file():
    raise SystemExit(f"Missing generated Android manifest: {manifest}")
source = manifest.read_text(encoding="utf-8")
source, label_count = re.subn(r'android:label="[^"]+"',
                              'android:label="Lunora"', source, count=1)
if label_count != 1:
    raise SystemExit("Could not locate android:label in AndroidManifest.xml")
if 'android:icon="@mipmap/ic_launcher"' in source:
    pass
else:
    source, icon_count = re.subn(r'<application\\b',
                                '<application android:icon="@mipmap/ic_launcher" '
                                'android:roundIcon="@mipmap/ic_launcher"',
                                source, count=1)
    if icon_count != 1:
        raise SystemExit("Could not locate <application> in AndroidManifest.xml")
manifest.write_text(source, encoding="utf-8")
print("Generated Lunora legacy and adaptive launcher icons; app label set to Lunora.")
