import sys
from PIL import Image, ImageChops
Q='G:/site/gudeteknolojiweb/qa_out/android/'
for a,b in [(0,1),(1,2),(2,3)]:
    A=Image.open(Q+f'df_{a}.png').convert('RGB'); B=Image.open(Q+f'df_{b}.png').convert('RGB')
    d=ImageChops.difference(A,B); bb=d.getbbox(); print(a,b,bb)
    if bb:
        g=d.convert('L').point(lambda v:255 if v>6 else 0); print(' strong bbox',g.getbbox())
