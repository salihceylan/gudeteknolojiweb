import sys, glob, os
from PIL import Image, ImageStat
d=sys.argv[1]
prev=None
for f in sorted(glob.glob(d+'/*.jpg')):
    im=Image.open(f).convert('L'); m=ImageStat.Stat(im).mean[0]
    print(os.path.basename(f), f'{m:7.2f}', '' if prev is None else f'd={m-prev:+.2f}')
    prev=m
