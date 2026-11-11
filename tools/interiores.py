"""Distribucion compartida entre Blender y la simulacion. python3 tools/interiores.py"""
import json
from pathlib import Path
P=Path(__file__).resolve().parents[1]/'arte'/'interiores.json'
beds=[];rooms=[];walls=[]
xs=[180+30*i for i in range(10)]+[560+30*i for i in range(7)]
for f in [2,3]:
 for x in xs:
  beds.append({'id':len(beds),'x':x,'y':2.2,'f':f,'acceso_x':x,'acceso_y':.9})
for i,(a,b) in enumerate([(6.25,11.9),(12.1,18.65),(21.95,26.5),(26.7,31.25)]):
 rooms.append({'x0':a,'x1':b,'f':4})
 for y in [2.2,5.0]:
  for side in [0,1]:
   x=a+.85 if side==0 else b-.85
   beds.append({'id':len(beds),'x':round(x*25,3),'y':y,'f':4,'acceso_x':round((x+(.8 if side==0 else -.8))*25,3),'acceso_y':y})
for x in [12.0,18.8,21.85,26.6]:walls.append({'x0':x-.08,'x1':x+.08,'y0':1.2,'y1':6.8,'f':4})
obstacles=[]
for bed in beds:
 x=bed['x']/25;y=bed['y']
 obstacles.append({'x0':x-.55,'x1':x+.55,'y0':y-1.05,'y1':y+1.05,'f':bed['f'],'tipo':'cama'})
obstacles+=walls
assert len(beds)==50
P.write_text(json.dumps({'camas':beds,'habitaciones':rooms,'obstaculos':obstacles,'obstaculos_base':obstacles},indent=2)+'\n')
print('50 camas; cuatro dormitorios superiores; accesos y obstaculos compartidos.')
