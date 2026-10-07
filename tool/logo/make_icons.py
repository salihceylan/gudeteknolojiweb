#!/usr/bin/env python3
"""Logo SVG'sinin yapraklarından web simgelerini üretir (keskin, vektörden).

Kullanım:  python tool/logo/make_icons.py <logo.svg>
Üretir: web/favicon.png (64, şeffaf), web/icons/Icon-192.png, Icon-512.png (koyu zemin), Icon-maskable-192.png,
Icon-maskable-512.png (koyu zemin, güvenli bölgeye sığan yapraklar). Gölge, yazı ve slogan simgeye girmez.
Gerekenler: Python (standart kütüphane), Node + tool/qa/node_modules (playwright-core) ve Chrome/Edge.
"""
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
NS = 'http://www.w3.org/2000/svg'
DARK_BG = '#06080B'  # web/manifest.json background_color ile aynı


def local(tag):
    return tag.split('}', 1)[1] if '}' in tag else tag


def leaves_only(src):
    ET.register_namespace('', NS)
    tree = ET.parse(src)
    root = tree.getroot()
    for g in list(root):
        if local(g.tag) == 'g' and g.get('id') in ('shadow', 'wordmark', 'tagline'):
            root.remove(g)
    xs, ys = [], []
    for p in root.iter():
        if local(p.tag) == 'path':
            nums = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', p.get('d'))]
            xs += nums[0::2]
            ys += nums[1::2]
    return tree, (min(xs), min(ys), max(xs), max(ys))


def icon_svg(tree, bbox, fill_ratio, bg):
    """Yaprak grubunu kare bir tuvalin ortasına, [fill_ratio] oranında yerleştirir."""
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0
    side = max(w, h) / fill_ratio
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    vb = f'{cx - side / 2:.1f} {cy - side / 2:.1f} {side:.1f} {side:.1f}'
    root = tree.getroot()
    root.set('viewBox', vb)
    for k in ('width', 'height'):
        root.attrib.pop(k, None)
    for r in root.findall(f'{{{NS}}}rect'):
        root.remove(r)
    if bg:
        rect = ET.Element(f'{{{NS}}}rect', {'x': f'{cx - side / 2:.1f}', 'y': f'{cy - side / 2:.1f}', 'width': f'{side:.1f}', 'height': f'{side:.1f}', 'fill': bg})
        root.insert(0, rect)
    return ET.tostring(root, encoding='unicode')


def render(svg_text, out_png, size, bg):
    with tempfile.NamedTemporaryFile('w', suffix='.svg', delete=False, encoding='utf-8') as f:
        f.write(svg_text)
        tmp = f.name
    try:
        subprocess.run(['node', os.path.join(ROOT, 'tool', 'logo', 'render_svg.mjs'), tmp, out_png, str(size), bg or 'transparent'], check=True)
    finally:
        os.unlink(tmp)


def main():
    src = sys.argv[1]
    tree, bbox = leaves_only(src)
    web = os.path.join(ROOT, 'web')
    # Tarayıcı sekmesi: şeffaf, yapraklar tuvali doldurur (açık/koyu sekme çubuğunda da görünür).
    render(icon_svg(tree, bbox, 0.94, None), os.path.join(web, 'favicon.png'), 64, None)
    # Ana ekran simgeleri: koyu zemin, yapraklar tuvalin ~%66'sını kaplar.
    for size in (192, 512):
        render(icon_svg(tree, bbox, 0.66, DARK_BG), os.path.join(web, 'icons', f'Icon-{size}.png'), size, DARK_BG)
    # Maskeli simgeler: platform kenarları kırpar; içerik merkezdeki %80'lik güvenli bölgeye (burada ~%52) sığmalı.
    for size in (192, 512):
        render(icon_svg(tree, bbox, 0.52, DARK_BG), os.path.join(web, 'icons', f'Icon-maskable-{size}.png'), size, DARK_BG)


if __name__ == '__main__':
    main()
