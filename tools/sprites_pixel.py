"""Atlas de actores 32px: 8 pasos, apuntado, disparo, recarga y caida.
python3 tools/sprites_pixel.py (Pillow). Armas independientes para animarlas.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
import math,json
OUT=Path(__file__).resolve().parents[1]/'arte'
SHIRTS=['697d84','bc7048','879461','8d6689','c09b57','547e8b','b35c65','aaa494']
SKINS=['e4b78e','b78061','825644'];INK='#191c28'

def shade(h,k):return tuple(min(255,int(int(h.lstrip('#')[i:i+2],16)*k)) for i in (0,2,4))

def sprite(col,row,shirt,look=0,zombie=None):
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    walking=1<=col<=8;aiming=9<=col<=12;reloading=13<=col<=15;dead=col>=16
    phase=(col-1)*math.tau/8 if walking else 0
    stride=math.sin(phase);bob=round(abs(math.sin(phase*2))) if walking else 0
    width=5 if zombie=='bruto' else 3
    x=16+ (round(math.sin(phase)*.6) if zombie else 0);y=14-bob
    lean=2 if zombie else (1 if aiming else 0)
    recoil=[0,-2,-1,0][col-9] if aiming and not zombie else 0
    skin=['a1aa80','b4aa82','8b9275'][['normal','corredor','bruto'].index(zombie)] if zombie else SKINS[look]
    def limb(points,c,w=2):
        d.line(points,fill=INK,width=w+2);d.line(points,fill=c,width=w)
    # Pierna trasera / delantera con rodillas y fase de vuelo separadas.
    for side in [-1,1]:
        cycle=phase+(math.pi if side<0 else 0)
        step=round(math.sin(cycle)*4) if walking else side*2
        lift=round(max(0,math.cos(cycle))*3) if walking else 0
        hip=(x+side*2,y+3);knee=(x+side+round(step*.5),y+7-lift//2);foot=(x+step,24-lift)
        limb([hip,knee,foot], '#384453' if side<0 else '#596675',3)
        d.rectangle((foot[0]-1,foot[1],foot[0]+2,foot[1]+1),fill=INK)
        d.point((foot[0],foot[1]),fill='#8a928b')
    tx=x+recoil
    d.polygon([(tx-width,y-6),(tx+width,y-6),(tx+width+1,y+3),(tx-width,y+3)],fill=INK)
    d.rectangle((tx-width+1,y-5,tx+width-1,y+2),fill='#'+shirt)
    d.line((tx-width+1,y-4,tx-width+1,y+1),fill=shade(shirt,1.3))
    d.line((tx+width-1,y-4,tx+width-1,y+1),fill=shade(shirt,.7))
    d.line((tx-width,y+2,tx+width,y+2),fill='#35353b')
    d.point((tx,y+2),fill='#c0a877')
    hx=tx+lean
    if zombie and aiming:hx+=col-9
    d.rectangle((hx-3,y-12,hx+3,y-6),fill=INK)
    d.rectangle((hx-2,y-11,hx+2,y-7),fill='#'+skin)
    d.line((hx-2,y-11,hx+1,y-11),fill=shade(skin,1.18))
    d.rectangle((hx-3,y-13,hx+2,y-11),fill=['#39303a','#72513f','#b9a181'][look])
    d.line((hx-2,y-13,hx+1,y-13),fill=['#5c4b51','#98724f','#e1cc9e'][look])
    d.point((hx+2,y-9),fill='#e1c78d' if zombie else INK)
    if zombie:
        d.rectangle((hx,y-7,hx+2,y-6),fill='#6c263f')
        d.rectangle((tx,y-4,tx+2,y),fill='#702a40')
        for i in range(3):d.line((tx,y-3+i*2,tx+2,y-2+i*2),fill='#c6aa92')
    for side in [-1,1]:
        shoulder=(tx+side*3,y-4)
        if aiming:
            reach=(col-8)*2 if zombie else 0
            elbow=(tx+4+reach//2,y-1)
            hand=(tx+7+reach,y-3) if zombie else (tx+7,y-3+ (1 if col==10 else 0))
        elif reloading:
            elbow=(tx+4,y+1);hand=(tx+3+(col-13),y-2+(col-13)*2)
        else:
            swing=round(stride*3)*side
            elbow=(tx+side*3+swing//2,y-1);hand=(tx+side*3+swing,y+3)
        limb([shoulder,elbow,hand],'#'+shirt)
        d.rectangle((hand[0],hand[1],hand[0]+1,hand[1]+1),fill='#'+skin)
    if row in [1,2,3] and not dead:
        d.rectangle((hx-2,y-10,hx+2,y-8),fill=['#39303a','#72513f','#b9a181'][look])
    if dead:
        angle=[20,48,75,90][col-16]
        rotated=im.rotate(angle,resample=Image.Resampling.NEAREST,center=(16,16))
        im=Image.new('RGBA',(32,32))
        im.paste(rotated,(0,round(math.sin(math.radians(angle))*6)))
    if row in [2,3,4,5]:im=ImageOps.mirror(im)
    return im

def weapon(kind):
    im=Image.new('RGBA',(40,16));d=ImageDraw.Draw(im)
    if kind=='pistola':
        d.rectangle((9,5,19,7),fill=INK);d.line((10,5,18,5),fill='#9aa7a4')
        d.polygon([(10,7),(14,7),(13,12),(10,12)],fill='#4d5150')
    else:
        ak=kind=='ak'
        d.polygon([(1,6),(8,6),(10,8),(7,10),(1,9)],fill='#86583c' if ak else '#414d50')
        d.rectangle((8,5,25,8),fill=INK);d.line((9,5,25,5),fill='#849391')
        d.rectangle((22,6,35,7),fill='#333c41');d.point((34,5),fill='#9ca79d')
        d.rectangle((19,6,26,8),fill='#a37145' if ak else '#56625f')
        d.polygon([(14,8),(18,8),(18,11),(21,13),(18,14),(15,12)],fill='#4f5553')
        d.line((16,9,17,12,19,13),fill='#87928b')
        d.polygon([(10,8),(13,8),(12,12),(10,12)],fill='#805335' if ak else '#414a48')
        d.rectangle((11,3,16,4),fill='#59655f')
    im.save(OUT/('arma_'+kind+'.png'))
    return im

def main():
    for i,shirt in enumerate(SHIRTS):
        for look in range(3):
            im=Image.new('RGBA',(640,256))
            for row in range(8):
                for col in range(20):im.paste(sprite(col,row,shirt,look),(col*32,row*32))
            im.save(OUT/f'sobreviviente_c{i}_l{look}.png')
    for kind,shirt in [('normal','626c63'),('corredor','92705d'),('bruto','675268')]:
        im=Image.new('RGBA',(640,256))
        for row in range(8):
            for col in range(20):im.paste(sprite(col,row,shirt,zombie=kind),(col*32,row*32))
        im.save(OUT/f'zombi_{kind}.png')
    for name in ['pistola','ak','m4']:weapon(name)
    for name in ['sobreviviente','zombi']:
        meta={'frame':32,'dirs':8,'columnas':20,'pie':[16,25],'anims':{'idle':[0,1],'walk':[1,8],'aim':[9,1],'shoot':[10,3],'reload' if name=='sobreviviente' else 'hurt':[13,3],'die':[16,4]}}
        if name=='sobreviviente':meta.update(camisas=8,looks=3)
        (OUT/(name+'.json')).write_text(json.dumps(meta,indent=2)+'\n')
    # Vista animada del ciclo de andar y disparar, salida de documentacion.
    frames=[]
    for i in range(24):
        canvas=Image.new('RGBA',(256,72),'#19212c')
        for j in range(3):
            col=1+i%8 if i<12 else 9+i%4
            f=sprite(col,0,SHIRTS[j]);canvas.alpha_composite(f,(16+j*75,12))
            if i>=12:
                g=weapon(['pistola','ak','m4'][j]);canvas.alpha_composite(g,(26+j*75-(2 if i%4==2 else 0),20))
        for j,k in enumerate(['normal','corredor','bruto']):
            f=sprite(1+i%8,0,'626c63',zombie=k);canvas.alpha_composite(f,(16+j*75,40))
        frames.append(canvas.resize((1024,288),Image.Resampling.NEAREST))
    frames[0].save(OUT/'animaciones.gif',save_all=True,append_images=frames[1:],duration=90,loop=0,disposal=2)
    print('27 atlas de 20 estados, armas independientes y muestra animada generados.')
if __name__=='__main__':main()
