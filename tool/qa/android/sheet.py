import sys
from PIL import Image
out = sys.argv[1]; files = sys.argv[2:]
ims = [Image.open(f).convert('RGB') for f in files]
h = 784; ims = [im.resize((int(im.width*h/im.height), h)) for im in ims]
W = sum(i.width for i in ims) + 6*(len(ims)-1)
sh = Image.new('RGB', (W, h), (255, 0, 255)); x = 0
for im in ims: sh.paste(im, (x, 0)); x += im.width + 6
sh.save(out)
