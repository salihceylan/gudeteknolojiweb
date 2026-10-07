#!/usr/bin/env python3
"""Üretim derlemesinde önbellek sorununu önler: main.dart.js dosyasını içerik özetiyle yeniden adlandırır.

Sunucu .js dosyalarına 7 gün önbellek süresi verdiğinden, aynı adla yüklenen yeni main.dart.js'in yerine ziyaretçinin
tarayıcısı eski kopyayı kullanabilir (yeni sayfa + eski kod karışımı). Dosya adı her derlemede içeriğe göre değiştiği için
bu olmaz. Kullanım:  python tool/cachebust.py <derleme-dizini>
"""
import hashlib
import json
import os
import re
import sys

root = sys.argv[1]
main_path = os.path.join(root, 'main.dart.js')
boot_path = os.path.join(root, 'flutter_bootstrap.js')
index_path = os.path.join(root, 'index.html')
for p in (main_path, boot_path, index_path):
    if not os.path.exists(p):
        sys.exit(f'HATA: {p} yok (zaten özetli ad verilmiş olabilir)')

with open(main_path, 'rb') as f:
    digest = hashlib.sha1(f.read()).hexdigest()[:10]
new_name = f'main.dart.{digest}.js'
os.replace(main_path, os.path.join(root, new_name))

with open(boot_path, encoding='utf-8') as f:
    boot = f.read()
patched, n = re.subn(r'"mainJsPath"\s*:\s*"main\.dart\.js"', f'"mainJsPath":"{new_name}"', boot)
if n == 0:
    sys.exit('HATA: flutter_bootstrap.js içinde mainJsPath bulunamadı')
with open(boot_path, 'w', encoding='utf-8') as f:
    f.write(patched)

with open(index_path, encoding='utf-8') as f:
    html = f.read()
html2, m = re.subn(r'src="flutter_bootstrap\.js(\?v=[^"]*)?"', f'src="flutter_bootstrap.js?v={digest}"', html)
if m == 0:
    sys.exit('HATA: index.html içinde flutter_bootstrap.js bulunamadı')
with open(index_path, 'w', encoding='utf-8') as f:
    f.write(html2)

print(json.dumps({'main': new_name, 'bootstrapReplaced': n, 'indexReplaced': m}))
