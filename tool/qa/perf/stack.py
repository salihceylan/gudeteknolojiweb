import sys
from PIL import Image
# usage: stack.py out.png cols scale files...
out = sys.argv[1]; cols = int(sys.argv[2]); sc = float(sys.argv[3]); files = sys.argv[4:]
ims = []
for f in files:
    i = Image.open(f).convert('RGB'); ims.append(i.resize((int(i.width*sc), int(i.height*sc))))
w = max(i.width for i in ims); h = max(i.height for i in ims)
rows = (len(ims)+cols-1)//cols
c = Image.new('RGB', (cols*(w+4), rows*(h+4)), (255, 0, 255))
for n, i in enumerate(ims): c.paste(i, ((n%cols)*(w+4), (n//cols)*(h+4)))
c.save(out)
