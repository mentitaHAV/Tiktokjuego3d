class_name Sim
extends RefCounted
## Simulación pura (sin dibujo) de la casa de sobrevivientes.
## Vista lateral: 2 plantas, patio a los lados. Todo en coordenadas virtuales 480x270.

const ANCHO := 640.0                       # lienzo en px; 25 px = 1 metro
const PISO_Y := [0.0, 3.2]                 # altura de cada piso en metros
const CASA_X0 := 20.0
const CASA_X1 := 320.0                     # pared derecha: la puerta da al patio
const ESCALERA_X := 225.0
const MAX_VIVOS := 12
const DIA_LEN := 120.0
const VEL_S := 33.0
const HUECOS_DER := [520.0, 550.0, 580.0]  # barricadas en el patio (de dentro hacia fuera)
const CARRILES := [-0.8, 0.8, 2.4, 4.0]    # profundidad del patio en metros
const CAMAS := [56.0, 106.0, 156.0, 284.0]
const COCINA_X := 55.0
const MESA_X := 135.0
const BANCO_X := 290.0
const VENTANA_DER := 300.0
const COSTE_BARRERA := 6
const FRASES := {
	"comer": ["Qué hambre...", "A comer.", "Ñam."],
	"dormir": ["Me caigo de sueño.", "A la cama.", "Zzz..."],
	"cocinar": ["Yo cocino.", "Algo caliente.", "Huele bien."],
	"construir": ["Más muros.", "Esto aguanta.", "A clavar."],
	"reparar": ["Arreglo esto.", "Otro parche.", "Aguanta, puerta."],
	"cultivar": ["A la huerta.", "Más comida.", "Cosechando."],
	"talar": ["Necesitamos madera.", "A talar.", "Leña."],
	"disparar": ["¡Vienen!", "¡A mi ventana!", "Apunten."],
	"luchar": ["¡Dentro!", "¡Se metió uno!", "¡Fuera de aquí!"],
	"volver": ["¡Adentro!", "¡Corran!", "Me vuelvo."],
	"pasear": ["...", "Qué silencio.", "Tengo miedo."],
	"hola": ["¡Hola!", "¡Llegué!", "¿Hay sitio?"],
	"muerte": ["Aaah...", "No...", "Díganle a mamá..."],
}

var rng := RandomNumberGenerator.new()
var config := {"regalos": {"Rose": "persona", "GG": "zombis"}, "ambiente": true}

var gen := 1
var t := 0.0
var supervivientes: Array = []
var zombis: Array = []
var barreras: Array = []
var puertas: Array = []
var huertos: Array = []
var arboles: Array = []
var tumbas: Array = []
var stock := {}
var cola_zombis: Array = []
var textos: Array = []
var disparos: Array = []
var avisos: Array = []
var historial: Array = []
var cadaveres: Array = []
var fx: Array = []        # eventos de gore para la vista (la vista los consume y vacia)

var kills := 0
var muertes := 0
var pico := 0
var tuvo_gente := false
var nombres_gen: Array = []
var fin_timer := -1.0
var sig_ambiente := 70.0
var next_id := 1


func _init(semilla: int = 0) -> void:
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()
	_reiniciar_mundo()


func _reiniciar_mundo() -> void:
	t = 0.0
	supervivientes.clear()
	zombis.clear()
	barreras.clear()
	cola_zombis.clear()
	tumbas.clear()
	textos.clear()
	disparos.clear()
	nombres_gen.clear()
	stock = {"crudo": 6, "comida": 4, "madera": 10, "municion": 30}
	puertas = [{"x": CASA_X1, "hp": 250.0, "max": 250.0}]
	huertos = []
	for x in [350.0, 378.0, 406.0]:
		huertos.append({"x": x, "y": 0.6, "listo": 0.0, "ocupado": false})
	arboles = []
	for x in [440.0, 465.0, 490.0]:
		arboles.append({"x": x, "y": 3.2, "listo": 0.0, "ocupado": false})
	cadaveres.clear()
	fx.clear()
	kills = 0
	muertes = 0
	pico = 0
	tuvo_gente = false
	fin_timer = -1.0
	sig_ambiente = 70.0
	aviso("GENERACIÓN %d" % gen, 5.0)


# ---------------------------------------------------------------- tiempo

func dia() -> int:
	return int(t / DIA_LEN) + 1


func hora() -> float:
	return fmod(t, DIA_LEN) / DIA_LEN


func oscuridad() -> float:
	var h := hora()
	if h < 0.55:
		return 0.0
	if h < 0.68:
		return (h - 0.55) / 0.13
	if h < 0.9:
		return 1.0
	return 1.0 - (h - 0.9) / 0.1


func es_noche() -> bool:
	return oscuridad() > 0.5


func vivos() -> int:
	return supervivientes.size()


# ---------------------------------------------------------------- eventos de donación

func aplicar_regalo(usuario: String, regalo: String, cantidad: int = 1) -> void:
	var tipo: String = config.regalos.get(regalo, "suministros")
	for i in range(maxi(cantidad, 1)):
		match tipo:
			"persona":
				_rosa(usuario)
			"zombis":
				_gg(usuario)
			_:
				_suministros(usuario, null)


func _buscar_vivo(usuario: String) -> Variant:
	for s in supervivientes:
		if String(s.nombre).to_lower() == usuario.to_lower():
			return s
	return null


func _rosa(usuario: String) -> void:
	var s = _buscar_vivo(usuario)
	if s == null:
		if vivos() >= MAX_VIVOS:
			_suministros(usuario, null)
			return
		s = _nuevo_superviviente(usuario)
		supervivientes.append(s)
		tuvo_gente = true
		if not nombres_gen.has(usuario):
			nombres_gen.append(usuario)
		pico = maxi(pico, vivos())
		aviso("%s llegó a la casa" % usuario, 3.5)
		_decir(s, "hola")
		return
	_suministros(usuario, s)


func _suministros(usuario: String, s: Variant) -> void:
	var n := vivos()
	stock.crudo += 1 + n / 2
	stock.comida += 1
	stock.madera += 3
	stock.municion += 10 + n
	for o in supervivientes:
		o.hp = minf(100.0, o.hp + 15.0)
	if s != null:
		s.aportes += 1
		_texto("+suministros", s.x, PISO_Y[s.f] + 2.3, Color(1, 0.9, 0.3))
	aviso("%s reparte suministros" % usuario, 3.0)


func _gg(usuario: String) -> void:
	var n := mini(5 + gen, 30)
	for i in range(n):
		var r := rng.randf()
		var tipo := "normal"
		if r < 0.08:
			tipo = "bruto"
		elif r < 0.30:
			tipo = "corredor"
		cola_zombis.append({"cuando": t + i * 0.45, "lado": 1, "tipo": tipo})
	aviso("%s invoca %d zombis" % [usuario, n], 4.0)


func _nuevo_superviviente(nombre: String) -> Dictionary:
	var h: int = absi(nombre.hash())
	var s := {
		"id": next_id, "nombre": nombre,
		"x": ESCALERA_X + rng.randf_range(-20.0, 20.0), "f": 0, "vy": 0.0, "y": rng.randf_range(1.4, 3.6), "y_casa": rng.randf_range(1.4, 3.6),
		"hp": 100.0, "hambre": rng.randf_range(10.0, 35.0), "energia": rng.randf_range(70.0, 100.0),
		"accion": "", "ox": 0.0, "of": 0, "trab": 0.0, "dur": 0.0, "llego": false,
		"cd_dec": 0.0, "cd_ataque": 0.0, "flash": 0.0, "ref": null, "lado": 0,
		"aportes": 0, "kills": 0, "dir": 1, "camina": false, "anim": rng.randf() * 10.0,
		"dice": "", "dice_ttl": 0.0, "golpe": 0.0,
		"val": rng.randf_range(0.8, 1.3), "tr": rng.randf_range(0.8, 1.3), "glot": rng.randf_range(0.8, 1.3),
		"camisa": h % 8, "look": (h / 8) % 3,
	}
	next_id += 1
	return s


# ---------------------------------------------------------------- utilidades de texto

func aviso(txt: String, ttl: float) -> void:
	avisos.append({"txt": txt, "ttl": ttl})
	if avisos.size() > 4:
		avisos.pop_front()


func _texto(txt: String, x: float, z: float, col: Color) -> void:
	textos.append({"txt": txt, "x": x, "y": z, "ttl": 1.6, "col": col})


func _decir(s: Dictionary, clave: String) -> void:
	var lista: Array = FRASES.get(clave, [])
	if lista.is_empty():
		return
	s.dice = lista[rng.randi() % lista.size()]
	s.dice_ttl = 2.6


# ---------------------------------------------------------------- bucle principal

func step(dt: float) -> void:
	t += dt
	_procesar_cola()
	_ambiente()
	for s in supervivientes:
		_vida(s, dt)
	for z in zombis:
		_zombi(z, dt)
	# muertes de supervivientes
	var quedan: Array = []
	for s in supervivientes:
		if s.hp <= 0.0:
			_morir(s)
		else:
			quedan.append(s)
	supervivientes = quedan
	zombis = zombis.filter(func(z): return z.hp > 0.0)
	barreras = barreras.filter(func(b): return b.hp > 0.0)
	# efectos
	for e in textos:
		e.ttl -= dt
		e.y += 0.35 * dt
	textos = textos.filter(func(e): return e.ttl > 0.0)
	for e in cadaveres:
		e.t += dt
	cadaveres = cadaveres.filter(func(e): return e.t < 4.0)
	for e in disparos:
		e.ttl -= dt
	disparos = disparos.filter(func(e): return e.ttl > 0.0)
	for e in avisos:
		e.ttl -= dt
	avisos = avisos.filter(func(e): return e.ttl > 0.0)
	# fin de generación
	if fin_timer < 0.0 and tuvo_gente and vivos() == 0:
		_cerrar_generacion()
	elif fin_timer >= 0.0:
		fin_timer -= dt
		if fin_timer < 0.0:
			gen += 1
			_reiniciar_mundo()


func _cerrar_generacion() -> void:
	historial.append({
		"gen": gen, "segundos": snappedf(t, 0.1), "dias": snappedf(t / DIA_LEN, 0.01),
		"pico": pico, "kills": kills, "muertes": muertes, "nombres": nombres_gen.duplicate(),
	})
	fin_timer = 8.0
	aviso("TODOS MURIERON  -  Gen %d duró %.1f días" % [gen, t / DIA_LEN], 8.0)


func _morir(s: Dictionary) -> void:
	_soltar(s)
	muertes += 1
	fx.append({"k": "muerte_s", "x": s.x, "y": s.y, "z": s.vy + 1.0, "dir": s.dir})
	tumbas.append({"x": s.x, "y": s.y, "nombre": s.nombre})
	cadaveres.append({"x": s.x, "y": s.y, "z": s.vy, "tipo": "", "dir": s.dir, "t": 0.0, "surv": true, "camisa": s.camisa, "look": s.look})
	_texto("RIP " + s.nombre, s.x, PISO_Y[s.f] + 2.3, Color(1, 0.4, 0.4))
	aviso("%s murió" % s.nombre, 3.0)


func _procesar_cola() -> void:
	if cola_zombis.is_empty():
		return
	var resto: Array = []
	for c in cola_zombis:
		if c.cuando <= t:
			spawn_zombi(c.lado, c.tipo)
		else:
			resto.append(c)
	cola_zombis = resto


func _ambiente() -> void:
	if not config.ambiente or t < sig_ambiente or vivos() == 0:
		return
	spawn_zombi(1, "normal")
	if es_noche():
		spawn_zombi(1, "corredor" if rng.randf() < 0.3 else "normal")
	sig_ambiente = t + rng.randf_range(90.0, 160.0) / (1.0 + dia() * 0.15)


func spawn_zombi(lado: int, tipo: String) -> void:
	var z := {
		"x": ANCHO + 12.0, "y": CARRILES[rng.randi() % CARRILES.size()], "f": 0, "vy": 0.0, "lado": 1,
		"tipo": tipo, "cd": 0.0, "dentro": false, "anim": rng.randf() * 10.0, "esc_t": 0.0, "dir": 1,
		"camina": true, "atac": 0.0, "golpe": 0.0,
	}
	match tipo:
		"corredor":
			z.hp = 20.0; z.vel = rng.randf_range(30.0, 36.0); z.dmg = 6.0; z.dps = 6.0
		"bruto":
			z.hp = 110.0; z.vel = rng.randf_range(11.0, 14.0); z.dmg = 18.0; z.dps = 28.0
		_:
			z.hp = 32.0; z.vel = rng.randf_range(15.0, 20.0); z.dmg = 8.0; z.dps = 8.0
	z.max = z.hp
	zombis.append(z)


# ---------------------------------------------------------------- superviviente

func _vida(s: Dictionary, dt: float) -> void:
	s.cd_ataque -= dt
	s.flash -= dt
	s.golpe = maxf(0.0, s.golpe - dt)
	s.dice_ttl -= dt
	s.anim += dt * (8.0 if s.camina else 0.0)
	s.vy = move_toward(s.vy, PISO_Y[s.f], 2.6 * dt)
	var y_meta: float = s.y_casa if s.x < CASA_X1 - 4.0 else 0.8
	s.y = move_toward(s.y, y_meta, 1.4 * dt)
	s.cd_dec -= dt
	if s.cd_dec <= 0.0 or s.accion == "":
		_decidir(s)
		s.cd_dec = rng.randf_range(0.5, 0.9)
	_actuar(s, dt)
	_reflejo(s)
	# necesidades
	s.hambre = minf(100.0, s.hambre + 0.5 * dt)
	if s.accion == "dormir" and s.llego:
		s.energia = minf(100.0, s.energia + 5.0 * dt)
	else:
		s.energia = maxf(0.0, s.energia - 0.4 * dt)
	if s.hambre >= 100.0:
		s.hp -= 1.5 * dt
	elif s.hambre < 70.0 and s.energia > 20.0:
		s.hp = minf(100.0, s.hp + 0.6 * dt)


func _fuera(s: Dictionary) -> bool:
	return s.x > CASA_X1 + 2.0


func _zombi_cerca_casa(rango: float) -> Variant:
	var mejor = null
	var md := 1e9
	for z in zombis:
		if z.dentro:
			continue
		var d: float = z.x - CASA_X1
		if d < rango and d < md:
			md = d
			mejor = z
	return mejor


func _zombi_dentro_cercano(s: Dictionary) -> Variant:
	var mejor = null
	var md := 1e9
	for z in zombis:
		if not z.dentro:
			continue
		var d: float = absf(z.x - s.x) + 50.0 * absf(z.f - s.f)
		if d < md:
			md = d
			mejor = z
	return mejor


func _zombi_cerca_de(x: float, rango: float) -> bool:
	for z in zombis:
		if not z.dentro and absf(z.x - x) < rango:
			return true
	return false


func _contar(accion: String) -> int:
	var n := 0
	for s in supervivientes:
		if s.accion == accion:
			n += 1
	return n


func _hueco_libre() -> Variant:
	for x in HUECOS_DER:
		var ocupado := false
		for b in barreras:
			if absf(b.x - x) < 1.0:
				ocupado = true
		for o in supervivientes:
			if o.accion == "construir" and absf(o.ox - x) < 1.0:
				ocupado = true
		if not ocupado and not _zombi_cerca_de(x, 90.0):
			return x
	return null


func _dañado() -> Variant:
	var mejor = null
	var mr := 0.6
	for p in puertas:
		var r: float = p.hp / p.max
		if r < mr and not _reservado(p) and not _zombi_cerca_de(p.x, 45.0):
			mr = r
			mejor = p
	for b in barreras:
		var r: float = b.hp / b.max
		if r < mr and not _reservado(b) and not _zombi_cerca_de(b.x, 45.0):
			mr = r
			mejor = b
	return mejor


func _reservado(obj: Variant) -> bool:
	for o in supervivientes:
		if o.accion == "reparar" and is_same(o.ref, obj):
			return true
	return false


func _libre_recurso(lista: Array, rango: float) -> Variant:
	for r in lista:
		if t >= r.listo and not r.ocupado and not _zombi_cerca_de(r.x, rango):
			return r
	return null


func _decidir(s: Dictionary) -> void:
	var c: Array = []   # [puntuación, {tipo,x,f,dur,ref}]
	var fuera := _fuera(s)
	var amen = _zombi_cerca_casa(360.0)
	var hay_municion: bool = stock.municion > 0
	var noche := es_noche()
	var pop := vivos()

	var zd = _zombi_dentro_cercano(s)
	if zd != null:
		var ox: float = zd.x
		if hay_municion:
			ox = zd.x - signf(zd.x - s.x) * 20.0
		c.append([100.0 * s.val, {"tipo": "luchar", "x": ox, "f": zd.f}])

	if amen != null:
		if fuera:
			c.append([96.0, {"tipo": "volver", "x": CASA_X1 - 36.0, "f": 0}])
		elif hay_municion and s.hp > 20.0:
			var piso := 1
			var n1 := _ocupantes_ventana(1)
			if n1 >= 3:
				piso = 0 if _ocupantes_ventana(0) < 3 else 1
			var k := _ocupantes_ventana(piso)
			var wx: float = VENTANA_DER - 16.0 * k
			c.append([78.0 * s.val, {"tipo": "disparar", "x": wx, "f": piso, "lado": 1}])
		elif s.val > 1.05 and s.hp > 50.0:
			c.append([52.0 * s.val, {"tipo": "disparar", "x": CASA_X1 - 20.0, "f": 0, "lado": 1}])

	if s.hambre >= 55.0 and (stock.comida > 0 or stock.crudo > 0):
		c.append([(s.hambre - 20.0) * 1.1 * s.glot, {"tipo": "comer", "x": MESA_X, "f": 0, "dur": 3.0}])

	var durmiendo: bool = s.accion == "dormir"
	if s.energia < 30.0 or (durmiendo and s.energia < 92.0):
		c.append([60.0 + maxf(0.0, 30.0 - s.energia), _cama(s)])
	elif noche and s.energia < 65.0:
		c.append([38.0, _cama(s)])

	var urg := 20.0 if amen != null else 0.0

	if stock.crudo >= 1 and stock.comida < 2 * pop + 2 and (_contar("cocinar") == 0 or s.accion == "cocinar"):
		c.append([(46.0 + (10.0 if stock.comida == 0 else 0.0)) * s.tr, {"tipo": "cocinar", "x": COCINA_X, "f": 0, "dur": 5.0}])

	if stock.madera >= COSTE_BARRERA and barreras.size() < 6 and (_contar("construir") < 2 or s.accion == "construir"):
		var hx = _hueco_libre()
		if hx != null:
			c.append([(50.0 + urg) * s.tr, {"tipo": "construir", "x": hx, "f": 0, "dur": 5.0}])

	if stock.madera >= 1:
		var d = _dañado()
		if d != null:
			var ox2: float = d.x - 14.0
			c.append([(52.0 + urg) * s.tr, {"tipo": "reparar", "x": ox2, "f": 0, "dur": 2.5, "ref": d}])

	if not noche and amen == null:
		if stock.crudo < 3 * pop + 4:
			var h = _libre_recurso(huertos, 200.0)
			if h != null:
				c.append([40.0 * s.tr, {"tipo": "cultivar", "x": h.x, "f": 0, "dur": 6.0, "ref": h}])
		if stock.madera < 14:
			var a = _libre_recurso(arboles, 200.0)
			if a != null:
				c.append([38.0 * s.tr, {"tipo": "talar", "x": a.x, "f": 0, "dur": 6.0, "ref": a}])

	var px := rng.randf_range(CASA_X0 + 30.0, CASA_X1 - 30.0)
	c.append([8.0, {"tipo": "pasear", "x": px, "f": rng.randi() % 2, "dur": rng.randf_range(1.5, 4.0)}])

	var mejor = null
	var mp := -1e9
	for par in c:
		var p: float = par[0] + rng.randf() * 6.0
		if par[1].tipo == s.accion:
			p += 8.0
		if p > mp:
			mp = p
			mejor = par[1]
	_comenzar(s, mejor)


func _ocupantes_ventana(piso: int) -> int:
	var n := 0
	for o in supervivientes:
		if o.accion == "disparar" and o.of == piso:
			n += 1
	return n


func _cama(s: Dictionary) -> Dictionary:
	var usadas: Array = []
	for o in supervivientes:
		if o.accion == "dormir" and o.id != s.id:
			usadas.append(o.ox)
	var x: float = CAMAS[s.id % CAMAS.size()]
	for cx in CAMAS:
		if not usadas.has(cx):
			x = cx
			break
	return {"tipo": "dormir", "x": x, "f": 1}


func _comenzar(s: Dictionary, a: Dictionary) -> void:
	var ref_nuevo = a.get("ref", null)
	if a.tipo == s.accion and is_same(ref_nuevo, s.ref):
		# misma acción y mismo objetivo: solo se ajusta el destino
		if a.tipo in ["luchar", "disparar", "volver"]:
			s.ox = a.x
			s.of = a.f
			s.lado = a.get("lado", 0)
		return
	_soltar(s)
	s.trab = 0.0
	if rng.randf() < 0.18:
		_decir(s, a.tipo)
	s.accion = a.tipo
	s.ox = a.x
	s.of = a.f
	s.dur = a.get("dur", 0.0)
	s.lado = a.get("lado", 0)
	s.llego = false
	var ref = a.get("ref", null)
	if ref != null:
		s.ref = ref
		if ref.has("ocupado"):
			ref.ocupado = true


func _soltar(s: Dictionary) -> void:
	if s.ref != null and s.ref.has("ocupado"):
		s.ref.ocupado = false
	s.ref = null


func _mover(s: Dictionary, tx: float, tf: int, dt: float) -> bool:
	var meta := tx
	if s.f != tf:
		meta = ESCALERA_X
		if absf(s.x - meta) < 2.0:
			s.f = tf
			meta = tx
	var d: float = meta - s.x
	if absf(d) < 1.5:
		s.camina = false
		return s.f == tf
	s.x += signf(d) * minf(absf(d), VEL_S * dt)
	s.dir = int(signf(d))
	s.camina = true
	return false


func _actuar(s: Dictionary, dt: float) -> void:
	s.llego = _mover(s, s.ox, s.of, dt)
	match s.accion:
		"comer", "cocinar", "construir", "reparar", "cultivar", "talar", "pasear":
			if s.llego:
				s.trab += dt
				if s.trab >= s.dur:
					_terminar(s)
		"luchar", "volver":
			if s.llego and s.accion == "volver":
				s.accion = ""


func _terminar(s: Dictionary) -> void:
	match s.accion:
		"comer":
			if stock.comida >= 1:
				stock.comida -= 1
				s.hambre = maxf(0.0, s.hambre - 60.0)
			elif stock.crudo >= 1:
				stock.crudo -= 1
				s.hambre = maxf(0.0, s.hambre - 28.0)
		"cocinar":
			if stock.crudo >= 1:
				stock.crudo -= 1
				stock.comida += 2
				_texto("+2 comida", s.x, PISO_Y[s.f] + 2.1, Color(1, 0.7, 0.3))
		"construir":
			if stock.madera >= COSTE_BARRERA:
				stock.madera -= COSTE_BARRERA
				barreras.append({"x": s.ox, "hp": 120.0, "max": 120.0})
		"reparar":
			var r = s.ref
			if r != null and stock.madera >= 1:
				stock.madera -= 1
				r.hp = minf(r.max, r.hp + 35.0)
		"cultivar":
			if s.ref != null:
				s.ref.listo = t + 70.0
				stock.crudo += 2
				_texto("+2 comida", s.x, 2.1, Color(0.5, 1, 0.5))
		"talar":
			if s.ref != null:
				s.ref.listo = t + 70.0
				stock.madera += 3
				_texto("+3 madera", s.x, 2.1, Color(0.9, 0.7, 0.4))
	_soltar(s)
	s.accion = ""
	s.cd_dec = 0.0


func _reflejo(s: Dictionary) -> void:
	if s.cd_ataque > 0.0 or s.accion == "dormir":
		return
	var objetivo = null
	var md := 1e9
	var afuera := _fuera(s)
	var en_ventana := false
	var rango_v := 0.0
	if not afuera and s.x > CASA_X1 - 70.0:
		en_ventana = true
		rango_v = 280.0 + (40.0 if s.f == 1 else 0.0)
	for z in zombis:
		var d := 1e9
		if z.dentro:
			if z.f == s.f:
				d = absf(z.x - s.x)
				if d > 45.0:
					d = 1e9
		else:
			if en_ventana:
				if z.x > CASA_X1:
					d = z.x - s.x
				if d > rango_v:
					d = 1e9
			elif afuera and s.f == 0:
				d = absf(z.x - s.x)
				if d > 140.0:
					d = 1e9
		if d < md:
			md = d
			objetivo = z
	if objetivo == null:
		return
	if stock.municion > 0:
		stock.municion -= 1
		s.cd_ataque = rng.randf_range(0.8, 1.1)
		s.flash = 0.1
		s.dir = 1 if objetivo.x > s.x else -1
		var prob := 0.8 if md < 160.0 else 0.6
		disparos.append({"x0": s.x + s.dir * 14.0, "d0": s.y, "z0": s.vy + 1.3, "x1": objetivo.x, "d1": objetivo.y, "z1": objetivo.vy + 1.0, "ttl": 0.09})
		if rng.randf() < prob:
			_dañar_zombi(objetivo, rng.randf_range(16.0, 24.0), s)
	elif md < 18.0 and objetivo.f == s.f:
		s.cd_ataque = 0.7
		s.flash = 0.1
		s.dir = 1 if objetivo.x > s.x else -1
		if rng.randf() < 0.85:
			_dañar_zombi(objetivo, 7.0, s)


func _dañar_zombi(z: Dictionary, dmg: float, s: Dictionary) -> void:
	z.hp -= dmg
	z.golpe = 0.12
	z.x += s.dir * 2.0
	fx.append({"k": "golpe", "x": z.x, "y": z.y, "z": z.vy + 1.1, "dir": s.dir, "mata": z.hp <= 0.0, "tipo": z.tipo})
	if z.hp <= 0.0:
		cadaveres.append({"x": z.x, "y": z.y, "z": z.vy, "tipo": z.tipo, "dir": z.dir, "t": 0.0, "surv": false})
		kills += 1
		s.kills += 1
		_texto("+1", z.x, z.vy + 2.0, Color(0.6, 1, 0.6))


# ---------------------------------------------------------------- zombi

func _objetivo_zombi(z: Dictionary) -> Variant:
	var mejor = null
	var md := 1e9
	for s in supervivientes:
		var d: float = absf(s.x - z.x) + 60.0 * absf(s.f - z.f)
		if not z.dentro:
			if not (_fuera(s) and s.f == 0 and absf(s.x - z.x) < 170.0):
				continue
		if d < md:
			md = d
			mejor = s
	return mejor


func _obstaculo(z: Dictionary, dir: int) -> Variant:
	if z.dentro or dir >= 0:
		return null
	for b in barreras:
		if b.x < z.x and z.x - b.x < 9.0:
			return b
	if z.x > CASA_X1 and z.x - CASA_X1 < 9.0 and puertas[0].hp > 0.0:
		return puertas[0]
	return null


func _zombi(z: Dictionary, dt: float) -> void:
	if z.hp <= 0.0:
		return
	z.cd -= dt
	z.vy = move_toward(z.vy, PISO_Y[z.f], 2.6 * dt)
	z.atac = maxf(0.0, z.atac - dt)
	z.golpe = maxf(0.0, z.golpe - dt)
	z.anim += dt * 6.0
	if not z.dentro and z.x < CASA_X1 - 6.0:
		z.dentro = true
	var obj = _objetivo_zombi(z)
	var dir := 0
	if obj != null:
		if obj.f != z.f and z.dentro:
			if absf(z.x - ESCALERA_X) < 2.0:
				z.esc_t += dt
				if z.esc_t >= 1.2:
					z.f = obj.f
					z.esc_t = 0.0
			else:
				dir = int(signf(ESCALERA_X - z.x))
		else:
			z.y = move_toward(z.y, obj.y, 1.2 * dt)
			if obj.f == z.f and absf(obj.x - z.x) < 16.0 and absf(obj.y - z.y) < 1.4:
				if z.cd <= 0.0:
					obj.hp -= z.dmg
					fx.append({"k": "golpe_s", "x": obj.x, "y": obj.y, "z": obj.vy + 1.1, "dir": z.dir, "mata": obj.hp <= 0.0})
					obj.golpe = 0.12
					z.cd = 1.1
					z.atac = 0.5
			else:
				dir = int(signf(obj.x - z.x))
	else:
		if z.dentro:
			dir = int(signf(ESCALERA_X - z.x)) if absf(z.x - ESCALERA_X) > 6.0 else 0
		else:
			dir = -1
	z.camina = dir != 0
	if dir != 0:
		z.dir = dir
		var ob = _obstaculo(z, dir)
		if ob != null:
			ob.hp -= z.dps * dt
			z.camina = false
			z.atac = 0.3
		else:
			z.x += dir * z.vel * dt
	# estela: la casa nunca es atravesada si la puerta cierra el paso


# ---------------------------------------------------------------- persistencia

func guardar_historial(ruta: String) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(historial, "  "))


func cargar_historial(ruta: String) -> void:
	if not FileAccess.file_exists(ruta):
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return
	var datos = JSON.parse_string(f.get_as_text())
	if datos is Array:
		historial = datos
		gen = historial.size() + 1
		aviso("GENERACIÓN %d" % gen, 5.0)
