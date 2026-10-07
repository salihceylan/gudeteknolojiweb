import sys, json
from PIL import Image
from collections import Counter
theme = sys.argv[1]
data = json.load(open(f'G:/site/gudeteknolojiweb/qa_out/perf/ct_{theme}.json',encoding='utf8'))
def lin(c):
    c/=255
    return c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
def lum(p): return 0.2126*lin(p[0])+0.7152*lin(p[1])+0.0722*lin(p[2])
def cr(a,b):
    la,lb=lum(a),lum(b); hi,lo=max(la,lb),min(la,lb); return (hi+0.05)/(lo+0.05)
rows=[]
for d in data:
    im = Image.open(d['file']).convert('RGB')
    for r in d['rects']:
        x0,y0=max(0,int(r['x'])-2),max(0,int(r['y'])-2); x1,y1=min(im.width,int(r['x']+r['w'])+2),min(im.height,int(r['y']+r['h'])+2)
        if x1-x0<4 or y1-y0<4: continue
        reg = im.crop((x0,y0,x1,y1)); px=list(reg.getdata())
        bg = Counter(px).most_common(1)[0][0]
        # fg: farthest in luminance from bg, with some mass
        far = sorted(px, key=lambda p: -abs(lum(p)-lum(bg)))[:max(3,len(px)//200)]
        fg = far[len(far)//2]
        rows.append((cr(fg,bg), r['t'], r['h'], fg, bg, d['scroll']))
rows.sort()
for c,t,h,fg,bg,sc in rows[:28]:
    print(f'{c:5.2f}  h={h:4.0f} sc={sc} fg={fg} bg={bg}  {t}')
print('n',len(rows))
