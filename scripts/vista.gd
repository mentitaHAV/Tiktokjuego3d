extends Node2D
## Pixel art: lienzo 640x360 escalado x2, camara elevada (52 grados, azimut 10 grados).
## Huerto protegido al oeste; casa central de cinco plantas; invasion por el este. Sprites pixel art (tools/sprites_pixel.py, arte/).
## Proyeccion ortografica compartida con blender/refugio.py: elevacion 52°, azimut 10°.
##   x = coordenada de la simulacion (px, 25 px = 1 m);  Y = profundidad en m;  Z = altura en m.
##
## Teclas: R rosa/zombis | T GG de Tester | G GG de un usuario nuevo | 1-4 velocidad | Espacio pausa

const RUTA_EVENTOS := "res://eventos.jsonl"
const RUTA_HISTORIAL := "res://datos/historial.json"
const NOMBRES_PRUEBA := ["Ana", "Luis", "Marta", "Pepe", "Sofi", "Rafa", "Lola", "Toño", "Vero", "Dani", "Nina", "Hugo"]
const GY := 260.0
const ELEVACION := deg_to_rad(52.0)
const AZIMUT := deg_to_rad(10.0)
const PPM := 12.5
const FR := 32
const PIE := Vector2(16.0, 25.0)
const SANGRE := [Color("8a0f0f"), Color("a31515"), Color("5c0a0a"), Color("c21c1c")]

var sim: Sim
var fuente: Font
var fuente_titulo: Font
var vel_juego := 1
var pausa := false
var pos_eventos := 0
var t_eventos := 0.0
var guardados := 0
var estrellas: Array = []
var captura_ruta := ""
var captura_en := -1.0
var t_real := 0.0
var t_anim := 0.0
var cache := {}
var bocas_arma := {}
var ventanas_3d: SubViewport
var props_meta := {}
var luces_interiores: Array = []
var hierba: Array = []
var parts: Array = []        # particulas de gore en vuelo
var manchas: Array = []      # sangre persistente en el suelo
var gen_vista := 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sim = Sim.new()
	ventanas_3d = preload("res://scripts/ventanas_3d.gd").new()
	add_child(ventanas_3d)
	sim.cargar_historial(RUTA_HISTORIAL)
	guardados = sim.historial.size()
	gen_vista = sim.gen
	var pixel: FontFile = load("res://arte/fuentes/PixelifySans.ttf")
	pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel.fallbacks = [ThemeDB.fallback_font]
	var cuerpo := FontVariation.new()
	cuerpo.base_font = pixel
	cuerpo.variation_opentype = {"wght": 500}
	fuente = cuerpo
	var titulo := FontVariation.new()
	titulo.base_font = pixel
	titulo.variation_opentype = {"wght": 700}
	fuente_titulo = titulo
	rng.seed = 7
	for i in range(50):
		estrellas.append(Vector2(rng.randf_range(0, 640), rng.randf_range(30, 220)))
	for i in range(220):
		hierba.append([rng.randf_range(0, 640), rng.randf_range(250, 360), rng.randi() % 3])
	var f := FileAccess.open("res://arte/props.json", FileAccess.READ)
	if f:
		props_meta = JSON.parse_string(f.get_as_text())
	var casa := FileAccess.open("res://arte/casa.json", FileAccess.READ)
	if casa:
		var datos: Dictionary = JSON.parse_string(casa.get_as_text())
		luces_interiores = datos.get("luces", [])
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			_demo(700, 210, 1)
		elif a == "--demo-armas":
			_demo_50(true)
		elif a == "--demo-50":
			_demo_50()
		elif a == "--demo-hogar":
			_demo_hogar()
		elif a == "--demo-dia":
			_demo(300, 200, 2)
		elif a.begins_with("--captura="):
			captura_en = float(a.substr(10))
		elif a.begins_with("--salida="):
			captura_ruta = a.substr(9)
		elif a.begins_with("--vel="):
			vel_juego = int(a.substr(6))


func _demo_hogar() -> void:
	# Escena de inspeccion: necesidades distintas, IA normal y sin ataque inicial.
	sim.config.ambiente = false
	sim.stock.madera = 0
	sim.stock.comida = 0
	sim.stock.crudo = 4
	for recurso in sim.arboles + sim.huertos:
		recurso.listo = 600.0
	for n in ["Ana", "Luis", "Marta", "Pepe", "Sofi", "Rafa"]:
		sim.aplicar_regalo(n, "GG", 1)
	for i in range(sim.supervivientes.size()):
		var s: Dictionary = sim.supervivientes[i]
		s.energia = 8.0 if i < 2 else 95.0
		s.hambre = 80.0 if i in [2, 3] else 10.0
	for i in range(250):
		sim.step(0.1)


func _demo(antes: int, despues: int, ggs: int) -> void:
	for n in ["Ana", "Luis", "Marta", "Pepe", "Sofi", "Rafa"]:
		sim.aplicar_regalo(n, "GG", 1)
	for i in range(antes):
		sim.step(0.1)
	for i in range(ggs):
		sim.aplicar_regalo("Luis", "Rose", 1)
	for i in range(despues):
		sim.step(0.1)
		_consumir_fx()
		_particulas(0.1)
		ventanas_3d.actualizar(sim.barreras, 0.1)


func _process(delta: float) -> void:
	t_real += delta
	if not pausa:
		t_anim += delta * vel_juego
		var restante := delta * vel_juego
		while restante > 0.0:
			var paso := minf(restante, 0.1)
			sim.step(paso)
			restante -= paso
	ventanas_3d.actualizar_actores(sim,0.0 if pausa else delta*vel_juego)
	_consumir_fx()
	_particulas(delta)
	ventanas_3d.actualizar(sim.barreras, 0.0 if pausa else delta * vel_juego)
	if sim.gen != gen_vista:
		gen_vista = sim.gen
		manchas.clear()
		parts.clear()
		ventanas_3d.limpiar_efectos()
	t_eventos += delta
	if t_eventos >= 0.5:
		t_eventos = 0.0
		_leer_eventos()
	if sim.historial.size() != guardados:
		guardados = sim.historial.size()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://datos"))
		sim.guardar_historial(RUTA_HISTORIAL)
	if captura_en >= 0.0 and t_real >= captura_en:
		var img := get_viewport().get_texture().get_image()
		img.save_png(captura_ruta if captura_ruta != "" else "res://captura.png")
		get_tree().quit()
	queue_redraw()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_R:
				var n: String = NOMBRES_PRUEBA[randi() % NOMBRES_PRUEBA.size()] + str(randi() % 100)
				sim.aplicar_regalo(n, "Rose", 1)
			KEY_T:
				sim.aplicar_regalo("Tester", "GG", 1)
			KEY_G:
				var n: String = NOMBRES_PRUEBA[randi() % NOMBRES_PRUEBA.size()] + str(randi() % 1000)
				sim.aplicar_regalo(n, "GG", 1)
			KEY_1: vel_juego = 1
			KEY_2: vel_juego = 2
			KEY_3: vel_juego = 4
			KEY_4: vel_juego = 8
			KEY_SPACE: pausa = not pausa


func _leer_eventos() -> void:
	if not FileAccess.file_exists(RUTA_EVENTOS):
		return
	var f := FileAccess.open(RUTA_EVENTOS, FileAccess.READ)
	if f == null:
		return
	if f.get_length() < pos_eventos:
		pos_eventos = 0
	f.seek(pos_eventos)
	while not f.eof_reached():
		var linea := f.get_line().strip_edges()
		if linea == "":
			continue
		var d = JSON.parse_string(linea)
		if d is Dictionary and d.has("usuario") and d.has("regalo"):
			sim.aplicar_regalo(str(d.usuario), str(d.regalo), int(d.get("cantidad", 1)))
	pos_eventos = f.get_position()


# ======================================================================= gore procedural

func _consumir_fx() -> void:
	for e in sim.fx:
		if e.k == "disparo3d":
			ventanas_3d.disparar(e)
		else:
			_gore(e)
	sim.fx.clear()


func _gore(e: Dictionary) -> void:
	var pos := proy(e.x, e.y, e.z)
	var piso: float = floorf(float(e.z) / 4.8) * 4.8
	var suelo_y: float = proy(e.x, e.y, piso).y
	var vdir := float(e.dir)                 # dir de la simulacion +1 = hacia la izquierda de la pantalla
	var mata: bool = e.get("mata", false) or e.k == "muerte_s"
	var n := 10 if mata else 3
	var colores: Array = [Color("8b714a"), Color("bda077"), Color("5c543c")] if e.k == "tabla" else SANGRE
	for i in range(n):
		parts.append({
			"p": pos + Vector2(rng.randf_range(-2, 2), rng.randf_range(-3, 3)),
			"anterior": pos,
			"v": Vector2(vdir * rng.randf_range(8, 32) + rng.randf_range(-20, 20), rng.randf_range(-35, -8)),
			"suelo": suelo_y + rng.randf_range(-2.0, 3.0), "c": colores[rng.randi() % colores.size()],
			"s": 1 + rng.randi() % 2, "trozo": false,
		})
	while parts.size() > 180:
		parts.pop_front()
	if mata:
		# charco bajo el cuerpo
		for i in range(6):
			manchas.append([suelo_y + rng.randf_range(-1.0, 3.0), proy(e.x, e.y, 0.0).x + rng.randf_range(-5, 5), 1 + rng.randi() % 3, 1 + rng.randi() % 2, SANGRE[rng.randi() % SANGRE.size()]])
		_limitar_manchas()


func _limitar_manchas() -> void:
	while manchas.size() > 450:
		manchas.pop_front()


func _particulas(dt: float) -> void:
	if pausa:
		return
	dt *= vel_juego
	var vivas: Array = []
	for p in parts:
		p["anterior"] = p.p
		p.p += p.v * dt
		p.v.y += 190.0 * dt
		if p.p.y >= p.suelo:
			if p.trozo and absf(p.v.y) > 45.0:
				p.v.y *= -0.35
				p.v.x *= 0.6
				p.p.y = p.suelo - 0.5
				vivas.append(p)
			else:
				manchas.append([p.suelo, p.p.x, p.s + (1 if p.trozo else 0), 1 + (1 if p.trozo else 0), p.c])
				_limitar_manchas()
			continue
		vivas.append(p)
	parts = vivas


# ======================================================================= utilidades

func tex(nombre: String) -> Texture2D:
	if not cache.has(nombre):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://arte/" + nombre))
		cache[nombre] = ImageTexture.create_from_image(img) if img != null else null
	return cache[nombre]


func proy(x: float, y: float, z: float) -> Vector2:
	var mx := x / 25.0
	return Vector2(
		floorf(10.0 + PPM * (mx * cos(AZIMUT) + y * sin(AZIMUT))),
		floorf(GY - PPM * (z * cos(ELEVACION) + y * cos(AZIMUT) * sin(ELEVACION) - mx * sin(AZIMUT) * sin(ELEVACION))))


func _rc(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


func _texto(txt: String, x: float, y: float, col: Color, tam: int = 7, ancho: float = 80.0) -> void:
	# Mundo a escala x2; texto a resolucion de ventana para conservar legibilidad.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k := 2.0
	var t2 := int(round(tam * 2.3))
	var p := Vector2(floorf((x - ancho / 2.0) * k), floorf(y * k))
	var tipo := fuente_titulo if tam >= 7 else fuente
	draw_string_outline(tipo, p, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho * k, t2, 2, Color(0, 0, 0, 0.95))
	draw_string(tipo, p, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho * k, t2, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))


func _sprite_prop(nombre: String, pos: Vector2, mod: Color = Color.WHITE, escala: float = 1.0) -> void:
	var t := tex("prop_%s.png" % nombre)
	if t == null:
		return
	var m: Dictionary = props_meta.get(nombre, {"pie": [t.get_width() / 2.0, t.get_height() - 6.0]})
	var pie: Array = m.pie
	draw_texture_rect(t, Rect2((pos - Vector2(pie[0], pie[1]) * escala).floor(), t.get_size() * escala), false, mod)


func _sprite_hoja(nombre: String, col: int, fila: int, pos: Vector2, mod: Color = Color.WHITE, dy: float = 0.0) -> void:
	var t := tex(nombre)
	if t == null:
		return
	draw_texture_rect_region(t, Rect2((pos - PIE * Vector2(0.75, 0.625) + Vector2(0, dy)).floor(), Vector2(FR * 0.75, FR * 0.625)), Rect2(col * FR, fila * FR, FR, FR), mod)


# ======================================================================= escena

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	var osc := sim.oscuridad()
	_cielo(osc)
	_capas_fondo(osc)
	_suelo(osc)
	for m in manchas:
		_rc(m[1], m[0], m[2], m[3], m[4])
	for a in sim.arboles:
		_sprite_prop("arbol" if sim.t >= a.listo else "tocon", proy(a.x, a.y, 0.0), Color.WHITE, 0.65 if sim.t >= a.listo else 1.0)
	# Casa central, dibujada con las mismas coordenadas que la simulacion.
	var t_atras := tex("casa_atras.png")
	if t_atras:
		_capa_casa(t_atras)
	_luces_casa(osc)
	_malla_huerto(false)
	_almacen()
	bocas_arma.clear()
	_entidades()
	_malla_huerto(true)
	var t_del := tex("casa_delante.png")
	if t_del:
		_capa_casa(t_del)
	draw_texture_rect(ventanas_3d.get_texture(),Rect2(0,0,640,360),false)
	_vapor_cocina()
	_efectos()
	for humano in sim.supervivientes:
		_rotulo_humano(humano)
	var t_pp := tex("primer_plano.png")
	if t_pp:
		draw_texture(t_pp, Vector2(0, 315), Color(0.55, 0.5, 0.5, 1))
	# luz: oscuro y rojizo
	draw_rect(Rect2(0, 0, 640, 360), Color(0.005, 0.018, 0.036, 0.08 + osc * 0.15))

	_vineta()
	_hud()


func _capa_casa(t: Texture2D) -> void:
	draw_texture(t, Vector2.ZERO)


func _vineta() -> void:
	for i in range(6):
		var a := 0.07 * (6 - i)
		draw_rect(Rect2(0, i * 3, 640, 3), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 360 - (i + 1) * 3, 640, 3), Color(0, 0, 0, a))
		draw_rect(Rect2(i * 3, 0, 3, 360), Color(0, 0, 0, a))
		draw_rect(Rect2(640 - (i + 1) * 3, 0, 3, 360), Color(0, 0, 0, a))


func _cielo(osc: float) -> void:
	var arriba := Color("111b2a").lerp(Color("07060a"), osc)
	var abajo := Color("344452").lerp(Color("1c1418"), osc)
	for i in range(0, 260, 3):
		draw_rect(Rect2(0, i, 640, 3), arriba.lerp(abajo, float(i) / 260.0))
	if osc > 0.25:
		for e in estrellas:
			draw_rect(Rect2(e.x, e.y, 1, 1), Color(1, 0.9, 0.9, (osc - 0.25) * 1.1))
		draw_circle(Vector2(70, 60), 6.0, Color(0.9, 0.85, 0.8, osc))
	else:
		draw_circle(Vector2(lerpf(590, 40, clampf(sim.hora() / 0.6, 0, 1)), 66), 7.0, Color(0.95, 0.75, 0.6, 0.45))


func _capas_fondo(osc: float) -> void:
	var l := tex("fondo_lejos.png")
	if l:
		draw_texture(l, Vector2(0, 65), Color(0.62, 0.52, 0.54, 1).lerp(Color(0.25, 0.22, 0.26, 1), osc))
	draw_rect(Rect2(0, 190, 640, 30), Color(0.55, 0.42, 0.42, 0.22 * (1.0 - osc)))
	var m := tex("fondo_medio.png")
	if m:
		draw_texture(m, Vector2(0, 95), Color(0.4, 0.34, 0.36, 1).lerp(Color(0.16, 0.14, 0.17, 1), osc))


func _suelo(osc: float) -> void:
	var lejos := Color("283530").lerp(Color("14100e"), osc)
	var cerca := Color("141f22").lerp(Color("0b0807"), osc)
	for i in range(0, 171, 3):
		draw_rect(Rect2(0, 190 + i, 640, 3), lejos.lerp(cerca, float(i) / 171.0))
	# Camino de acceso gastado, juntas, grava y humedad con semilla estable.
	for i in range(18):
		var p := proy(810 + i * 24.0, 0.5, 0.0)
		_rc(p.x, p.y, 10, 4, Color("404a45").lerp(Color("202e30"), osc * 0.75))
		_rc(p.x + 1, p.y, 8, 1, Color("70776a").lerp(Color("283637"), osc * 0.8))
	for i in range(12):
		var x := float((i * 43 + 13) % 220 + 410)
		var y := float(331 + (i * 7) % 24)
		_rc(x, y, 5 + i % 4, 1, Color("304447").lerp(Color("16292d"), osc * 0.8))
	for h in hierba:
		var c := Color("55552f") if h[2] == 0 else Color("3f4a2a")
		draw_rect(Rect2(h[0], h[1], 1, 1), c.lerp(Color.BLACK, osc * 0.7))


# ======================================================================= entidades con profundidad

func _entidades() -> void:
	var lista: Array = []
	for z in sim.zombis:
		lista.append([z.y, "zombi", z])
	for s in sim.supervivientes:
		lista.append([s.y, "surv", s])
	for e in sim.cadaveres:
		lista.append([e.y, "cad", e])
	for h in sim.huertos:
		lista.append([h.y, "huerto", h])
	for tb in sim.tumbas:
		lista.append([tb.y, "tumba", tb])
	lista.append([3.9, "furgoneta", null])
	lista.sort_custom(func(a, b): return a[0] > b[0])
	for it in lista:
		match it[1]:
			"zombi": _zombi(it[2])
			"surv": _superviviente(it[2])
			"cad": _cadaver(it[2])
			"huerto":
				var h: Dictionary = it[2]
				_sprite_prop("huerto_listo" if sim.t >= h.listo else "huerto_vacio", proy(h.x, h.y, 0.0), Color.WHITE)
			"tumba":
				var tb: Dictionary = it[2]
				var pp := proy(tb.x, tb.y, 0.0)
				_sprite_prop("tumba", pp)
				_texto(str(tb.nombre).substr(0, 10), pp.x, pp.y + 7, Color(0.85, 0.8, 0.8, 0.8), 6, 40)
			"furgoneta":
				_sprite_prop("furgoneta", proy(1160.0, 3.9, 0.0), Color.WHITE)


func _superviviente(_s: Dictionary) -> void:
	pass # Se dibuja como modelo 3D articulado en ventanas_3d.


func _rotulo_humano(s: Dictionary) -> void:
	var pos := proy(s.x,s.y,s.vy)
	if s.accion == "dormir" and s.llego:
		_texto("z", pos.x + 5, pos.y - 19, Color.WHITE, 7, 8)
	var estrellitas := ""
	for i in range(mini(s.aportes, 3)):
		estrellitas += "*"
	if sim.vivos() <= 15 or s.accion == "disparar" or (get_global_mouse_position() / 2.0).distance_to(pos - Vector2(0, 12)) < 10.0:
		_texto(String(s.nombre).substr(0, 10) + estrellitas, pos.x, pos.y - 20, Color("ffe9c0"), 5, 45)
	if (get_global_mouse_position() / 2.0).distance_to(pos - Vector2(0, 12)) < 10.0:
		var actividad := ""
		if s.accion == "cocinar": actividad = "cocinando" if s.llego else "a la cocina"
		elif s.accion == "cultivar": actividad = "huerto"
		elif s.carga.get("n", 0) > 0: actividad = "lleva comida" if s.carga.kind == "crudo" else "lleva munición"
		elif s.accion == "recoger": actividad = "al almacén"
		if actividad != "": _texto(actividad, pos.x, pos.y - 13, Color("b8b29b"), 5, 70)
	if s.hp < 99.0:
		_rc(pos.x - 6, pos.y - 18, 12, 1, Color("3a0a0a"))
		_rc(pos.x - 6, pos.y - 18, 12.0 * s.hp / 100.0, 1, Color("e03030"))
	if s.dice_ttl > 0.0 and s.dice != "" and (sim.vivos() <= 15 or (get_global_mouse_position() / 2.0).distance_to(pos) < 14.0):
		var tw := fuente.get_string_size(s.dice, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x / 2.0
		_rc(pos.x - tw / 2.0 - 2, pos.y - 44, tw + 4, 9, Color(0.95, 0.92, 0.9, 0.95))
		_texto(s.dice, pos.x, pos.y - 37, Color("201818"), 6, tw + 20)


func _zombi(_z: Dictionary) -> void:
	pass

func _cadaver(_e: Dictionary) -> void:
	pass


func _vapor_cocina() -> void:
	for humano in sim.supervivientes:
		if humano.accion != "cocinar" or not humano.llego:
			continue
		for i in range(3):
			var fase := fmod(t_anim * 0.5 + i / 3.0, 1.0)
			var p := proy(humano.x, humano.y + 0.6, humano.vy + 1.1)
			p += Vector2(sin(fase * TAU + i) * 1.5, -fase * 9.0)
			draw_circle(p.floor(), 0.6 + fase, Color(0.75, 0.75, 0.7, (1.0 - fase) * 0.28))


func _efectos() -> void:
	for p in parts:
		if p.has("anterior"):
			draw_line(Vector2(p.anterior).round(), Vector2(p.p).round(), p.c.darkened(0.25), 1.0)
		_rc(p.p.x, p.p.y, p.s, p.s, p.c)
	for e in sim.textos:
		var p := proy(e.x, 2.0, e.y)
		_texto(e.txt, p.x, p.y, e.col, 6, 70)


func _hud() -> void:
	var hh := int(sim.hora() * 24.0 + 6.0) % 24
	draw_rect(Rect2(0, 0, 640, 42), Color(0, 0, 0, 0.6))
	var linea := "GEN %d  DIA %d  %02d:00   HUMANOS %d/50   ZOMBIS %d" % [sim.gen, sim.dia(), hh, sim.vivos(), sim.zombis.size()]
	_texto(linea, 320, 8, Color("f0e0d8"), 7, 600)
	# Indicadores del almacen: suministros (comida sin cocinar) y municion, con lo que hay en cajas y cocina.
	var en_cajas := 0
	for cj in sim.cajas:
		en_cajas += cj.mun
	var max_cajas: int = sim.cajas.size() * Sim.CAJA_MAX
	_indicador(8.0, 21.0, "SUMINISTROS", sim.alm.crudo, 120, Color("d9b45a"), "cocina %d" % sim.stock.crudo)
	_indicador(168.0, 21.0, "MUNICIÓN", sim.alm.municion, 300, Color("9fc060"), "cajas %d/%d" % [en_cajas, max_cajas])
	var r := "COMIDA %d/%d   MADERA %d   VENTANAS %d/8" % [sim.stock.comida, sim.objetivo_comida(), sim.stock.madera, sim._contar("disparar")]
	_texto(r, 495, 29, Color("ffd9a0"), 6, 280)
	var vacias := 0
	for cj in sim.cajas:
		if cj.mun <= 0:
			vacias += 1
	var aviso: String = sim.aviso_municion()
	if aviso != "":
		_texto(aviso, 320, 50, Color("ff5040") if aviso == "¡SIN MUNICIÓN!" else Color("ffbc64"), 8, 240)
	elif vacias > 0:
		_texto("%d cajas vacias" % vacias, 320, 50, Color("ff9a60", 0.7 + 0.3 * sin(t_real * 5.0)), 6, 200)
	elif sim.zombis.is_empty() and sim.cola_zombis.is_empty():
		var rutina := "EN CALMA · COCINA %d · HUERTO %d · REPARTO %d" % [sim._contar("cocinar"), sim._contar("cultivar"), sim._contar("recoger") + sim._contar("entregar")]
		_texto(rutina, 320, 50, Color("b9bdad"), 6, 400)
	if sim.historial.size() > 0:
		var mejor := 0.0
		for h in sim.historial:
			mejor = maxf(mejor, float(h.dias))
		_texto("RECORD %.1fd" % mejor, 585, 9, Color("c0a0a0"), 6, 60)
	var y := 62.0
	for a in sim.avisos:
		_texto(a.txt, 320, y, Color(1, 0.55, 0.45, clampf(a.ttl, 0.0, 1.0)), 8, 280)
		y += 10.0
	if vel_juego > 1:
		_texto("x%d" % vel_juego, 14, 350, Color.WHITE, 6, 24)
	if pausa:
		_texto("PAUSA", 320, 180, Color.WHITE, 10, 80)


func _indicador(x: float, y: float, titulo: String, valor: int, tope: int, col: Color, extra: String) -> void:
	_rc(x, y + 2, 150, 4, Color(0.2, 0.2, 0.2, 0.9))
	var f := clampf(float(valor) / float(tope), 0.0, 1.0)
	var c := col if f > 0.2 else Color("e05a40")
	_rc(x, y + 2, 150.0 * f, 4, c)
	_texto("%s · %d" % [titulo, valor], x + 75, y - 4, Color("f0e6d0"), 5, 190)
	_texto(extra, x + 75, y + 13, Color("b8a890"), 5, 190)


func _prisma(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color) -> void:
	# Caja con tres caras visibles: techo, frente (profundidad menor) y costado (+x).
	var arriba := col.lightened(0.18)
	var frente := col
	var lado := col.darkened(0.3)
	draw_colored_polygon(PackedVector2Array([proy(x0, y0, z1), proy(x1, y0, z1), proy(x1, y1, z1), proy(x0, y1, z1)]), arriba)
	draw_colored_polygon(PackedVector2Array([proy(x0, y0, z0), proy(x1, y0, z0), proy(x1, y0, z1), proy(x0, y0, z1)]), frente)
	draw_colored_polygon(PackedVector2Array([proy(x1, y0, z0), proy(x1, y1, z0), proy(x1, y1, z1), proy(x1, y0, z1)]), lado)


func _almacen() -> void:
	# Cobertizo abierto por delante, entre los huertos y la casa; al fondo se apilan las reservas.
	var X0 := Sim.ALM_X0
	var X1 := Sim.ALM_X1
	var Y0 := Sim.ALM_Y0
	var Y1 := Sim.ALM_Y1
	var H := 3.2
	var suelo := Color("3a2f27")
	draw_colored_polygon(PackedVector2Array([proy(X0, Y0, 0), proy(X1, Y0, 0), proy(X1, Y1, 0), proy(X0, Y1, 0)]), suelo)
	draw_colored_polygon(PackedVector2Array([proy(X0, Y1, 0), proy(X1, Y1, 0), proy(X1, Y1, H), proy(X0, Y1, H)]), Color("5a4a3a"))
	draw_colored_polygon(PackedVector2Array([proy(X0, Y0, 0), proy(X0, Y1, 0), proy(X0, Y1, H), proy(X0, Y0, H)]), Color("463a2e"))
	draw_colored_polygon(PackedVector2Array([proy(X1, Y0, 0), proy(X1, Y1, 0), proy(X1, Y1, H), proy(X1, Y0, H)]), Color("3a3028"))
	# tablones de la pared del fondo
	for i in range(1, 8):
		var zz := H * float(i) / 8.0
		draw_line(proy(X0, Y1, zz), proy(X1, Y1, zz), Color(0, 0, 0, 0.25), 1)
	# techo: solo un alero al frente para que se vea el interior
	_prisma(X0 - 4, X1 + 4, Y0 - 0.2, Y0 + 0.2, H, H + 0.25, Color("6b4a32"))
	# reservas de municion (izquierda) y suministros (derecha), tantas cajas como haya
	var n_mun := clampi(ceili(float(sim.alm.municion) / 30.0), 0, 12)
	for i in range(n_mun):
		_caja_reserva(X0 + 4.0 + (i % 2) * 11.0, Y1, (i / 2) % 3, i / 6, Color("5c6b36"), Color("e0c04a"))
	var n_com := clampi(ceili(float(sim.alm.crudo) / 8.0), 0, 12)
	for i in range(n_com):
		_caja_reserva(X1 - 26.0 + (i % 2) * 11.0, Y1, (i / 2) % 3, i / 6, Color("a07a44"), Color("d8b0a0"))
	var cartel := proy(X0 + 14.0, Y0, H + 0.6)
	_texto("ALMACÉN", cartel.x, cartel.y - 6, Color("e8d8b0"), 7, 80)


func _caja_reserva(cx: float, y1: float, fila: int, piso: int, col: Color, marca: Color) -> void:
	var yy := y1 - 1.0 - fila * 0.85
	_prisma(cx, cx + 9.0, yy, yy + 0.75, piso * 0.55, piso * 0.55 + 0.5, col)
	var p := proy(cx + 4.0, yy, piso * 0.55 + 0.25)
	_rc(p.x - 1, p.y, 2, 1, marca)




# Cadenas organicas continuas, cuantizadas al pixel al dibujar.
# La fase depende del individuo; no crea nodos ni texturas por fotograma.
func _apendices(z: Dictionary, pos: Vector2) -> void:
	var fase := t_anim * (8.0 if z.camina else 3.0) + float(z.x) * 0.07
	var frente := float(z.dir)
	var cantidad := 4 if z.tipo == "bruto" else 2
	for rama in range(cantidad):
		var previo := pos + Vector2(0, -12 + rama)
		for segmento in range(1, 7):
			var u := float(segmento) / 6.0
			var longitud := 13.0 if z.tipo == "bruto" else 8.0
			var latido := sin(fase + u * 4.0 + rama * 1.7)
			if z.atac > 0.0:
				longitud += 5.0 * maxf(0.0, sin(t_anim * 14.0))
			var punto := pos + Vector2(-frente * u * longitud, -12.0 + rama + u * u * 6.0 + latido * u * 3.0)
			draw_line(previo.round(), punto.round(), Color("251c2e"), 3.0 if segmento < 4 else 2.0)
			draw_line(previo.round(), punto.round(), Color("a44458") if rama % 2 == 0 else Color("703046"), 1.0)
			if segmento == 6:
				_rc(punto.x, punto.y, 1, 1, Color("e9b9a0"))
			previo = punto


func _sombra(pos: Vector2, ancho: float) -> void:
	var direccion := Vector2(0.8, 0.45)
	var distancia := 1.0e9
	for luz in luces_interiores:
		var p := proy(luz.x, luz.y, luz.z)
		var d := pos.distance_squared_to(p)
		if d < distancia:
			distancia = d
			direccion = (pos - p).normalized()
	var lateral := Vector2(ancho * 0.65, 0)
	var cola := direccion * 8.0
	draw_colored_polygon(PackedVector2Array([pos - lateral, pos + lateral, pos + lateral * 0.4 + cola, pos - lateral * 0.4 + cola]), Color(0.005, 0.014, 0.02, 0.4))
	_rc(pos.x - ancho * 0.5, pos.y, ancho, 1, Color(0.005, 0.014, 0.02, 0.7))


func _luces_casa(_osc: float) -> void:
	# La iluminacion de las habitaciones y sus sombras se hornea con Cycles.
	# Aqui solo se anima el brillo del propio difusor y el fogon.
	for luz in luces_interiores:
		var p := proy(luz.x, luz.y, luz.z)
		var c: Array = luz.color
		_rc(p.x, p.y, 1, 1, Color(c[0], c[1], c[2], 0.4))


func _luz_actor(x: float, y: float, z: float) -> Color:
	var fuera := x < Sim.CASA_X0 or x > Sim.CASA_X1
	var color := Vector3(0.29, 0.38, 0.52) if fuera else Vector3(0.24, 0.30, 0.37)
	for luz in luces_interiores:
		if int(float(luz.z) / 4.8) != int(z / 4.8):
			continue
		var d := Vector3((x - float(luz.x)) / 25.0, y - float(luz.y), z + 1.0 - float(luz.z)).length_squared()
		var peso: float = minf(0.7, float(luz.energia) / (40.0 + d * 15.0))
		var c: Array = luz.color
		color += Vector3(c[0], c[1], c[2]) * peso
	return Color(minf(color.x, 1.15), minf(color.y, 1.1), minf(color.z, 1.05))


func _actividad(s: Dictionary, pos: Vector2) -> void:
	var pulso := sin(t_anim * 7.0 + s.id)
	var mano := pos + Vector2(s.dir * 5, -11 + roundf(pulso))
	match s.accion:
		"cocinar":
			_rc(mano.x, mano.y, 2, 2, Color("d6b18a"))
			draw_line(mano, mano + Vector2(3, -3), Color("a9b6a7"), 1)
			for i in range(3):
				var humo := fmod(t_anim * 3.0 + i * 2.0, 7.0)
				_rc(pos.x + 1 + sin(t_anim + i), pos.y - 14 - humo, 1, 2, Color(0.8, 0.84, 0.78, (1.0 - humo / 7.0) * 0.6))
		"comer":
			_rc(mano.x, mano.y - (2 if pulso > 0 else 0), 2, 1, Color("d4c59d"))
		"construir", "reparar", "talar":
			var punta := mano + Vector2(2, -4 if pulso > 0 else 1)
			draw_line(mano, punta, Color("b48d5e"), 1)
			_rc(punta.x - 1, punta.y, 3, 2, Color("a0aaa0"))
			if s.preparando:
				_rc(pos.x - 4, pos.y - 2, 8 * clampf(s.trab / 2.0, 0, 1), 1, Color("d5b781"))


func _malla_huerto(delante: bool) -> void:
	var profundidad := -1.0 if delante else 7.0
	var a := proy(5.0, profundidad, 0.0)
	var b := proy(Sim.CASA_X0, profundidad, 0.0)
	_segmento_malla(a, b)
	if delante:
		_segmento_malla(a, proy(5.0, 7.0, 0.0))
		_texto("HUERTO SEGURO", 46, 350, Color("9fae92"), 5, 85)
		_texto("PATIO / OLEADAS", 520, 350, Color("b5a58d"), 5, 180)


func _segmento_malla(a: Vector2, b: Vector2) -> void:
	var pasos := maxi(1, int(a.distance_to(b) / 4.0))
	for i in range(pasos):
		var p := a.lerp(b, float(i) / pasos)
		var q := a.lerp(b, float(i + 1) / pasos)
		draw_line(p, q - Vector2(0, 18), Color(0.43, 0.53, 0.51, 0.55), 1)
		draw_line(q, p - Vector2(0, 18), Color(0.43, 0.53, 0.51, 0.55), 1)
		if i % 4 == 0:
			draw_line(p, p - Vector2(0, 21), Color("697e75"), 1)
	draw_line(a - Vector2(0, 20), b - Vector2(0, 20), Color("738a7e"), 1)


func _demo_50(ensayo_armas: bool = false) -> void:
	sim.config.ambiente = false
	sim.rng.seed = 5050
	for i in range(50):
		sim.aplicar_regalo("Vecino%02d" % (i + 1), "GG")
	# Distribucion inicial para inspeccionar las cinco plantas sin esperar el viaje.
	for i in range(50):
		var s: Dictionary = sim.supervivientes[i]
		s.f = i / 10
		s.vy = Sim.PISO_Y[s.f]
		s.x = 185 + (i % 10) * 53.0
		s.y = Sim.PASILLO_Y
		s.energia = 95.0
		s.hambre = 10.0
	for cj in sim.cajas:
		cj.mun = 90
	sim.alm.municion = 5000 if ensayo_armas else 500
	# Los ocho puestos empiezan ocupados para mostrar su distribucion en la demo.
	var puestos := sim.puestos_ventana()
	for i in range(8):
		var s: Dictionary = sim.supervivientes[i]
		sim._comenzar(s, puestos[i])
		s.x = s.ox; s.y = s.oy; s.f = s.of; s.vy = Sim.PISO_Y[s.f]
		s.llego = true; s.camina = false
	for i in range(12):
		sim.spawn_zombi(1, "bruto" if i < 8 else "normal")
		var z: Dictionary = sim.zombis.back()
		z.x = 1100.0 + i * 15.0
	for i in range(0 if ensayo_armas else 80):
		sim.step(0.1)
		_consumir_fx()
		_particulas(0.1)
		ventanas_3d.actualizar(sim.barreras, 0.1)


func _arma_humano(s: Dictionary, pos: Vector2, iluminacion: Color) -> void:
	var activa: bool = (s.accion in ["disparar", "luchar"] and s.llego) or s.tiempo_tiro < 0.3
	var trabajando: bool = s.llego and s.accion in ["cocinar", "comer", "cultivar", "talar", "reparar", "construir"]
	var larga: bool = s.modelo_arma != "Pistola"
	var nombre: String = "ak" if s.modelo_arma == "AK" else "m4" if s.modelo_arma == "M4" else "pistola"
	var arma := tex("arma_" + nombre + ".png")
	var direccion := float(s.dir)
	var giro := 0.0
	if activa:
		var objetivo := proy(s.apunta_x, s.apunta_y, s.apunta_z)
		giro = clampf(atan2(objetivo.y - (pos.y - 9), absf(objetivo.x - pos.x)), -0.45, 0.45) * direccion
	else:
		giro = (0.4 + sin(s.anim * 0.7) * 0.045) * direccion
	if trabajando:
		giro = -1.2 * direccion
	var apoyo := pos + Vector2(direccion * (1.0 - s.retroceso * 2.0), -9.0)
	if trabajando: apoyo = pos + Vector2(-direccion * 2.0, -9.0)
	if s.recarga > 0.0:
		var p: float = 1.0 - s.recarga / Sim.ARMAS[s.modelo_arma].recarga
		giro += sin(p * PI) * 0.65 * direccion
	giro -= s.retroceso * (0.15 if larga else 0.28) * direccion
	draw_set_transform(apoyo * 2.0, giro, Vector2(0.8 * direccion, 0.8))
	draw_texture(arma, Vector2(-11, -8), iluminacion)
	if activa:
		_rc(0, 0, 2, 2, Color("b98c6a") * iluminacion)
		if larga: _rc(10, 0, 2, 2, Color("b98c6a") * iluminacion)
	var boca := 25.0 if larga else 9.0
	bocas_arma[s.id] = apoyo + Vector2(boca * 0.4 * direccion, -0.4).rotated(giro)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
