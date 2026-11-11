"""Fondos de paralaje en pixel art; los interiores 2.5D usan blender/refugio.py.
python3 tools/escenario_pixel.py. Requiere Pillow. No depende de Blender.
"""
from PIL import Image, ImageDraw
from pathlib import Path
import random, math, json
OUT=Path(__file__).resolve().parents[1]/'arte'
R=random.Random(91)

def panel(d,box,color,light='#776e5c',dark='#282b2c'):
    x,y,X,Y=box
    d.rectangle(box,fill=color)
    d.line((x,y,X,y),fill=light)
    d.line((x,y,x,Y),fill=light)
    d.line((x,Y,X,Y),fill=dark)
    d.line((X,y,X,Y),fill=dark)

def city():
    for layer,base in [('fondo_lejos',('#4e6062','#334950')),('fondo_medio',('#46514c','#283b3d'))]:
        im=Image.new('RGBA',(640,130));d=ImageDraw.Draw(im)
        x=-6
        while x<640:
            w=R.randint(19,45);h=R.randint(38,95);y=120-h
            panel(d,(x,y,x+w,125),base[0], '#6b7164',base[1])
            d.rectangle((x+w-5,y+2,x+w,125),fill=base[1])
            for yy in range(y+7,117,11):
                for xx in range(x+4,x+w-7,7):
                    d.rectangle((xx,yy,xx+3,yy+5),fill=R.choice([base[1],base[1],'#898366']))
                    d.line((xx,yy+6,xx+4,yy+6),fill='#637068')
                    if R.random()<.2:d.line((xx,yy,xx+3,yy+5),fill='#3b4441')
            d.polygon([(x+3,y),(x+6,y-5),(x+11,y),(x+14,y-3),(x+17,y+3)],fill=base[0])
            for i in range(8):
                xx=R.randint(x,x+w);yy=R.randint(y+5,120)
                d.line((xx,yy,xx-2,yy+7,xx+1,yy+11),fill=base[1])
            for i in range(18):
                xx=R.randint(x,x+w);yy=R.randint(100,124)
                d.rectangle((xx,yy,xx+2,yy+3),fill='#424e3b')
            d.line((x+5,y,x+5,y-8,x+12,y-8),fill=base[1])
            x+=w+R.randint(2,7)
        # Sagging utility cables and a broken road-side fence.
        for xx in [22,126,245]:
            d.line((xx,64,xx,130),fill='#253737',width=2)
            d.line((xx-6,68,xx+7,68),fill='#253737')
        d.line([(22,67),(48,74),(74,77),(99,74),(126,67),(155,75),(183,78),(214,75),(245,67)],fill='#2d3e3e')
        im.save(OUT/(layer+'.png'))
    im=Image.new('RGBA',(640,45));d=ImageDraw.Draw(im)
    for i in range(340):
        x=R.randrange(640);y=R.randint(29,44)
        d.line((x,44,x+R.randint(-2,2),y),fill=R.choice(['#233c38','#354b3a','#49573c']))
    im.save(OUT/'primer_plano.png')

def props():
    import json
    meta=json.loads((OUT/'props.json').read_text())
    for name,m in meta.items():
        w,h=m['w'],m['h'];x=int(m['pie'][0]);y=int(m['pie'][1])
        im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im)
        d.ellipse((x-10,y-2,x+11,y+2),fill='#202d2e88')
        if name=='arbol':
            d.polygon([(x-3,y),(x-1,y-35),(x+3,y-34),(x+4,y)],fill='#635442')
            d.line((x,y-4,x+1,y-32),fill='#998064')
            for side in [-1,1]:d.line((x,y-21,x+side*10,y-34),fill='#6c6049',width=2)
            for i in range(90):
                xx=R.randint(x-15,x+15);yy=R.randint(y-59,y-25)
                if ((xx-x)/18)**2+((yy-(y-42))/22)**2<1:
                    d.rectangle((xx,yy,xx+R.randint(2,5),yy+2),fill=R.choice(['#344537','#475744','#5d674c','#778063']))
        elif name=='tocon':
            panel(d,(x-4,y-7,x+5,y),'#5f503f','#ab9870')
            d.line((x-2,y-6,x+3,y-6),fill='#c0a578')
        elif name.startswith('huerto'):
            d.polygon([(x-9,y-4),(x+7,y-4),(x+10,y),(x-8,y+2)],fill='#7c6547')
            for j in range(3):
                d.line((x-6,y-3+j*2,x+6,y-3+j*2),fill='#3b3830')
                for k in range(3):
                    xx=x-5+k*5; yy=y-3+j*2
                    d.line((xx,yy,xx,yy-(4 if name.endswith('listo') else 1)),fill='#8b9760')
                    if name.endswith('listo'):
                        d.line((xx-2,yy-3,xx+2,yy-2),fill='#718858')
                        d.point((xx+1,yy-4),fill='#bd7b45')
        elif name.startswith('valla'):
            damage=int(name[-1]);top=y-16+damage*4
            for i in range(5):
                xx=x-11+i*5
                panel(d,(xx,top+R.randint(-2,2),xx+2,y),'#716047','#ae956a')
                d.point((xx+1,y-6),fill='#222e30')
            for yy in [y-5,y-11]:
                if damage<2 or yy==y-5:
                    d.line((x-12,yy,x+12,yy+damage),fill='#a08a62',width=2)
            if damage:d.line((x-8,y-2,x+8,y-4),fill='#685840',width=2)
        elif name.startswith('puerta'):
            damage=int(name[-1]);top=y-28+damage*7
            panel(d,(x-8,top,x+8,y),'#5e5544','#aa9570')
            for xx in range(x-7,x+8,4):d.line((xx,top+1,xx,y),fill='#3e443b')
            if damage<3:
                for yy in [y-7,y-19]:d.line((x-9,yy,x+9,yy+3),fill='#b6a17b',width=2)
                d.point((x-5,y-14),fill='#d7bd78')
        elif name=='tumba':
            panel(d,(x-4,y-12,x+4,y),'#68736b','#a0a390')
            d.line((x,y-10,x,y-4),fill='#323f3c');d.line((x-2,y-8,x+2,y-8),fill='#323f3c')
        im.save(OUT/('prop_'+name+'.png'))
    # Rusted abandoned vehicle, same registered dimensions and ground anchor.
    im=Image.new('RGBA',(80,45));d=ImageDraw.Draw(im)
    for xx in [20,60]:
        d.ellipse((xx-5,31,xx+5,41),fill='#202d31');d.ellipse((xx-2,34,xx+2,38),fill='#62716a')
    d.polygon([(8,33),(8,22),(18,12),(29,12),(31,8),(70,8),(73,34)],fill='#9a9d85')
    d.polygon([(11,22),(19,14),(28,14),(28,22)],fill='#344e57')
    d.line((31,10,69,10),fill='#c1bea2');d.line((32,12,32,32),fill='#657367')
    d.rectangle((9,26,72,28),fill='#714f40');d.rectangle((8,31,73,34),fill='#566056')
    d.rectangle((10,24,13,25),fill='#c5b887');d.rectangle((61,25,64,26),fill='#303e3e')
    for i in range(70):
        xx=R.randint(33,70);yy=R.randint(22,33)
        d.point((xx,yy),fill=R.choice(['#785b40','#a38356','#68684f']))
    im.save(OUT/'prop_furgoneta.png')

if __name__=='__main__':
    city();print('Fondos de paralaje generados. Casa y objetos: blender -b -t 4 -P blender/refugio.py')
