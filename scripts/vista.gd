extends Node2D
## Vista 2.5D super pixelada (estilo Carrion): lienzo 320x180 escalado x4, camara elevada (35 grados).
## La casa esta a la DERECHA y los zombis llegan por la IZQUIERDA. Sprites de Blender (arte/).
## Proyeccion:  pantalla_x = 316 - x*0.5     pantalla_y = 130 - (Z*cos35 + Y*sin35) * 12.5
##   x = coordenada de la simulacion (px, 25 px = 1 m);  Y = profundidad en m;  Z = altura en m.
##
## Teclas: R rosa nueva | T rosa de "Tester" (repetir = suministros) | G GG | 1-4 velocidad | Espacio pausa

const RUTA_EVENTOS := "res://eventos.jsonl"
const RUTA_HISTORIAL := "res://datos/historial.json"
const NOMBRES_PRUEBA := ["Ana", "Luis", "Marta", "Pepe", "Sofi", "Rafa", "Lola", "Toño", "Vero", "Dani", "Nina", "Hugo"]
const GY := 130.0
const C35 := 0.819
const S35 := 0.574
const PPM := 12.5
const FR := 32
const PIE := Vector2(16.0, 25.0)
const SANGRE := [Color("8a0f0f"), Color("a31515"), Color("5c0a0a"), Color("c21c1c")]

var sim: Sim
var fuente: Font
var vel_juego := 1
var pausa := false
var pos_eventos := 0
var t_eventos := 0.0
var guardados := 0
var estrellas: Array = []
var captura_ruta := ""
var captura_en := -1.0
var t_real := 0.0
var cache := {}
var props_meta := {}
var hierba: Array = []
var parts: Array = []        # particulas de gore en vuelo
var manchas: Array = []      # sangre persistente en el suelo
var gen_vista := 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	sim = Sim.new()
	sim.cargar_historial(RUTA_HISTORIAL)
	guardados = sim.historial.size()
	gen_vista = sim.gen
	fuente = ThemeDB.fallback_font
	rng.seed = 7
	for i in range(50):
		estrellas.append(Vector2(rng.randf_range(0, 320), rng.randf_range(0, 70)))
	for i in range(220):
		hierba.append([rng.randf_range(0, 320), rng.randf_range(84, 180), rng.randi() % 3])
	var f := FileAccess.open("res://arte/props.json", FileAccess.READ)
	if f:
		props_meta = JSON.parse_string(f.get_as_text())
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			_demo(700, 210, 1)
		elif a == "--demo-dia":
			_demo(300, 200, 2)
		elif a.begins_with("--captura="):
			captura_en = float(a.substr(10))
		elif a.begins_with("--salida="):
			captura_ruta = a.substr(9)
		elif a.begins_with("--vel="):
			vel_juego = int(a.substr(6))


func _demo(antes: int, despues: int, ggs: int) -> void:
	for n in ["Ana", "Luis", "Marta", "Pepe", "Sofi", "Rafa"]:
		sim.aplicar_regalo(n, "Rose", 1)
	for i in range(antes):
		sim.step(0.1)
	for i in range(ggs):
		sim.aplicar_regalo("Luis", "GG", 1)
	for i in range(despues):
		sim.step(0.1)
		_consumir_fx()
		_particulas(0.1)


func _process(delta: float) -> void:
	t_real += delta
	if not pausa:
		var restante := delta * vel_juego
		while restante > 0.0:
			var paso := minf(restante, 0.1)
			sim.step(paso)
			restante -= paso
	_consumir_fx()
	_particulas(delta)
	if sim.gen != gen_vista:
		gen_vista = sim.gen
		manchas.clear()
		parts.clear()
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
				sim.aplicar_regalo("Tester", "Rose", 1)
			KEY_G:
				sim.aplicar_regalo("Tester", "GG", 1)
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
		_gore(e)
	sim.fx.clear()


func _gore(e: Dictionary) -> void:
	var pos := proy(e.x, e.y, e.z)
	var suelo_y: float = proy(e.x, e.y, 0.0).y
	var vdir := -float(e.dir)                 # dir de la simulacion +1 = hacia la izquierda de la pantalla
	var mata: bool = e.get("mata", false) or e.k == "muerte_s"
	var n := 26 if mata else 7
	for i in range(n):
		parts.append({
			"p": pos + Vector2(rng.randf_range(-2, 2), rng.randf_range(-3, 3)),
			"v": Vector2(vdir * rng.randf_range(10, 90) + rng.randf_range(-20, 20), rng.randf_range(-90, -10)),
			"suelo": suelo_y + rng.randf_range(-2.0, 3.0), "c": SANGRE[rng.randi() % SANGRE.size()],
			"s": 1 + rng.randi() % 2, "trozo": false,
		})
	if mata:
		var piel := Color("6fae5a")
		var ropa := Color("5a4a6a")
		if e.k == "muerte_s":
			piel = Color("f1c9a0")
			ropa = Color("c0392b")
		else:
			if e.get("tipo", "") == "bruto":
				piel = Color("4f8a46")
			elif e.get("tipo", "") == "corredor":
				piel = Color("9ab85a")
		for c in [piel, piel, ropa, ropa, Color("8a0f0f")]:
			parts.append({
				"p": pos + Vector2(rng.randf_range(-3, 3), rng.randf_range(-4, 2)),
				"v": Vector2(vdir * rng.randf_range(10, 60) + rng.randf_range(-30, 30), rng.randf_range(-110, -40)),
				"suelo": suelo_y + rng.randf_range(0.0, 3.0), "c": c, "s": 3, "trozo": true,
			})
		# charco bajo el cuerpo
		for i in range(14):
			manchas.append([suelo_y + rng.randf_range(-1.0, 3.0), proy(e.x, e.y, 0.0).x + rng.randf_range(-9, 9), 1 + rng.randi() % 3, 1 + rng.randi() % 2, SANGRE[rng.randi() % SANGRE.size()]])
		_limitar_manchas()


func _limitar_manchas() -> void:
	while manchas.size() > 1400:
		manchas.pop_front()


func _particulas(dt: float) -> void:
	var vivas: Array = []
	for p in parts:
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
	return Vector2(floorf(316.0 - x * 0.5), floorf(GY - (z * C35 + y * S35) * PPM))


func _rc(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


func _texto(txt: String, x: float, y: float, col: Color, tam: int = 7, ancho: float = 80.0) -> void:
	# el mundo se dibuja a escala x4 (pixeles gordos); el texto va a resolucion de ventana para que se lea
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k := 4.0
	var t2 := int(round(tam * 2.3))
	var p := Vector2(floorf((x - ancho / 2.0) * k), floorf(y * k))
	draw_string_outline(fuente, p, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho * k, t2, 4, Color(0, 0, 0, 0.95))
	draw_string(fuente, p, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho * k, t2, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))


func _sprite_prop(nombre: String, pos: Vector2, mod: Color = Color.WHITE) -> void:
	var t := tex("prop_%s.png" % nombre)
	if t == null:
		return
	var m: Dictionary = props_meta.get(nombre, {"pie": [t.get_width() / 2.0, t.get_height() - 6.0]})
	var pie: Array = m.pie
	draw_texture(t, Vector2(floorf(pos.x - pie[0]), floorf(pos.y - pie[1])), mod)


func _sprite_hoja(nombre: String, col: int, fila: int, pos: Vector2, mod: Color = Color.WHITE, dy: float = 0.0) -> void:
	var t := tex(nombre)
	if t == null:
		return
	draw_texture_rect_region(t, Rect2(floorf(pos.x - PIE.x), floorf(pos.y - PIE.y + dy), FR, FR), Rect2(col * FR, fila * FR, FR, FR), mod)


# ======================================================================= escena

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
	var osc := sim.oscuridad()
	_cielo(osc)
	_capas_fondo(osc)
	_suelo(osc)
	for m in manchas:
		_rc(m[1], m[0], m[2], m[3], m[4])
	# casa espejada: el arte esta hecho con la puerta a la derecha; aqui va a la derecha del lienzo
	var t_atras := tex("casa_atras.png")
	if t_atras:
		_casa_espejo(t_atras)
	_entidades()
	var t_del := tex("casa_delante.png")
	if t_del:
		_casa_espejo(t_del)
	_efectos()
	var t_pp := tex("primer_plano.png")
	if t_pp:
		draw_texture(t_pp, Vector2(0, 135), Color(0.55, 0.5, 0.5, 1))
	# luz: oscuro y rojizo
	draw_rect(Rect2(0, 0, 320, 180), Color(0.1, 0.02, 0.03, 0.22 + osc * 0.35))
	if osc > 0.0:
		draw_rect(Rect2(150, 40, 160, 100), Color(1.0, 0.7, 0.35, osc * 0.12))
	_vineta()
	_hud()


func _casa_espejo(t: Texture2D) -> void:
	draw_set_transform(Vector2(321.0 * 4.0, (GY - 120.0) * 4.0), 0.0, Vector2(-4, 4))
	draw_texture(t, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))


func _vineta() -> void:
	for i in range(6):
		var a := 0.07 * (6 - i)
		draw_rect(Rect2(0, i * 3, 320, 3), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 180 - (i + 1) * 3, 320, 3), Color(0, 0, 0, a))
		draw_rect(Rect2(i * 3, 0, 3, 180), Color(0, 0, 0, a))
		draw_rect(Rect2(320 - (i + 1) * 3, 0, 3, 180), Color(0, 0, 0, a))


func _cielo(osc: float) -> void:
	var arriba := Color("33292e").lerp(Color("07060a"), osc)
	var abajo := Color("84706a").lerp(Color("1c1418"), osc)
	for i in range(0, 90, 3):
		draw_rect(Rect2(0, i, 320, 3), arriba.lerp(abajo, float(i) / 90.0))
	if osc > 0.25:
		for e in estrellas:
			draw_rect(Rect2(e.x, e.y, 1, 1), Color(1, 0.9, 0.9, (osc - 0.25) * 1.1))
		draw_circle(Vector2(60, 24), 6.0, Color(0.9, 0.85, 0.8, osc))
	else:
		draw_circle(Vector2(lerpf(300, 40, clampf(sim.hora() / 0.6, 0, 1)), 26), 7.0, Color(0.95, 0.75, 0.6, 0.45))


func _capas_fondo(osc: float) -> void:
	var l := tex("fondo_lejos.png")
	if l:
		draw_texture(l, Vector2(0, -33), Color(0.62, 0.52, 0.54, 1).lerp(Color(0.25, 0.22, 0.26, 1), osc))
	draw_rect(Rect2(0, 60, 320, 30), Color(0.55, 0.42, 0.42, 0.22 * (1.0 - osc)))
	var m := tex("fondo_medio.png")
	if m:
		draw_texture(m, Vector2(0, -25), Color(0.4, 0.34, 0.36, 1).lerp(Color(0.16, 0.14, 0.17, 1), osc))


func _suelo(osc: float) -> void:
	var lejos := Color("4a3f34").lerp(Color("14100e"), osc)
	var cerca := Color("2e2620").lerp(Color("0b0807"), osc)
	for i in range(0, 96, 3):
		draw_rect(Rect2(0, 84 + i, 320, 3), lejos.lerp(cerca, float(i) / 96.0))
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
	for a in sim.arboles:
		lista.append([a.y, "arbol", a])
	for h in sim.huertos:
		lista.append([h.y, "huerto", h])
	for tb in sim.tumbas:
		lista.append([tb.y, "tumba", tb])
	for b in sim.barreras:
		for ln in [-0.6, 1.6, 3.6]:
			lista.append([ln, "valla", [b, ln]])
	lista.append([3.9, "furgoneta", null])
	lista.append([0.3, "puerta", sim.puertas[0]])
	lista.sort_custom(func(a, b): return a[0] > b[0])
	for it in lista:
		match it[1]:
			"zombi": _zombi(it[2])
			"surv": _superviviente(it[2])
			"cad": _cadaver(it[2])
			"arbol":
				var a: Dictionary = it[2]
				_sprite_prop("arbol" if sim.t >= a.listo else "tocon", proy(a.x, a.y, 0.0), Color(0.7, 0.62, 0.6))
			"huerto":
				var h: Dictionary = it[2]
				_sprite_prop("huerto_listo" if sim.t >= h.listo else "huerto_vacio", proy(h.x, h.y, 0.0), Color(0.75, 0.68, 0.66))
			"tumba":
				var tb: Dictionary = it[2]
				var pp := proy(tb.x, tb.y, 0.0)
				_sprite_prop("tumba", pp)
				_texto(str(tb.nombre).substr(0, 10), pp.x, pp.y + 7, Color(0.85, 0.8, 0.8, 0.8), 6, 40)
			"valla":
				var b: Dictionary = it[2][0]
				var r: float = b.hp / b.max
				_sprite_prop("valla_%d" % (0 if r > 0.66 else (1 if r > 0.33 else 2)), proy(b.x, it[2][1], 0.0), Color(0.8, 0.72, 0.7))
			"furgoneta":
				_sprite_prop("furgoneta", proy(560.0, 3.9, 0.0), Color(0.55, 0.52, 0.52))
			"puerta":
				var p: Dictionary = it[2]
				var r2: float = p.hp / p.max
				var est := 0 if r2 > 0.66 else (1 if r2 > 0.33 else (2 if p.hp > 0.0 else 3))
				_sprite_prop("puerta_%d" % est, proy(p.x + 6.0, 0.3, 0.0))


func _superviviente(s: Dictionary) -> void:
	var pos := proy(s.x, s.y, s.vy)
	var activo: bool = s.accion in ["disparar", "luchar"]
	var fila := 6
	if s.camina or activo:
		fila = 0 if s.dir < 0 else 4
	var col := 0
	var dy := 0.0
	if s.camina:
		col = 1 + int(s.anim) % 6
	elif s.flash > 0.0:
		col = 8
	elif s.accion == "disparar" and s.llego:
		col = 7
	else:
		dy = floorf(0.6 + sin(t_real * 3.0 + s.id) * 0.6)          # respiracion
	var mod := Color(1, 1, 1)
	if s.golpe > 0.0:
		mod = Color(2.2, 0.8, 0.8)
		dy -= 1.0
	_sprite_hoja("sobreviviente_c%d_l%d.png" % [s.camisa, s.look], col, fila, pos, mod, dy)
	if s.flash > 0.0:
		_rc(pos.x - s.dir * 10, pos.y - 16, 2, 2, Color("ffe36b"))
	if s.accion == "dormir" and s.llego:
		_texto("z", pos.x + 5, pos.y - 24, Color.WHITE, 7, 8)
	var estrellitas := ""
	for i in range(mini(s.aportes, 3)):
		estrellitas += "*"
	_texto(String(s.nombre).substr(0, 10) + estrellitas, pos.x, pos.y - 27, Color("ffe9c0"), 6, 60)
	if s.hp < 99.0:
		_rc(pos.x - 6, pos.y - 25, 12, 1, Color("3a0a0a"))
		_rc(pos.x - 6, pos.y - 25, 12.0 * s.hp / 100.0, 1, Color("e03030"))
	if s.dice_ttl > 0.0 and s.dice != "":
		var tw := fuente.get_string_size(s.dice, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x / 4.0
		_rc(pos.x - tw / 2.0 - 2, pos.y - 44, tw + 4, 9, Color(0.95, 0.92, 0.9, 0.95))
		_texto(s.dice, pos.x, pos.y - 37, Color("201818"), 6, tw + 20)


func _zombi(z: Dictionary) -> void:
	var pos := proy(z.x, z.y, z.vy)
	var fila := 0 if z.dir < 0 else 4
	var col := 0
	var dy := 0.0
	if z.atac > 0.0:
		col = 7 + int(t_real * 9.0) % 3
	elif z.camina:
		col = 1 + int(z.anim) % 6
		dy = floorf(0.5 + sin(z.anim * 1.7) * 0.7)                # cojera: cabeceo irregular
	var mod := Color(1, 1, 1)
	if z.golpe > 0.0:
		mod = Color(2.4, 0.7, 0.7)
	_sprite_hoja("zombi_%s.png" % z.tipo, col, fila, pos, mod, dy)
	if z.hp < z.max:
		_rc(pos.x - 6, pos.y - 28, 12, 1, Color("1a2a18"))
		_rc(pos.x - 6, pos.y - 28, 12.0 * z.hp / z.max, 1, Color("8ae060"))


func _cadaver(e: Dictionary) -> void:
	var pos := proy(e.x, e.y, e.z)
	var mod := Color(1, 1, 1, clampf(4.0 - e.t, 0.0, 1.0) if e.t > 3.0 else 1.0)
	var fila := 0 if e.dir < 0 else 4
	if e.surv:
		_sprite_hoja("sobreviviente_c%d_l%d.png" % [e.camisa, e.look], 9 + mini(3, int(e.t / 0.2)), fila, pos, mod)
	else:
		_sprite_hoja("zombi_%s.png" % e.tipo, 10 + mini(3, int(e.t / 0.2)), fila, pos, mod)


func _efectos() -> void:
	for d in sim.disparos:
		draw_line(proy(d.x0, d.d0, d.z0), proy(d.x1, d.d1, d.z1), Color(1, 0.92, 0.55, 0.95), 1.0)
	for p in parts:
		_rc(p.p.x, p.p.y, p.s, p.s, p.c)
	for e in sim.textos:
		var p := proy(e.x, 2.0, e.y)
		_texto(e.txt, p.x, p.y, e.col, 6, 70)


func _hud() -> void:
	var hh := int(sim.hora() * 24.0 + 6.0) % 24
	draw_rect(Rect2(0, 0, 320, 17), Color(0, 0, 0, 0.5))
	var linea := "GEN %d  DIA %d  %02d:00   VIVOS %d   ZOMBIS %d" % [sim.gen, sim.dia(), hh, sim.vivos(), sim.zombis.size()]
	_texto(linea, 160, 7, Color("f0e0d8"), 7, 300)
	var r := "COMIDA %d(+%d)   MADERA %d   MUNICION %d" % [sim.stock.comida, sim.stock.crudo, sim.stock.madera, sim.stock.municion]
	_texto(r, 160, 15, Color("ffd9a0"), 6, 300)
	if sim.historial.size() > 0:
		var mejor := 0.0
		for h in sim.historial:
			mejor = maxf(mejor, float(h.dias))
		_texto("RECORD %.1fd" % mejor, 285, 7, Color("c0a0a0"), 6, 60)
	var y := 30.0
	for a in sim.avisos:
		_texto(a.txt, 160, y, Color(1, 0.55, 0.45, clampf(a.ttl, 0.0, 1.0)), 8, 280)
		y += 10.0
	if vel_juego > 1:
		_texto("x%d" % vel_juego, 14, 174, Color.WHITE, 6, 24)
	if pausa:
		_texto("PAUSA", 160, 90, Color.WHITE, 10, 80)
