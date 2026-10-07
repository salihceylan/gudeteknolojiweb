import sys
from PIL import Image, ImageChops
# usage: diff.py prefix_a prefix_b ... prints mean abs diff & changed pixel % between *_a and *_b
for pre in sys.argv[1:]:
    a=Image.open(pre+'_a.png').convert('L'); b=Image.open(pre+'_b.png').convert('L')
    d=ImageChops.difference(a,b); px=list(d.getdata())
    ch=sum(1 for p in px if p>8)/len(px)*100
    print(f'{pre.split("/")[-1]:40s} mean={sum(px)/len(px):6.3f} changed>8={ch:6.3f}%')
