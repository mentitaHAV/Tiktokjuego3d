"""Refugio 2.5D: Blender 4.3+, Cycles CPU, camara 52° / azimut 10°.
blender -b -t 4 -P blender/refugio.py
Arte renderizado a 640x360. No se necesita Blender al jugar.
"""
import bpy, math, random, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'arte'
R=random.Random(520)
SOLO_DATOS="--metadata-only" in sys.argv
def renderizar():
    if not SOLO_DATOS:bpy.ops.render.render(write_still=True)
EL=math.radians(52);AZ=math.radians(10);PPM=12.5
FLOORS=[0,4.8,9.6,14.4,19.2]
BEDS=[180+30*i for i in range(10)]+[560+30*i for i in range(7)]
LAYOUT=json.loads((OUT/"interiores.json").read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
sc=bpy.context.scene
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=512
sc.cycles.sample_clamp_direct=5.0
sc.cycles.sample_clamp_indirect=1.2
sc.cycles.volume_bounces=1
sc.cycles.use_adaptive_sampling=True
sc.cycles.adaptive_threshold=.035
sc.cycles.use_denoising=False;sc.render.threads_mode='FIXED';sc.render.threads=4
sc.render.resolution_x=640;sc.render.resolution_y=360;sc.render.resolution_percentage=100
sc.render.film_transparent=True;sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA'
sc.view_settings.view_transform='AgX';sc.view_settings.exposure=.6
sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.19,.30,1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.16
sc.render.image_settings.color_depth='8'
main=bpy.data.collections.new('Interiores');sc.collection.children.link(main)
front=bpy.data.collections.new('Cantos_del_corte');sc.collection.children.link(front)
M={};lamps=[]
def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def col(h):return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
def mat(name,h,second=None,scale=4,emit=0):
    if name in M:return M[name]
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=col(h);p.inputs['Roughness'].default_value=.88
    if second:
        t=n.new('ShaderNodeTexNoise');t.inputs['Scale'].default_value=scale;t.inputs['Detail'].default_value=1.7
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
        ramp.color_ramp.elements[0].position=.28;ramp.color_ramp.elements[0].color=col(second)
        ramp.color_ramp.elements[1].position=.62;ramp.color_ramp.elements[1].color=col(h)
        m.node_tree.links.new(t.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs['Color'],p.inputs['Base Color'])
    if emit:
        p.inputs['Emission Color'].default_value=col(h);p.inputs['Emission Strength'].default_value=emit
    M[name]=m;return m
plaster=[mat('yeso_oliva','777665','515a52'),mat('yeso_clinica','7a9290','536969'),mat('yeso_ocre','8b8069','5f6358'),mat('yeso_azul','637986','424f5e'),mat('yeso_at ico','655d57','44413e')]
wood=mat('roble gastado','79654d','453e34',7);dark=mat('madera negra','302f2b','1d292c')
metal=mat('acero pavonado','3f5054','263336');rust=mat('oxido','7d4934','4a3930')
concrete=mat('hormigon','66675e','414b46',5);tile=mat('azulejo','929f91','657a70',4)
cloths=[mat('manta'+str(i),h,h2) for i,(h,h2) in enumerate([('606d58','3f4c3f'),('6f554e','4d3733'),('495e6b','32434b'),('827152','5a4a35')])]
linen=mat('lino','c1b89d','8b8978');black=mat('negro','121f27');glass=mat('cristal oscuro','294b5b','192f3c')
brick=mat('ladrillo','72503e','433b30');pale=mat('porcelana','aab3a5','73877d');red=mat('cruz','844b40');book=mat('libros','6a5745','4d4940')

MESHES={}
def box(name,loc,size,m,collection=main):
    if m.name not in MESHES:
        mesh=bpy.data.meshes.new('cubo_'+m.name)
        mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(.5,.5,-.5),(-.5,.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)],[],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)])
        mesh.materials.append(m);MESHES[m.name]=mesh
    o=bpy.data.objects.new(name,MESHES[m.name]);collection.objects.link(o)
    o.location=loc;o.scale=size;return o

def slab(name,x0,x1,y0,y1,z,h,m,collection=main):return box(name,((x0+x1)/2,(y0+y1)/2,z+h/2),(x1-x0,y1-y0,h),m,collection)
def light(name,loc,color,power,radius=.55):
    data=bpy.data.lights.new(name,'POINT');data.color=color;data.energy=power;data.shadow_soft_size=radius
    o=bpy.data.objects.new(name,data);sc.collection.objects.link(o);o.location=loc
    lamps.append({'x':loc[0]*25,'y':loc[1],'z':loc[2],'color':list(color),'energia':power})

def lamp(x,y,z,c=(1,.65,.32),power=95):
    box('aplique',(x,y,z),(.45,.4,.12),metal)
    bulb=mat('bombilla'+str(c), 'ffe1a1' if c[0]>.8 else 'a0cbd4',emit=4)
    box('difusor',(x,y,z-.09),(.25,.23,.06),bulb)
    light('luz interior',(x,y,z-.23),c,power)

def window(x,z):
    slab('hueco sombra',x-.5,x+.5,6.69,6.81,z+1.5,1.25,black)
    slab('cristal',x-.4,x+.4,6.64,6.68,z+1.6,1.05,glass)
    box('marco lateral',(x-.47,6.6,z+2.12),(.08,.13,1.25),dark)
    box('marco lateral',(x+.47,6.6,z+2.12),(.08,.13,1.25),dark)
    box('parteluz',(x,6.59,z+2.12),(.06,.12,1.2),metal)
    box('alfeizar',(x,6.45,z+1.48),(1.15,.5,.12),concrete)

def bed(x,z,index,y=2.2):
    x=x/25
    box('sombra cama',(x,y,z+.12),(1.08,2.1,.2),dark)
    box('colchon',(x,y,z+.35),(.98,1.95,.25),linen)
    box('almohada',(x,y+.63,z+.52),(.72,.48,.14),linen)
    box('manta',(x,y-.26,z+.5),(.99,1.28,.12),cloths[index%4])
    for py in [y-1,y+1]:box('cabecero hierro',(x,py,z+.52),(1.05,.06,.85),metal)
    for px in [x-.45,x+.45]:
        for py in [y-.9,y+.9]:box('pata cama',(px,py,z+.17),(.07,.07,.34),metal)
    if index%3==0 and z<19:box('baul personal',(x,3.65,z+.23),(.85,.52,.45),wood)

def partition(x,z,wall):
    # Testero alto al fondo, tabique cortado delante: muestra grosor y deja ver al jugador.
    slab('tabique alto',x-.08,x+.08,4.8,6.85,z,3.6,wall)
    slab('tabique cortado',x-.08,x+.08,1.2,4.8,z,1.2,wall)
    slab('coronacion tabique',x-.11,x+.11,1.2,4.8,z+1.2,.08,concrete)

def stairs(z):
    # Dos tramos de doce escalones: contrahuella 0.20m / huella 0.25m.
    for flight in [0,1]:
        for i in range(12):
            y=.6+i*.25 if flight==0 else 3.6-(i+1)*.25
            height=(i+1)*.2 + flight*2.4
            x=19.6 if flight==0 else 21.2
            box('contrahuella',(x,y+.125,z+height-.1),(1.12,.25,.2),concrete)
            box('huella gastada',(x,y+.125,z+height+.025),(1.15,.27,.05),wood)
            box('zanca',(x+.59,y+.125,z+height-.15),(.08,.27,.4),metal)
            if i%3==0:
                box('barrote',(x+.59,y+.125,z+height+.52),(.045,.045,1),metal)
        # Viga diagonal portante real.
        x=19.6 if flight==0 else 21.2
        beam=box('zanca inclinada',(x-.59,2.1,z+(1.2 if flight==0 else 3.6)),(.08,3.85,.16),metal)
        beam.rotation_euler.x=math.atan2(2.4,3.0)*(1 if flight==0 else -1)
        rail=box('pasamanos',(x+.59,2.1,z+(2.2 if flight==0 else 4.6)),(.06,3.85,.06),wood)
        rail.rotation_euler.x=beam.rotation_euler.x
    slab('rellano',18.95,21.85,3.6,4.25,z+2.4,.16,concrete)

for floor,z in enumerate(FLOORS):
    wall=plaster[floor]
    # Plancher con hueco verdadero para la escalera central.
    areas=[(6,18.9,0,7),(21.85,31.6,0,7),(18.9,21.85,0,.65),(18.9,21.85,4.3,7)]
    if floor==0:areas=[(6,31.6,0,7)]
    for x0,x1,y0,y1 in areas:
        slab('losa',x0,x1,y0,y1,z-.23,.23,concrete)
        rows=int((y1-y0)/.34)
        for j in range(rows):
            for k in range(math.ceil((x1-x0)/2.4)):
                a=x0+k*2.4;b=min(x1,a+2.37)
                if b>a:slab('tabla de suelo',a,b,y0+j*.34,y0+j*.34+.32,z,.035,wood if floor!=1 else tile)
    slab('muro trasero',6,31.6,6.8,7,z,4.6,wall)
    # Pared lateral oeste en corte, poca altura para no ocultar el huerto.
    slab('pared cortada',6,6.2,0,6.8,z,.9,wall)
    slab('canto frontal',6,31.6,-.06,.08,z-.24,.24,dark,front)
    for wx in ([7.8,11.4,15.7,23.9,28.3] if floor%2==0 else [9,14,24.6,29]):window(wx,z)
    # Humedad y ladrillo visto en parches, con piezas a escala de mamposteria.
    for i in range(22):
        x=R.uniform(6.4,31.1);h=R.uniform(.12,.9)
        box('yeso saltado',(x,6.68,z+h),(.3+R.random()*.45,.06,.18),brick if i%4==0 else dark)
    if floor<4:
        stairs(z)
        lamp(20.4,2.0,z+2.7,(1,.48,.20),85)
    if floor>=2:
        for cama in LAYOUT['camas']:
            if cama['f']==floor:bed(cama['x'],z,cama['id'],cama['y'])
        dividers={2:[10.2,13.8,18.6,25.4],3:[9,12.6,16.2,23,26.6,30.2],4:[12,18.8,21.85,26.6]}[floor]
        for x in dividers:partition(x,z,wall)
        for x in ([8.3,15.5,24.1,29.3] if floor==2 else [10.8,16.3,23.6,28.7]):
            lamp(x,2.9,z+2.6,(1,.56,.27) if floor != 3 else (.55,.72,1),125 if floor==2 else 90)
        # Muebles y usos propios, evitando habitaciones clonadas.
        if floor==2:
            for x in [11.7,26.5]:
                box('taquilla',(x,3.7,z+.95),(.65,.6,1.9),metal)
                box('botiquin',(x+.8,3.9,z+1.7),(.6,.18,.7),linen)
                box('cruz',(x+.8,3.77,z+1.7),(.1,.05,.43),red)
        elif floor==3:
            for x in [8.3,12.2,16.2,24.8,29.4]:
                box('mesa escritorio',(x,4.6,z+.8),(1.1,.7,.12),wood)
                box('libro',(x,4.6,z+.91),(.35,.27,.07),book)
                box('silla',(x,4.0,z+.45),(.5,.55,.16),wood)
        else:
            # Cuatro dormitorios de cuatro camas; armarios al fondo y rellano amueblado.
            for i,room in enumerate(LAYOUT['habitaciones']):
                x=(room['x0']+room['x1'])/2
                box('armario habitacion',(x,6.45,z+.95),(1.05,.60,1.9),wood)
                box('puertas armario',(x,6.12,z+.95),(.98,.035,1.75),dark)
                for dx in [-.06,.06]:box('tirador',(x+dx,6.08,z+1.0),(.02,.04,.15),metal)
                lamp(x,3.7,z+2.7,(1,.62,.32) if i%2==0 else (.66,.78,1),120)
            box('sofa rellano',(20.35,5.8,z+.5),(2.1,.85,.65),cloths[2])
            box('respaldo rellano',(20.35,6.2,z+.9),(2.1,.17,.85),cloths[2])
            box('mesa rellano',(20.35,4.8,z+.46),(.9,.5,.12),wood)
            for x in [9,14.5,23.5,28.9]:
                viga=box('viga inclinada atico',(x,3.5,z+3.6),(.18,7,.20),dark)
                viga.rotation_euler.x=.12
    elif floor==0:
        # Cocina azulejada con cuatro puestos reales, campanas y fogones.
        for k in range(4):
            x=(235+k*16)/25
            box('mueble cocina',(x,2.4,z+.48),(.6,1,.95),metal)
            box('encimera',(x,2.4,z+1),(.63,1.04,.09),concrete)
            box('fogones',(x,2.4,z+1.07),(.43,.6,.04),black)
            box('olla',(x,2.55,z+1.22),(.25,.28,.3),metal)
            box('campana',(x,3.5,z+2.3),(.65,.75,.25),metal)
        partition(12.2,z,wall)
        for tx in [13.3,15.0,16.7]:
            box('mesa comedor',(tx,2.9,z+.85),(1.5,1.6,.15),wood)
            for dx in [-.55,.55]:
                for dy in [-.55,.55]:box('pata mesa',(tx+dx,2.9+dy,z+.42),(.1,.1,.85),dark)
            for dy in [-1.15,1.15]:box('banco',(tx,2.9+dy,z+.45),(1.5,.4,.18),wood)
            for dx in [-.35,.35]:box('plato',(tx+dx,2.9,z+.95),(.28,.28,.045),linen)
        box('frigorifico',(7.4,4.9,z+1.1),(.85,.8,2.2),pale)
        for k in range(3):
            box('estante despensa',(17.9,5.9,z+.5+k*.6),(1.4,.6,.08),wood)
            for i in range(4):box('conserva',(17.4+i*.32,5.8,z+.66+k*.6),(.18,.2,.3),cloths[i])
        partition(23,z,wall)
        box('banco taller',(25.6,2.7,z+.85),(3.5,1.1,.18),wood)
        box('panel herramientas',(25.6,5.7,z+1.9),(3.4,.18,1.2),metal)
        for x in [24.4,24.9,25.4,26.1,26.7]:box('herramienta',(x,5.5,z+1.8),(.05,.1,.6),concrete)
        for x in [24.3,26.9]:box('caballete',(x,2.7,z+.4),(.18,.85,.8),metal)
        lamp(10.3,2.8,z+2.8,(1,.72,.42),280)
        lamp(15.2,2.9,z+3.0,(1,.58,.27),220)
        lamp(25.8,3.5,z+3.2,(.55,.77,1),145)
        lamp(29.4,4.5,z+2.9,(1,.5,.22),60)
    else:
        # Clinica a la izquierda; salon/biblioteca; duchas a la derecha.
        partition(11.5,z,wall);partition(17.8,z,wall);partition(25,z,wall)
        for x in [7.7,9.5]:
            box('camilla',(x,1.9,z+.65),(1.15,2.1,.25),linen)
            box('base camilla',(x,1.9,z+.3),(.7,1.5,.6),metal)
        box('armario medico',(8.7,6.15,z+1.0),(1.7,.55,2),pale)
        box('cruz clinica',(8.7,5.8,z+1.25),(.14,.08,.8),red)
        box('cruz clinica',(8.7,5.8,z+1.25),(.65,.08,.14),red)
        for x in [13.2,16.2]:
            box('sofa',(x,3.6,z+.5),(1.6,1,.65),cloths[2])
            box('respaldo',(x,4.05,z+.9),(1.6,.18,.8),cloths[2])
        box('mesa salon',(14.7,2.4,z+.45),(1.2,.7,.12),wood)
        for zbook in [.5,1.2,1.9]:
            box('biblioteca',(15.1,6.15,z+zbook),(3.8,.55,.1),wood)
            for i in range(13):box('libro',(13.4+i*.27,6.05,z+zbook+.2),(.14,.3,.35),cloths[i%4])
        for x in [26.0,27.4,28.8]:
            slab('plato ducha',x,x+1.1,3.8,5.6,z,.08,pale)
            slab('separacion ducha',x,x+.06,3.8,6.3,z,2.0,tile)
            box('tubo ducha',(x+.55,6.5,z+1.55),(.05,.08,1.5),metal)
            box('alcachofa',(x+.55,6.25,z+2.25),(.3,.45,.07),metal)
        lamp(8.5,3.5,z+3,(.55,.85,.8),155)
        lamp(14.9,3.9,z+3,(1,.63,.3),110)
        lamp(27.5,4,z+3,(.5,.7,1),90)
    # Luz fria exterior desde las ventanas derechas; ocho posiciones jugables.
    if floor<4:
        for slot in [0,1]:
            x=31.6-.42;y=1.1+slot*2.1
            box('marco ventana defensa',(x+.42,y,z+1.5),(.1,1.0,2),dark)
            box('alfeizar defensa',(x+.15,y,z+.7),(.65,1.2,.12),wood)
        lamp(30.6,4.5,z+2.7,(.45,.62,.9),60)

# Tierra exterior y camino con sombras reales del edificio, sin un plano verde uniforme.
soil_ground=mat('suelo exterior','414a3e','222f2c',3)
# Fundir el limite del terreno con el fondo: evita el borde de una maqueta rectangular.
nodes=soil_ground.node_tree.nodes;links=soil_ground.node_tree.links
position=nodes.new('ShaderNodeNewGeometry');sep=nodes.new('ShaderNodeSeparateXYZ')
links.new(position.outputs['Position'],sep.inputs[0])
weights=[]
for axis,lo,hi in [('X',0,2),('X',51,49),('Y',-3,-1),('Y',8,6)]:
    ramp=nodes.new('ShaderNodeMapRange');ramp.clamp=True
    ramp.inputs['From Min'].default_value=lo;ramp.inputs['From Max'].default_value=hi
    links.new(sep.outputs[axis],ramp.inputs['Value']);weights.append(ramp.outputs['Result'])
factor=weights[0]
for weight in weights[1:]:
    mul=nodes.new('ShaderNodeMath');mul.operation='MULTIPLY'
    links.new(factor,mul.inputs[0]);links.new(weight,mul.inputs[1]);factor=mul.outputs[0]
transparent=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader')
links.new(factor,mix.inputs[0]);links.new(transparent.outputs[0],mix.inputs[1])
links.new(nodes.get('Principled BSDF').outputs[0],mix.inputs[2])
links.new(mix.outputs[0],nodes.get('Material Output').inputs['Surface'])

slab('terreno',0,51,-3,8,-.24,.15,soil_ground)
stone_ground=mat('piedra camino','646d61','394b47',8)
for i in range(29):
    x=32.8+i*.65
    if x<50.5:box('losa acceso',(x,.65,-.045),(.58,.78,.08),stone_ground)
for i in range(90):
    x=R.uniform(32,50.5);y=R.uniform(-1.7,7)
    box('grava',(x,y,-.035),(R.uniform(.04,.16),R.uniform(.04,.13),.06),concrete if i%3 else dark)
# Una luminaria de porche: deja caer luz fria sobre el primer tramo del patio.
lamp(31.7,1.0,3.0,(.54,.73,1),165)

# Polvo atmosferico con dispersion volumetrica real de Cycles.
volume=bpy.data.materials.new('polvo volumetrico');volume.use_nodes=True
nodes=volume.node_tree.nodes;nodes.clear()
out=nodes.new('ShaderNodeOutputMaterial');scatter=nodes.new('ShaderNodeVolumeScatter')
scatter.inputs['Color'].default_value=(.56,.64,.76,1)
scatter.inputs['Density'].default_value=.018
scatter.inputs['Anisotropy'].default_value=.28
volume.node_tree.links.new(scatter.outputs[0],out.inputs['Volume'])
box('volumen interior',(18.8,3.5,12),(25.6,7,24),volume)
for f in [1,3,4]:
    data=bpy.data.lights.new('haz ventana','SPOT');data.energy=160
    data.color=(.58,.73,1);data.spot_size=.72;data.spot_blend=.5
    luz=bpy.data.objects.new('haz ventana',data);sc.collection.objects.link(luz)
    luz.location=(10.5,6.45,FLOORS[f]+3.5)
    destino=Vector((12.0,.9,FLOORS[f]+.2))
    luz.rotation_euler=(destino-luz.location).to_track_quat('-Z','Y').to_euler()
# Cornisa y cubierta solo trasera: corte de muneca, sin tapar el interior.
box('cubierta',(18.8,6.9,24),(26.4,.7,.32),dark)
for x in [6,31.6]:box('pilar',(x,6.85,12),(.28,.35,24),brick)
# Luz lunar direccional rasante, sombras con rebote sobre muros y muebles.
sun=bpy.data.lights.new('Luna','SUN');sun.energy=.65;sun.color=(.45,.6,1);sun.angle=.12
obj=bpy.data.objects.new('Luna',sun);sc.collection.objects.link(obj);obj.rotation_euler=(.6,-.45,-.5)
# Camara consistente con proy(): screen=(10+12.5*(X cosA+Y sinA),260-12.5*(Z cosE+Y cosA sinE-X sinA sinE)).
right=Vector((math.cos(AZ),math.sin(AZ),0));up=Vector((-math.sin(AZ)*math.sin(EL),math.cos(AZ)*math.sin(EL),math.cos(EL)))
target=right*((320-10)/PPM)+up*((260-180)/PPM)
camd=bpy.data.cameras.new('Camara');camd.type='ORTHO';camd.ortho_scale=640/PPM
cam=bpy.data.objects.new('Camara',camd);sc.collection.objects.link(cam)
view=Vector((math.sin(AZ)*math.cos(EL),-math.cos(AZ)*math.cos(EL),math.sin(EL)))
cam.location=target+view*100;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();sc.camera=cam
# Metadatos compartidos; este script reconstruye la escena para futuros ajustes.
meta={'ppm':PPM,'elev':52,'azimut':10,'img':[640,360],'origen_px':[10,260],
      'pisos':FLOORS,'casa_x':[150,790],'capacidad':50,
      'camas':LAYOUT['camas'],
      'ventanas':[{'x':770-i*26,'y':1.1+i*2.1,'f':f} for f in range(4) for i in range(2)],'luces':lamps,
      'escalera':{'x0':490,'x1':530,'y0':.6,'y1':3.6,'escalones_por_tramo':12,'contrahuella':.2,'huella':.25}}
# Exportar huellas reales de muebles y tabiques para que la navegacion use la misma escena.
bpy.context.view_layer.update()
obstaculos=list(LAYOUT.get('obstaculos_base',LAYOUT['obstaculos']))
prefijos=('tabique','coronacion tabique','mesa','silla','sofa','respaldo','taquilla','armario','frigorifico','mueble cocina','banco','base camilla','baul personal','separacion ducha')
for o in main.objects:
    if o.type!='MESH' or not o.name.startswith(prefijos):continue
    vertices=[o.matrix_world @ Vector(v) for v in o.bound_box]
    zmin=min(v.z for v in vertices)
    f=max(0,min(4,int((zmin+.02)/4.8)))
    if zmin-FLOORS[f]>1.75:continue
    obstaculos.append({'x0':min(v.x for v in vertices),'x1':max(v.x for v in vertices),
                      'y0':min(v.y for v in vertices),'y1':max(v.y for v in vertices),'f':f,'tipo':o.name})
LAYOUT['obstaculos']=obstaculos
(OUT/'interiores.json').write_text(json.dumps(LAYOUT,indent=2)+'\n')
(OUT/'casa.json').write_text(json.dumps(meta,indent=2)+'\n')
front.hide_render=True
sc.render.filepath=str(OUT/'casa_atras.png');renderizar()
main.hide_render=True;front.hide_render=False
sc.cycles.samples=8
sc.render.filepath=str(OUT/'casa_delante.png');renderizar()
print('Metadatos de navegacion exportados.' if SOLO_DATOS else 'Refugio renderizado con volumen y 50 camas.',flush=True)

# Objetos cercanos con exactamente la misma camara; el arte lejano sigue en paralaje.
main.hide_render=True;front.hide_render=True
propcol=bpy.data.collections.new('Objeto');sc.collection.children.link(propcol)
key=bpy.data.lights.new('Cielo local','AREA');key.energy=350;key.color=(.55,.7,1);key.shape='DISK';key.size=6
keyobj=bpy.data.objects.new('Cielo local',key);sc.collection.objects.link(keyobj);keyobj.location=(-3,-4,8)
keyobj.rotation_euler=(Vector((0,0,0))-keyobj.location).to_track_quat('-Z','Y').to_euler()
def pb(name,loc,size,m):return box(name,loc,size,m,propcol)
def adopt(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    propcol.objects.link(o);return o

def resetprop():
    for o in list(propcol.objects):bpy.data.objects.remove(o,do_unlink=True)

def renderprop(name,w,h,pie):
    sc.render.resolution_x=w;sc.render.resolution_y=h
    camd.ortho_scale=w/PPM
    t=right*((w/2-pie[0])/PPM)+up*((pie[1]-h/2)/PPM)
    cam.location=t+view*100;cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.cycles.samples=64;sc.render.filepath=str(OUT/('prop_'+name+'.png'))
    renderizar()

paint=mat('pintura furgoneta','7f8a81','4f615c',5)
pb('chasis',(0,0,1.0),(5.2,1.8,1.0),paint)
pb('carga',(.8,0,1.8),(3.7,1.75,1.1),paint)
pb('cabina',(-1.8,0,1.6),(1.5,1.72,.95),paint)
pb('parabrisas',(-2.56,0,1.8),(.04,1.5,.55),glass)
pb('ventanilla',(-1.8,-.88,1.8),(1.2,.04,.55),glass)
pb('capo',(-2.3,0,1.3),(.6,1.8,.16),paint)
pb('parachoques',(-2.65,0,.7),(.18,1.92,.22),metal)
for x in [-1.65,1.65]:
    for y in [-.88,.88]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=.44,depth=.25,location=(x,y,.44),rotation=(math.pi/2,0,0))
        o=adopt(bpy.context.object);o.data.materials.append(black)
        pb('buje',(x,y-.14 if y<0 else y+.14,.44),(.2,.03,.2),metal)
for i in range(24):
    pb('oxido', (R.uniform(-1,2.5),-.91,R.uniform(.62,1.05)),(.15+R.random()*.3,.025,.07+R.random()*.15),rust)
for x in [-2.15,-1.5]:pb('faro',(x,-.91,1.13),(.26,.03,.17),linen)
renderprop('furgoneta',80,45,[40,39]);resetprop()

bark=mat('corteza','6d6656','34413b',6)
leaves=[mat('hojas'+str(i),h,h2,6) for i,(h,h2) in enumerate([('4a5d4a','263a30'),('5f6f4e','33452f'),('3d5348','253a34')])]
def branch(a,b,r):
    a=Vector(a);b=Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=r,radius2=r*.55,depth=(b-a).length,location=(a+b)/2)
    o=adopt(bpy.context.object);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(bark)
branch((0,0,0),(0,0,3.8),.25)
for i in range(16):
    ang=i*2.4;r=R.uniform(.35,1.35)
    pos=(math.cos(ang)*r,math.sin(ang)*r,R.uniform(3.1,5.0))
    if i%3==0:branch((0,0,2.2),pos,.1)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=pos)
    o=adopt(bpy.context.object);o.scale=(.8,.7,.65);o.data.materials.append(leaves[i%3])
renderprop('arbol',64,80,[32,74]);resetprop()
branch((0,0,0),(.06,.03,.5),.28);renderprop('tocon',32,32,[16,26]);resetprop()
soil=mat('tierra humeda','4e4638','27342c',9)
for state in ['listo','vacio']:
    pb('tierra',(0,0,.1),(1.6,1.2,.2),soil)
    for y in [-.62,.62]:pb('borde',(0,y,.15),(1.8,.1,.3),wood)
    for x in [-.86,.86]:pb('borde',(x,0,.15),(.1,1.3,.3),wood)
    if state=='listo':
        for x in [-.5,0,.5]:
            for y in [-.3,.3]:
                branch((x,y,.2),(x,y,.75),.025)
                for i in [-1,1]:
                    leaf=pb('hoja',(x+i*.12,y,.5),(.35,.08,.04),leaves[1]);leaf.rotation_euler.y=i*.5
                pb('fruto',(x+.04,y-.04,.7),(.12,.13,.14),red)
    renderprop('huerto_'+state,32,32,[16,26]);resetprop()
print('Objetos cercanos renderizados con elevacion de 52 grados.',flush=True)
