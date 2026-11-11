extends Node3D
## Actor articulado en metros, sin sprites ni armas dibujadas en 2D.
static var materiales := {}
static var mallas := {}
var modelo: Node3D
var torso: Node3D
var cabeza: Node3D
var arma: Node3D
var boca: Node3D
var huesos := {}
var manos: Array = []
var pies: Array = []
var rodillas: Array = []
var codos: Array = []
var anterior := Vector3.ZERO
var iniciado := false
var infectado := false
var tipo := ""
var piel: StandardMaterial3D
var camisa: StandardMaterial3D
var pantalon: StandardMaterial3D
var bota: StandardMaterial3D
var metal: StandardMaterial3D
var madera: StandardMaterial3D
var arma_modelo := ""
var descanso := 0.0
var cama_descanso := {}
var capa_actual := -1
var utensilios: Node3D
var martillo: Node3D
var cuchara: Node3D
var plato: Node3D

func mat(h: String, metalico: bool = false) -> StandardMaterial3D:
	var clave:=h+str(metalico)
	if not materiales.has(clave):
		var m:=StandardMaterial3D.new()
		m.albedo_color=Color(h);m.roughness=.78 if not metalico else .38
		m.metallic=.7 if metalico else 0
		materiales[clave]=m
	return materiales[clave]
func mesh(clase: String) -> Mesh:
	if not mallas.has(clase):
		if clase=="caja":
			var m:=BoxMesh.new();m.size=Vector3.ONE;mallas[clase]=m
		elif clase=="torso":
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var perfiles: Array=[Vector3(-.275,.18,.12),Vector3(-.10,.19,.13),Vector3(.13,.235,.15),Vector3(.235,.24,.13),Vector3(.30,.075,.07)]
			for j in range(perfiles.size()-1):
				for i in range(16):
					var a0:=TAU*i/16.0;var a1:=TAU*(i+1)/16.0
					var p: Vector3=perfiles[j];var q: Vector3=perfiles[j+1]
					var v0:=Vector3(cos(a0)*p.y,p.x,sin(a0)*p.z)
					var v1:=Vector3(cos(a1)*p.y,p.x,sin(a1)*p.z)
					var v2:=Vector3(cos(a1)*q.y,q.x,sin(a1)*q.z)
					var v3:=Vector3(cos(a0)*q.y,q.x,sin(a0)*q.z)
					for v in [v0,v2,v1,v0,v3,v2]:st.add_vertex(v)
			st.generate_normals();mallas[clase]=st.commit()
		elif clase=="esfera":
			var m:=SphereMesh.new();m.radius=1;m.height=2;m.radial_segments=12;m.rings=6;mallas[clase]=m
		else:
			var m:=CylinderMesh.new();m.top_radius=1;m.bottom_radius=1;m.height=1;m.radial_segments=10;mallas[clase]=m
	return mallas[clase]
func pieza(padre: Node3D, clase: String, pos: Vector3, tam: Vector3, material: Material) -> MeshInstance3D:
	var o:=MeshInstance3D.new();o.mesh=mesh(clase);o.material_override=material
	padre.add_child(o);o.position=pos;o.scale=tam
	return o
func crear(s: Dictionary, zombi: bool) -> void:
	infectado=zombi;tipo=s.get("tipo","")
	var tonos: Array=["d6ac89","b27f61","805b48"]
	piel=mat(["7b8b71","989977","657861"][0 if tipo=="normal" else 1 if tipo=="corredor" else 2] if infectado else tonos[int(s.get("look",0))%3])
	var colores: Array=["596e74","995f43","6e7b54","795c72","9c8453","466c79","97535a","969487"]
	camisa=mat("514f4d" if infectado else colores[int(s.get("camisa",0))%8]);pantalon=mat("303b44");bota=mat("252a2b")
	metal=mat("566369",true);madera=mat("79513b")
	modelo=Node3D.new();add_child(modelo)
	pieza(modelo,"esfera",Vector3(0,.84,0),Vector3(.18,.13,.13),pantalon)
	torso=Node3D.new();modelo.add_child(torso);torso.position=Vector3(0,1.14,0)
	pieza(torso,"torso",Vector3.ZERO,Vector3.ONE,camisa)
	pieza(modelo,"cilindro",Vector3(0,.84,0),Vector3(.19,.065,.145),bota)
	pieza(modelo,"caja",Vector3(0,.84,-.15),Vector3(.045,.045,.02),metal)
	for lado in [-1,1]:
		pieza(torso,"caja",Vector3(lado*.11,.04,-.135),Vector3(.13,.13,.025),camisa)
	pieza(modelo,"cilindro",Vector3(0,1.49,0),Vector3(.065,.14,.065),piel)
	cabeza=Node3D.new();modelo.add_child(cabeza);cabeza.position=Vector3(0,1.64,-.01)
	pieza(cabeza,"esfera",Vector3.ZERO,Vector3(.115,.145,.115),piel)
	pieza(cabeza,"esfera",Vector3(0,.07,.018),Vector3(.118,.085,.108),mat("34302e" if infectado else ["332b28","6d513b","9a8c6d"][int(s.get("look",0))%3]))
	pieza(cabeza,"esfera",Vector3(0,-.01,-.115),Vector3(.025,.032,.04),piel)
	for lado in [-1,1]:
		pieza(cabeza,"esfera",Vector3(lado*.11,-.01,.005),Vector3(.022,.036,.019),piel)
		pieza(cabeza,"esfera",Vector3(lado*.043,.025,-.111),Vector3(.012,.009,.009),mat("a2a88c" if infectado else "292d2e"))
		for nombre in ["muslo","pierna","brazo","antebrazo"]:
			var material:=pantalon if nombre in ["muslo","pierna"] else camisa if nombre=="brazo" else piel
			huesos[nombre+str(lado)]=pieza(modelo,"cilindro",Vector3.ZERO,Vector3.ONE,material)
		var mano:=pieza(modelo,"esfera",Vector3.ZERO,Vector3(.046,.06,.045),piel)
		pieza(mano,"esfera",Vector3(lado*.75,-.1,0),Vector3(.35,.5,.35),piel)
		manos.append(mano)
		rodillas.append(pieza(modelo,"esfera",Vector3.ZERO,Vector3(.074,.074,.074),pantalon))
		codos.append(pieza(modelo,"esfera",Vector3.ZERO,Vector3(.058,.058,.058),camisa))
		pies.append(pieza(modelo,"esfera",Vector3.ZERO,Vector3(.065,.045,.125),bota))
	if infectado:
		pieza(torso,"caja",Vector3(.07,0,-.145),Vector3(.12,.22,.02),mat("613538"))
		for i in range(3):pieza(torso,"caja",Vector3(.07,-.06+i*.06,-.16),Vector3(.115,.018,.015),mat("b3a18b"))
		if tipo=="bruto":scale=Vector3(1.22,1.15,1.18)
		elif tipo=="corredor":scale=Vector3(.9,1,.9)
	else:
		crear_arma(s.get("modelo_arma","Pistola"))
		utensilios=Node3D.new();modelo.add_child(utensilios)
		martillo=Node3D.new();utensilios.add_child(martillo)
		pieza(martillo,"cilindro",Vector3(0,.05,0),Vector3(.018,.25,.018),madera)
		pieza(martillo,"caja",Vector3(0,.18,0),Vector3(.16,.055,.065),metal)
		cuchara=Node3D.new();utensilios.add_child(cuchara)
		pieza(cuchara,"cilindro",Vector3(0,.06,0),Vector3(.009,.22,.009),madera)
		pieza(cuchara,"esfera",Vector3(0,.18,0),Vector3(.035,.05,.015),madera)
		plato=pieza(utensilios,"esfera",Vector3.ZERO,Vector3(.11,.015,.11),mat("b6b5a5"))
		utensilios.visible=false
func crear_arma(nombre: String) -> void:
	if is_instance_valid(arma):arma.queue_free()
	arma_modelo=nombre;arma=Node3D.new();modelo.add_child(arma)
	arma.position=Vector3(.13,1.18,-.26)
	if nombre=="Pistola":
		pieza(arma,"caja",Vector3(0,0,-.08),Vector3(.045,.065,.22),metal)
		pieza(arma,"caja",Vector3(0,-.075,0),Vector3(.05,.11,.065),bota)
	else:
		var ak:=nombre=="AK"
		pieza(arma,"caja",Vector3(0,0,-.14),Vector3(.065,.09,.32),metal)
		pieza(arma,"caja",Vector3(0,-.01,.15),Vector3(.055,.10,.27),madera if ak else bota)
		pieza(arma,"caja",Vector3(0,-.07,-.10),Vector3(.05,.12,.055),madera if ak else bota)
		pieza(arma,"caja",Vector3(0,0,-.36),Vector3(.07,.075,.23),madera if ak else bota)
		var tubo:=pieza(arma,"cilindro",Vector3(0,.015,-.56),Vector3(.018,.30,.018),metal);tubo.rotation.x=PI/2
		for i in range(3):
			var mag:=pieza(arma,"caja",Vector3(0,-.09-i*.045,-.21-i*.012),Vector3(.05,.055,.095),metal)
			mag.rotation.x=(i*.18 if ak else .10)
	boca=Node3D.new();arma.add_child(boca);boca.position=Vector3(0,.015,-.73 if nombre!="Pistola" else -.20)
	if capa_actual>=0:
		for m in arma.find_children("*","MeshInstance3D",true,false):m.layers=1<<(capa_actual+1)
func hueso(nombre: String, a: Vector3, b: Vector3, radio: float) -> void:
	var o: Node3D=huesos[nombre];o.position=(a+b)*.5
	o.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	o.scale=Vector3(radio,a.distance_to(b),radio)
func actualizar(s: Dictionary, dt: float, camas: Array) -> void:
	if capa_actual!=s.f:
		capa_actual=s.f
		for m in modelo.find_children("*","MeshInstance3D",true,false):m.layers=1<<(capa_actual+1)
	var pos:=Vector3(s.x/25.0,s.vy,-s.y)
	var desplazamiento:=pos-anterior
	position=pos
	var rumbo: float=-PI/2 if s.dir>0 else PI/2
	if iniciado and s.camina and Vector2(desplazamiento.x,desplazamiento.z).length()>.001:rumbo=atan2(-desplazamiento.x,-desplazamiento.z)
	rotation.y=lerp_angle(rotation.y,rumbo,minf(1,dt*12)) if iniciado else rumbo
	anterior=pos;iniciado=true
	var fase: float=s.anim*TAU/8.0
	var caminando: bool=s.camina
	var andando:=1.0 if caminando else 0.0
	var ataque: bool=s.get("atac",0.0)>0 if infectado else s.accion in ["disparar","luchar"] or s.tiempo_tiro<.3
	var retroceso: float=s.get("retroceso",0.0)
	var trabajando: bool=not infectado and s.llego and not ataque and s.accion in ["cocinar","comer","reparar","cultivar","talar"]
	var recargando: bool=not infectado and s.recarga>0
	var durmiendo: bool=not infectado and s.accion=="dormir" and s.llego and s.cama_id>=0
	modelo.position=Vector3(0,absf(sin(fase*2))*.025*andando,0)
	modelo.rotation=Vector3(-.15 if infectado else 0,0,0)
	cabeza.rotation.x=(.08*sin(fase) if infectado else 0)
	modelo.rotation.z=float(s.get("golpe",0.0))*.8
	torso.position.z=float(s.get("golpe",0.0))*.3
	if not infectado:
		if s.modelo_arma!=arma_modelo:crear_arma(s.modelo_arma)
		arma.position=Vector3(.13,1.18,-.26+retroceso*.06)
		arma.rotation=Vector3(-.55 if not ataque else retroceso*.10,0,0)
		if ataque:
			var objetivo:=Vector3(s.apunta_x/25.0,s.apunta_z,-s.apunta_y)-pos
			rotation.y=atan2(-objetivo.x,-objetivo.z)
			var pitch:=atan2(objetivo.y-1.2,Vector2(objetivo.x,objetivo.z).length())
			arma.rotation.x=pitch+retroceso*.10;cabeza.rotation.x=pitch*.6
		if recargando:arma.rotation.x=-.6-sin(s.recarga*3)*.2
		if trabajando:arma.position=Vector3(0,1.1,.20);arma.rotation.x=-PI/2
	for i in range(2):
		var lado: int=-1 if i==0 else 1
		var ciclo:=fase+i*PI
		var cadera:=Vector3(lado*.105,.83,0)
		var pie:=Vector3(lado*.105,.065+maxf(0,sin(ciclo))*.12*andando,cos(ciclo)*.23*andando-.03)
		var rodilla:=(cadera+pie)*.5+Vector3(0,.01,-.09-absf(sin(ciclo))*.05*andando)
		hueso("muslo"+str(lado),cadera,rodilla,.075)
		hueso("pierna"+str(lado),rodilla,pie,.058)
		pies[i].position=pie+Vector3(0,-.01,-.055)
		rodillas[i].position=rodilla
		var hombro:=Vector3(lado*.23,1.39,0)
		var mano:=Vector3(lado*.26,.91,-cos(ciclo)*.18*andando)
		if infectado:mano=Vector3(lado*.20,1.12+sin(fase*2)*.06,-.42-(.20*maxf(0,sin(fase*2)) if ataque else 0))
		elif ataque or recargando:mano=Vector3(.14 if i==1 else -.03,1.17-retroceso*.04,-.27 if i==1 else (-.31 if s.get("modelo_arma","")=="Pistola" else -.63))
		elif not trabajando:mano=Vector3(.14 if i==1 else -.03,1.05,-.22 if i==1 else (-.25 if s.get("modelo_arma","")=="Pistola" else -.47))
		if trabajando:mano=Vector3(lado*.12,1.03+sin(fase*3)*.1,-.35)
		if recargando and i==0:mano=Vector3(.10,.9+sin(s.recarga*4)*.1,-.4)
		if durmiendo:mano=Vector3(lado*.20,.95,-.02)
		var codo:=(hombro+mano)*.5+Vector3(lado*.09,-.09,.05)
		codos[i].position=codo
		hueso("brazo"+str(lado),hombro,codo,.058)
		hueso("antebrazo"+str(lado),codo,mano,.043)
		manos[i].position=mano
	if not infectado:
		utensilios.visible=trabajando
		utensilios.position=manos[1].position
		utensilios.rotation.x=sin(fase*3)*.5
		martillo.visible=s.accion in ["reparar","talar","cultivar"]
		cuchara.visible=s.accion=="cocinar"
		plato.visible=s.accion=="comer"
	if not infectado:
		descanso=move_toward(descanso,1.0 if durmiendo else 0.0,dt*2.0)
		if durmiendo:cama_descanso=camas[s.cama_id]
		if descanso>0 and not cama_descanso.is_empty():
			var cama: Dictionary=cama_descanso
			var sobre_cama:=Vector3(cama.x/25.0,Sim.PISO_Y[cama.f]+.71,-(cama.y-.85))
			position=position.lerp(sobre_cama,descanso)
			rotation.y=lerp_angle(rotation.y,0,descanso)
			modelo.rotation=Vector3(-PI/2*descanso,0,0);modelo.position=Vector3.ZERO
		arma.visible=descanso<.05

func cadaver(e: Dictionary) -> void:
	position=Vector3(e.x/25.0,e.z+.12,-e.y)
	rotation.y=-PI/2 if e.dir>0 else PI/2
	modelo.rotation=Vector3(0,0,-minf(1,e.t/.45)*PI/2)
