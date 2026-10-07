import sys, os
from PIL import Image, ImageDraw
# usage: sheet.py out.png cols scale in1 in2 ...
out, cols, scale = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
files = sys.argv[4:]
ims = [Image.open(f).convert('RGB') for f in files]
ims = [i.resize((int(i.width*scale), int(i.height*scale))) for i in ims]
w, h = ims[0].size
rows = (len(ims)+cols-1)//cols
S = Image.new('RGB', (cols*w, rows*h), (255,0,255))
for k, im in enumerate(ims):
    S.paste(im, ((k%cols)*w, (k//cols)*h))
    d = ImageDraw.Draw(S); d.text(((k%cols)*w+4, (k//cols)*h+4), str(k)+':'+os.path.basename(files[k]), fill=(255,255,0))
S.save(out)
