extends SubViewport
## Geometria 3D real de ventanas, tablas, balas, fogonazos y casquillos.
const PPM := 12.5
var raiz: Node3D
var tablas := {}
var estado := {}
var efectos: Array = []
var rng := RandomNumberGenerator.new()
var madera: ShaderMaterial
var metal: StandardMaterial3D
var laton: StandardMaterial3D
var fuego: StandardMaterial3D

func material(color: Color, emision: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	if emision > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emision
	return m

func _ready() -> void:
	size = Vector2i(1280,720)
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	raiz = Node3D.new()
	add_child(raiz)
	madera = ShaderMaterial.new()
	madera.shader = load("res://scripts/tabla.gdshader")
	metal = material(Color("343c3e"))
	laton = material(Color("a48c50"), 0.1)
	laton.metallic = 0.7
	fuego = material(Color("ffd08a"), 4.0)
	var ambiente := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("7b8a9b")
	entorno.ambient_light_energy = 0.22
	ambiente.environment = entorno
	raiz.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-42,-28,0)
	luz.light_color = Color("adc5df")
	luz.light_energy = 0.7
	luz.shadow_enabled = true
	raiz.add_child(luz)
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/casa.json"))
	var e := deg_to_rad(float(datos.get("elev",52.0)))
	var a := deg_to_rad(float(datos.get("azimut",10.0)))
	var origen: Array = datos.get("origen_px",[10,260])
	var derecha := Vector3(cos(a),0,-sin(a))
	var arriba := Vector3(-sin(a)*sin(e),cos(e),-cos(a)*sin(e))
	var objetivo: Vector3 = derecha * ((320.0-origen[0])/PPM) + arriba * ((origen[1]-180.0)/PPM)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.keep_aspect = Camera3D.KEEP_HEIGHT
	camara.size = 360.0 / PPM
	camara.far = 200
	raiz.add_child(camara)
	camara.position = objetivo + Vector3(sin(a)*cos(e),sin(e),cos(a)*cos(e))*100
	camara.look_at(objetivo)
	camara.current = true

func cubo(padre: Node3D, pos: Vector3, tam: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.material_override = mat
	padre.add_child(m)
	m.position = pos
	return m

func crear_ventana(b: Dictionary) -> void:
	if b.f != 0:return
	var marco := Node3D.new()
	raiz.add_child(marco)
	# Ambas ventanas estan en el mismo plano de la pared este, sin chaflan ni marco saliente.
	marco.position = Vector3(b.x/25.0+0.005, Sim.PISO_Y[b.f], -b.y)
	marco.rotation.y = PI/2.0
	var piezas: Array = []
	for i in range(5):
		var pieza := cubo(marco,Vector3(0,[0.65,1.05,1.45,1.85,2.25][i],0),Vector3(0.94,0.15,0.035),madera)
		pieza.rotation.z = [-0.04,0.035,-0.025,0.04,-0.03][i]
		for lado in [-0.40,0.40]:
			cubo(pieza,Vector3(lado,0,0.025),Vector3(0.035,0.035,0.015),metal)
		piezas.append(pieza)
	tablas[b.id] = piezas
	var luz := OmniLight3D.new()
	marco.add_child(luz)
	luz.position = Vector3(-0.5,2.4,1.8)
	luz.light_color = Color("e7b17a")
	luz.light_energy = 0.35
	luz.omni_range = 4

func actualizar(defensas: Array, dt: float) -> void:
	var cambio := false
	for b in defensas:
		if b.f != 0:continue
		if not tablas.has(b.id):
			crear_ventana(b)
		var n := ceili(b.hp / Sim.TABLA_HP)
		if estado.get(b.id,-1) != n:
			for i in range(5): tablas[b.id][i].visible = i < n
			estado[b.id] = n
			cambio = true
	var vivas: Array = []
	for fx in efectos:
		if fx.nuevo:
			fx.nuevo = false
		else:
			fx.t += dt
		if fx.t >= fx.dur:
			fx.nodo.queue_free()
			continue
		var t: float = fx.t
		if fx.tipo == "bala":
			fx.nodo.position = fx.a.lerp(fx.b, minf(1,t/fx.dur))
		elif fx.tipo == "casquillo":
			fx.nodo.position = fx.a + fx.v*t + Vector3(0,-4.9*t*t,0)
			fx.nodo.rotation += Vector3(7,4,3)*dt
			if fx.nodo.position.y < fx.suelo:
				fx.nodo.position.y = fx.suelo
		elif fx.tipo == "impacto":
			fx.nodo.scale = Vector3.ONE*(0.5+t*5)
		vivas.append(fx)
	efectos = vivas
	if cambio or not efectos.is_empty() or dt > 0:
		render_target_update_mode = SubViewport.UPDATE_ONCE

func agregar(nodo: Node3D, tipo: String, pos: Vector3, duracion: float, datos: Dictionary = {}) -> void:
	raiz.add_child(nodo)
	nodo.position = pos
	var fx := {"nodo":nodo,"tipo":tipo,"a":pos,"t":0.0,"dur":duracion,"nuevo":true}
	fx.merge(datos)
	efectos.append(fx)
	while efectos.size()>128:
		var viejo: Dictionary = efectos.pop_front()
		viejo.nodo.queue_free()

func disparar(e: Dictionary) -> void:
	var a := Vector3(e.x0/25.0,e.z0,-e.d0)
	var clave: String="s%d"%e.get("origen",-1)
	if actores.has(clave) and is_instance_valid(actores[clave].boca):
		a=actores[clave].boca.global_position
	var b := Vector3(e.x1/25.0,e.z1,-e.d1)
	var direccion := (b-a).normalized()
	var bala := MeshInstance3D.new()
	var forma := CapsuleMesh.new()
	forma.radius = 0.014
	forma.height = 0.08
	bala.mesh = forma
	bala.material_override = laton
	bala.quaternion = Quaternion(Vector3.UP,direccion)
	agregar(bala,"bala",a,0.055,{"b":b})
	var flash := Node3D.new()
	var cono := cubo(flash,Vector3.ZERO,Vector3(0.06,0.08,0.20),fuego)
	cono.quaternion = Quaternion(Vector3.FORWARD,direccion)
	var luz := OmniLight3D.new()
	flash.add_child(luz)
	luz.light_color = Color("ffba66")
	luz.light_energy = 1.8
	luz.omni_range = 2.0
	agregar(flash,"flash",a,0.045)
	var vaina := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius=0.025; cilindro.bottom_radius=0.025; cilindro.height=0.09
	vaina.mesh=cilindro; vaina.material_override=laton
	agregar(vaina,"casquillo",a- direccion*0.4,0.75,{"v":Vector3(rng.randf_range(-0.8,0.5),1.2,rng.randf_range(0.5,1.1)),"suelo":floorf(a.y/4.8)*4.8+0.03})
	var impacto := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius=0.06; esfera.height=0.12
	impacto.mesh=esfera; impacto.material_override=material(Color("806f59"))
	agregar(impacto,"impacto",b,0.16)


func limpiar_efectos() -> void:
	for fx in efectos:
		fx.nodo.queue_free()
	efectos.clear()
	render_target_update_mode = SubViewport.UPDATE_ONCE

var cajas_municion := {}
var actores := {}
var luces_actores_creadas := false
func luces_actores() -> void:
	if luces_actores_creadas:return
	luces_actores_creadas=true
	var datos: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://arte/casa.json"))
	for fuente in datos.get("luces",[]):
		var luz:=OmniLight3D.new();raiz.add_child(luz)
		luz.position=Vector3(fuente.x/25.0,fuente.z,-fuente.y)
		luz.light_color=Color(fuente.color[0],fuente.color[1],fuente.color[2])
		luz.light_energy=fuente.energia*.006
		luz.light_cull_mask=1<<(int(fuente.z/4.8)+1)
		luz.omni_range=5.5
		luz.shadow_enabled=false
	var sombra:=ShaderMaterial.new();sombra.shader=load("res://scripts/sombra_actor.gdshader")
	for altura in Sim.PISO_Y:
		var plano:=MeshInstance3D.new();var m:=PlaneMesh.new();m.size=Vector2(25.6,7)
		plano.mesh=m;plano.material_override=sombra;raiz.add_child(plano)
		plano.position=Vector3(18.8,altura-.015,-3.5)
		plano.layers=1<<(int(roundf(altura/4.8))+1)
func actualizar_cajas(cajas: Array) -> void:
	for c in cajas:
		if cajas_municion.has(c.puesto):continue
		var caja := Node3D.new()
		raiz.add_child(caja)
		caja.position=Vector3((c.x+6.0)/25.0,Sim.PISO_Y[c.f],-c.y)
		# Caja baja, mate y apoyada en el suelo; sin indicadores flotantes.
		cubo(caja,Vector3(0,.17,0),Vector3(.46,.34,.64),metal)
		cubo(caja,Vector3(0,.35,0),Vector3(.48,.04,.66),metal)
		for lado in [-1,1]:
			cubo(caja,Vector3(lado*.15,.18,.325),Vector3(.025,.26,.025),laton)
		for m in caja.find_children("*","MeshInstance3D",true,false):m.layers=1<<(c.f+1)
		cajas_municion[c.puesto]=caja


func actualizar_actores(sim: Sim, dt: float) -> void:
	luces_actores()
	actualizar_cajas(sim.cajas)
	var vivos: Dictionary={}
	for s in sim.supervivientes:
		var clave: String="s%d"%s.id
		vivos[clave]=true
		if not actores.has(clave):
			var actor:=preload("res://scripts/actor_3d.gd").new();raiz.add_child(actor);actor.crear(s,false);actores[clave]=actor
		actores[clave].actualizar(s,dt,sim.camas())
	for z in sim.zombis:
		var clave: String="z%d"%z.id
		vivos[clave]=true
		if not actores.has(clave):
			var actor:=preload("res://scripts/actor_3d.gd").new();raiz.add_child(actor);actor.crear(z,true);actores[clave]=actor
		actores[clave].actualizar(z,dt,sim.camas())
	for e in sim.cadaveres:
		var clave: String=e.get("id","")
		if not actores.has(clave) and clave!="":
			var ficha: Dictionary={"x":e.x,"y":e.y,"vy":e.z,"f":int(roundf(e.z/4.8)),"dir":e.dir,"tipo":e.tipo,"camisa":e.get("camisa",0),"look":e.get("look",0),"modelo_arma":e.get("modelo_arma","Pistola"),"anim":0.0,"camina":false,"accion":"","llego":false,"tiempo_tiro":10.0,"retroceso":0.0,"recarga":0.0,"cama_id":-1}
			var actor:=preload("res://scripts/actor_3d.gd").new();raiz.add_child(actor);actor.crear(ficha,not e.surv);actor.actualizar(ficha,0,sim.camas());actores[clave]=actor
		if actores.has(clave):
			vivos[clave]=true
			actores[clave].cadaver(e)
	for clave in actores.keys():
		if not vivos.has(clave):actores[clave].queue_free();actores.erase(clave)
	render_target_update_mode=SubViewport.UPDATE_ONCE
