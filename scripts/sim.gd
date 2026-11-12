class_name Sim
extends RefCounted
## Simulación pura (sin dibujo) de la casa de sobrevivientes.
## Cinco plantas, 50 residentes; huerto seguro al oeste, invasion por el este.

const ANCHO := 1260.0                       # lienzo en px; 25 px = 1 metro
const PISO_Y := [0.0, 4.8, 9.6, 14.4, 19.2]                 # altura de cada piso en metros
const CASA_X0 := 150.0
const CASA_X1 := 790.0                     # pared derecha: la puerta da al patio
const ESCALERA_X := 490.0
const MAX_VIVOS := 50
const DIA_LEN := 120.0
const VEL_S := 33.0
const CARRILES := [-0.8, 0.8, 2.4, 4.0]    # profundidad del patio en metros
const CAMAS := [180.0, 210.0, 240.0, 270.0, 300.0, 330.0, 360.0, 390.0, 420.0, 450.0, 560.0, 590.0, 620.0, 650.0, 680.0, 710.0, 740.0]
const ESCALERA_Y := 2.8
const PASILLO_Y := 0.6
const PUERTA_Y := 0.8
const COCINA_X := 235.0
const MESA_X := 365.0
const BANCO_X := 640.0
const VENTANA_DER := 770.0
const MAX_TIRADORES := 8
const TIRO_RESERVA_X := CASA_X1 - 85.0
const TABLA_HP := 30.0
const TABLAS_BARRERA := 5
# Almacen del oeste (junto a los huertos), cajas de municion junto a las ventanas y despensa de cocina.
const ALM_X0 := 8.0
const ALM_X1 := 70.0
const ALM_Y0 := 3.6
const ALM_Y1 := 6.8
const ALM_ACCESO_X := 40.0
const ALM_ACCESO_Y := 4.6
const CAJA_MAX := 90
const CARGA_MUN := 45
const CARGA_CRUDO := 12
const COCINA_MIN := 10
const ARMAS := {
	"Pistola": {"cargador": 12, "cadencia": 0.65, "recarga": 1.6, "dano": 20.0},
	"AK": {"cargador": 30, "cadencia": 0.18, "recarga": 2.5, "dano": 22.0},
	"M4": {"cargador": 30, "cadencia": 0.14, "recarga": 2.1, "dano": 18.0},
}
const FRASES := {
	"comer": ["Qué hambre...", "A comer.", "Ñam."],
	"dormir": ["Me caigo de sueño.", "A la cama.", "Zzz..."],
	"cocinar": ["Preparo para luego.", "Algo caliente.", "Huele bien."],
	"construir": ["Más muros.", "Esto aguanta.", "A clavar."],
	"reparar": ["Arreglo esto.", "Otro parche.", "Aguanta, puerta."],
	"cultivar": ["A la huerta.", "Más comida.", "Cosechando."],
	"talar": ["Necesitamos madera.", "A talar.", "Leña."],
	"disparar": ["¡Vienen!", "¡A mi ventana!", "Apunten."],
	"recoger": ["Voy al almacén.", "Traigo cosas.", "A cargar."],
	"entregar": ["Aquí tienen.", "Reposición.", "Dejo esto."],
	"luchar": ["¡Dentro!", "¡Se metió uno!", "¡Fuera de aquí!"],
	"volver": ["¡Adentro!", "¡Corran!", "Me vuelvo."],
	"pasear": ["...", "Qué silencio.", "Tengo miedo."],
	"hola": ["¡Hola!", "¡Llegué!", "¿Hay sitio?"],
	"muerte": ["Aaah...", "No...", "Díganle a mamá..."],
}

var rng := RandomNumberGenerator.new()
var navegacion := Navegacion.new()
var next_zombie := 1
var config := {"regalos": {"Rose": "zombis", "GG": "persona"}, "ambiente": false}

var gen := 1
var t := 0.0
var supervivientes: Array = []
var zombis: Array = []
var barreras: Array = []
var puertas: Array = []
var huertos: Array = []
var arboles: Array = []
var tumbas: Array = []
var stock := {}          # cocina y taller: crudo (listo para cocinar), comida cocinada, madera
var alm := {}            # almacen: suministros (comida SIN cocinar) y municion
var cajas: Array = []    # una caja de municion junto a cada ventana
var cocina_ref := {"tipo": "cocina", "ax": COCINA_X + 24.0, "ay": 1.4, "f": 0, "entrante": 0}
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
var registrados := {} # Una identidad por generacion, incluso tras morir.
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
	registrados.clear()
	stock = {"crudo": 12, "comida": 20, "madera": 100}
	alm = {"crudo": 60, "municion": 120}
	cocina_ref.entrante = 0
	cajas = []
	for pv in puestos_ventana():
		cajas.append({"puesto": pv.puesto, "x": CASA_X1 - (90.0 if pv.f == 0 else 18.0), "y": pv.y + 0.7, "ax": CASA_X1 - (101.0 if pv.f == 0 else 25.0), "ay": pv.y + 0.7, "f": pv.f, "mun": 40, "max": CAJA_MAX, "entrante": 0})
	navegacion.actualizar_cajas(cajas)
	puertas = []
	for puesto in puestos_ventana():
		if puesto.f != 0:
			continue
		barreras.append({"id":puesto.puesto,"x":CASA_X1,"px":CASA_X1-14.0,"y":puesto.y,"f":puesto.f,"hp":150.0,"max":150.0})
	huertos = []
	for x in [30.0, 70.0, 110.0]:
		for profundidad in [0.3, 2.3]:
			huertos.append({"x": x, "y": profundidad, "listo": 0.0, "ocupado": false})
	arboles = []
	for par in [[126.0, 3.4], [138.0, 5.0], [146.0, 6.4]]:
		arboles.append({"x": par[0], "y": par[1], "listo": 0.0, "ocupado": false})
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
	var clave := regalo.strip_edges().to_lower()
	var canonico := "Rose" if clave in ["rose", "rosa", "rosita"] else ("GG" if clave == "gg" else regalo)
	var tipo: String = config.regalos.get(canonico, "suministros")
	for i in range(maxi(cantidad, 1)):
		match tipo:
			"persona":
				_recibir_gg(usuario)
			"zombis":
				_recibir_rosa(usuario)
			_:
				_suministros(usuario, null)


func _buscar_vivo(usuario: String) -> Variant:
	for s in supervivientes:
		if s.hp > 0.0 and String(s.nombre).to_lower() == usuario.strip_edges().to_lower():
			return s
	return null


func _recibir_gg(usuario: String) -> void:
	usuario = usuario.strip_edges()
	if usuario.is_empty():
		return
	var identidad := usuario.to_lower()
	var s = _buscar_vivo(usuario)
	if s == null and registrados.has(identidad):
		_suministros(usuario, null)
		return
	if s == null:
		if vivos() >= MAX_VIVOS:
			_suministros(usuario, null)
			return
		s = _nuevo_superviviente(usuario)
		supervivientes.append(s)
		registrados[identidad] = s.id
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
	alm.crudo += 2 + n / 2          # suministros: comida sin cocinar, a la despensa del almacen
	alm.municion += 10 + n          # municion: al almacen; alguien tiene que repartirla a las cajas
	stock.madera += 3
	for o in supervivientes:
		if o.hp > 0.0:
			o.hp = minf(100.0, o.hp + 15.0)
	if s != null:
		s.aportes += 1
		s.nivel_arma = mini(4, s.nivel_arma + 1)
		if s.modelo_arma == "Pistola":
			s.modelo_arma = "AK" if rng.randf() < 0.5 else "M4"
			s.cartuchos = ARMAS[s.modelo_arma].cargador
		s.arma = s.modelo_arma + " +" + str(s.nivel_arma - 1)
		_texto("+suministros / " + s.arma, s.x, PISO_Y[s.f] + 2.3, Color(1, 0.9, 0.3))
	aviso("%s: +%d suministros y +%d munición al almacén" % [usuario, 2 + n / 2, 10 + n], 3.5)


func _recibir_rosa(usuario: String) -> void:
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
	var sorteo := rng.randf()
	var modelo := "AK" if sorteo < 0.3 else ("M4" if sorteo < 0.55 else "Pistola")
	var s := {
		"id": next_id, "nombre": nombre,
		"x": CASA_X0+30.0+rng.randf_range(0.0,25.0), "f": 0, "vy": 0.0, "y": PASILLO_Y, "y_casa": rng.randf_range(1.4, 3.6),
		"hp": 100.0, "hambre": rng.randf_range(10.0, 35.0), "energia": rng.randf_range(70.0, 100.0),
		"escalera": {}, "accion": "", "ox": 0.0, "of": 0, "oy": PASILLO_Y, "preparando": false, "trab": 0.0, "dur": 0.0, "llego": false,
		"cd_dec": 0.0, "cd_ataque": 0.0, "flash": 0.0, "ref": null, "lado": 0,
		"cama_id": -1, "modelo_arma": modelo, "nivel_arma": 1, "arma": modelo,
		"cartuchos": ARMAS[modelo].cargador, "recarga": 0.0, "retroceso": 0.0,
		"tiempo_tiro": 10.0, "tiros": 0, "apunta_x": CASA_X1 + 150.0, "apunta_y": PUERTA_Y, "apunta_z": 1.0, "puesto": -1, "aportes": 0, "kills": 0, "dir": 1, "camina": false, "anim": rng.randf() * 10.0,
		"dice": "", "dice_ttl": 0.0, "golpe": 0.0, "carga": {},
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
		if s.hp > 0.0:
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
	# Las defensas rotas persisten: se reconstruyen tabla por tabla.
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
	_perder_carga(s)
	muertes += 1
	fx.append({"k": "muerte_s", "x": s.x, "y": s.y, "z": s.vy + 1.0, "dir": s.dir})
	tumbas.append({"x": s.x, "y": s.y, "nombre": s.nombre})
	cadaveres.append({"id": "s%d" % s.id, "x": s.x, "y": s.y, "z": s.vy, "tipo": "", "dir": s.dir, "t": 0.0, "surv": true, "modelo_arma":s.modelo_arma, "camisa": s.camisa, "look": s.look})
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
		"id": next_zombie, "x": ANCHO + 12.0, "y": CARRILES[rng.randi() % CARRILES.size()], "f": 0, "vy": 0.0, "lado": 1,
		"entrada": rng.randi_range(0,1), "escalera": {}, "tipo": tipo, "cd": 0.0, "dentro": false, "anim": rng.randf() * 10.0, "esc_t": 0.0, "dir": 1,
		"camina": true, "atac": 0.0, "golpe": 0.0,
	}
	match tipo:
		"corredor":
			z.hp = 12.0; z.vel = rng.randf_range(30.0, 36.0); z.dmg = 6.0; z.dps = 6.0
		"bruto":
			z.hp = 55.0; z.vel = rng.randf_range(11.0, 14.0); z.dmg = 18.0; z.dps = 28.0
		_:
			z.hp = 18.0; z.vel = rng.randf_range(15.0, 20.0); z.dmg = 8.0; z.dps = 8.0
	z.max = z.hp
	zombis.append(z)
	next_zombie += 1


# ---------------------------------------------------------------- superviviente

func _vida(s: Dictionary, dt: float) -> void:
	# Reaccion inmediata ante manos en las tablas; nadie repara ni se queda pegado al hueco.
	if s.f == 0 and s.escalera.is_empty() and s.x > TIRO_RESERVA_X + 8.0 and s.x < CASA_X1:
		for b in barreras:
			if absf(s.y - b.y) < 1.1 and (_ventana_peligrosa(0) or _ventana_peligrosa(1)):
				if s.accion == "disparar" and s.puesto >= 0:
					var seguro := _puesto_ventana(s)
					if not seguro.is_empty(): _comenzar(s, seguro)
					else: _comenzar(s, {"tipo":"volver", "x":TIRO_RESERVA_X, "y":b.y, "f":0})
				else:
					_comenzar(s, {"tipo":"volver", "x":TIRO_RESERVA_X, "y":b.y, "f":0})
				s.cd_dec = maxf(s.cd_dec, 0.5)
				break
	s.cd_ataque -= dt
	s.tiempo_tiro += dt
	s.retroceso = maxf(0.0, s.retroceso - dt * 7.0)
	if s.recarga > 0.0:
		s.recarga = maxf(0.0, s.recarga - dt)
		if s.recarga <= 0.0:
			var cj = _caja_de(s)
			if cj != null:
				var n: int = mini(ARMAS[s.modelo_arma].cargador - s.cartuchos, cj.mun)
				cj.mun -= n
				s.cartuchos += n
	s.flash -= dt
	s.golpe = maxf(0.0, s.golpe - dt)
	s.dice_ttl -= dt
	s.anim += dt * (7.0 if s.camina else 1.0)
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
	return s.x > CASA_X1 + 2.0 or s.x < CASA_X0 - 2.0


func _zombi_cerca_casa(rango: float) -> Variant:
	var mejor = null
	var md := 1e9
	for z in zombis:
		if z.dentro or z.hp <= 0.0:
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
		if not z.dentro or z.hp <= 0.0 or z.f != s.f:
			continue
		var d: float = Vector2(z.x - s.x, (z.y - s.y) * 25.0).length()
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


func _dañado(trabajador: Variant = null) -> Variant:
	var mejor = null
	var mr := 1.0
	for p in puertas:
		var r: float = p.hp / p.max
		if r < mr and not _reservado(p, trabajador):
			mr = r
			mejor = p
	for b in barreras:
		if _ventana_peligrosa(0) or _ventana_peligrosa(1):continue
		var r: float = b.hp / b.max
		if r < mr and not _reservado(b, trabajador):
			mr = r
			mejor = b
	return mejor


func _reservado(obj: Variant, excepto: Variant = null) -> bool:
	for o in supervivientes:
		if not is_same(o, excepto) and o.accion == "reparar" and is_same(o.ref, obj):
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
	var hay_municion: bool = s.cartuchos > 0
	var noche := es_noche()
	var pop := vivos()

	var zd = _zombi_dentro_cercano(s)
	if zd != null:
		# Una brecha tiene prioridad sobre reparar, cocinar o transportar.
		var distancia: float = Vector2(zd.x - s.x, (zd.y - s.y) * 25.0).length()
		var ox: float = s.x
		var oy: float = s.y
		if hay_municion:
			if distancia > 130.0 or not _linea_tiro_libre(s, zd):
				ox = zd.x - signf(zd.x - s.x) * 85.0
				oy = zd.y
			elif distancia < 32.0:
				ox = s.x - signf(zd.x - s.x) * 38.0
		else:
			ox = zd.x - signf(zd.x - s.x) * 12.0
			oy = zd.y
		ox = clampf(ox, CASA_X0 + 10.0, CASA_X1 - 14.0)
		if not navegacion.transitable(ox / 25.0, oy, s.f):
			ox = s.x
			oy = s.y
		_comenzar(s, {"tipo":"luchar", "x":ox, "y":oy, "f":s.f})
		return
	if amen == null and s.accion == "disparar":
		_soltar(s)
		s.accion = ""
		s.recarga = 0.0
	# Terminar una tarea breve o su desplazamiento evita cambiar de rumbo a cada decision.
	if amen == null and s.accion not in ["", "disparar", "luchar", "volver"] and s.hambre < 90.0 and s.energia > 8.0:
		return

	if amen != null:
		if fuera:
			c.append([96.0, {"tipo": "volver", "x": CASA_X1 - 36.0, "f": 0}])
		elif s.hp > 20.0:
			var puesto := _puesto_ventana(s)
			if not puesto.is_empty():
				c.append([84.0 * s.val, puesto])

	if s.hambre >= 55.0 and stock.comida > 0:
		c.append([(s.hambre - 20.0) * 1.1 * s.glot, {"tipo": "comer", "x": MESA_X + float(s.id % 8 - 4) * 12.0, "f": 0, "dur": 3.0}])

	var durmiendo: bool = s.accion == "dormir"
	if s.energia < 30.0 or (durmiendo and s.energia < 92.0):
		c.append([60.0 + maxf(0.0, 30.0 - s.energia), _cama(s)])
	elif noche and s.energia < 65.0:
		c.append([38.0, _cama(s)])

	var urg := 20.0 if amen != null else 0.0

	var cocina := _puesto_cocina(s)
	if stock.crudo >= 1 and stock.comida < objetivo_comida() and not cocina.is_empty():
		var prioridad := 67.0 if amen == null else 46.0
		c.append([(prioridad + (15.0 if stock.comida == 0 else 0.0)) * s.tr, cocina])


	if stock.madera >= 1:
		var d = _dañado(s)
		if d != null:
			var ox2: float = d.px - 8.0
			c.append([(90.0 + urg) * s.tr, {"tipo": "reparar", "x": ox2, "f": d.f, "y": d.y, "dur": 0.8, "ref": d}])

	if not noche:
		if stock.crudo + alm.crudo < maxi(90, 10 * pop) and (_contar("cultivar") < maxi(1, ceili(pop / 8.0)) or s.accion == "cultivar"):
			var h = _libre_recurso(huertos, 200.0)
			if h != null:
				c.append([40.0 * s.tr, {"tipo": "cultivar", "x": h.x, "f": 0, "dur": 6.0, "ref": h}])
		if stock.madera < maxi(40, pop * 3) and (_contar("talar") < 2 or s.accion == "talar"):
			var a = _libre_recurso(arboles, 200.0)
			if a != null:
				c.append([38.0 * s.tr, {"tipo": "talar", "x": a.x, "f": 0, "dur": 6.0, "ref": a}])

	# logistica: llevar lo que hay en el almacen a donde hace falta
	var lleva: int = s.carga.get("n", 0)
	if lleva > 0:
		var d: Dictionary = s.carga.dest
		c.append([93.0, {"tipo": "entregar", "x": d.ax, "y": d.ay, "f": d.f, "dur": 1.0}])
	elif _contar("recoger") + _contar("entregar") < 3 or s.accion == "recoger":
		var plan = _plan_reparto(s)
		if plan != null:
			var u := 0.0
			if plan.tipo == "caja" and plan.dest.mun < 15:
				u += 14.0
			if plan.tipo == "caja" and amen != null:
				u += 14.0
			if plan.tipo == "cocina" and stock.comida == 0:
				u += 14.0
			c.append([(58.0 + u) * s.tr, {"tipo": "recoger", "x": ALM_ACCESO_X, "y": ALM_ACCESO_Y, "f": 0, "dur": 1.2, "ref": plan.dest}])

	var px: float = s.x
	var pf: int = s.f
	for intento in range(24):
		var candidato := rng.randf_range(CASA_X0 + 30.0, CASA_X1 - 30.0)
		var planta := rng.randi() % PISO_Y.size()
		if navegacion.transitable(candidato / 25.0, PASILLO_Y, planta):
			px = candidato
			pf = planta
			break
	c.append([8.0, {"tipo": "pasear", "x": px, "f": pf, "dur": rng.randf_range(1.5, 4.0)}])

	var mejor = null
	var mp := -1e9
	for par in c:
		var p: float = par[0] + rng.randf() * 6.0
		if par[1].tipo == s.accion:
			p += 20.0
		if p > mp:
			mp = p
			mejor = par[1]
	_comenzar(s, mejor)


func objetivo_comida() -> int:
	# Seis raciones por persona: preparar antes de que alguien tenga hambre.
	return maxi(12, vivos() * 6)


func _puesto_cocina(s: Dictionary) -> Dictionary:
	var limite := mini(4, maxi(1, ceili(vivos() / 6.0)))
	for i in range(limite):
		var x := COCINA_X + i * 16.0
		var ocupado := false
		for otro in supervivientes:
			if otro.id != s.id and otro.accion == "cocinar" and is_equal_approx(otro.ox, x):
				ocupado = true
				break
		if not ocupado:
			return {"tipo":"cocinar", "x":x, "y":1.4, "f":0, "dur":6.0}
	return {}


func _reservado_recoger(dest: Variant, excepto: Variant) -> bool:
	for o in supervivientes:
		if not is_same(o, excepto) and o.accion == "recoger" and is_same(o.ref, dest):
			return true
	return false


func _plan_reparto(s: Dictionary) -> Variant:
	# Devuelve {"tipo","dest"} con la necesidad mas urgente que nadie esta atendiendo.
	if s.accion == "recoger" and s.ref != null:
		var r = s.ref
		if r.get("tipo", "caja") == "cocina":
			if alm.crudo > 0 and stock.crudo + r.entrante < COCINA_MIN + 6:
				return {"tipo": "cocina", "dest": r}
		elif alm.municion > 0 and r.mun + r.entrante < r.max * 0.85:
			return {"tipo": "caja", "dest": r}
	# La comida preparada necesita una despensa abastecida antes de llenar cajas de reserva.
	if stock.comida < objetivo_comida() and stock.crudo + cocina_ref.entrante < maxi(COCINA_MIN, vivos() * 2) and alm.crudo > 0 and not _reservado_recoger(cocina_ref, s):
		return {"tipo":"cocina", "dest":cocina_ref}
	var peor = null
	var pm := 1e9
	for cj in cajas:
		var tot: int = cj.mun + cj.entrante
		if tot < cj.max * 0.6 and tot < pm and not _reservado_recoger(cj, s):
			pm = tot
			peor = cj
	if peor != null and alm.municion > 0:
		return {"tipo": "caja", "dest": peor}
	if stock.crudo + cocina_ref.entrante < COCINA_MIN and alm.crudo > 0 and not _reservado_recoger(cocina_ref, s):
		return {"tipo": "cocina", "dest": cocina_ref}
	return null


func _perder_carga(s: Dictionary) -> void:
	var n: int = s.carga.get("n", 0)
	if n > 0:
		s.carga.dest.entrante = maxi(0, s.carga.dest.entrante - n)
	s.carga = {}


func _caja_de(s: Dictionary) -> Variant:
	if s.accion == "disparar" and s.llego and s.puesto >= 0 and s.puesto < cajas.size():
		var c: Dictionary = cajas[s.puesto]
		if Vector2(s.x - c.ax, (s.y - c.ay) * 25.0).length() < 32.0:
			return c
	for cj in cajas:
		if cj.f == s.f and Vector2(s.x - cj.ax, (s.y - cj.ay) * 25.0).length() < 32.0:
			return cj
	return null


func aviso_municion() -> String:
	var disponible := 0
	var en_transito := 0
	for cj in cajas:
		disponible += int(cj.mun)
	for humano in supervivientes:
		if humano.hp > 0:
			disponible += int(humano.cartuchos)
			if humano.carga.get("kind", "") == "municion":
				en_transito += int(humano.carga.get("n", 0))
	if disponible + en_transito + int(alm.municion) == 0:
		return "¡SIN MUNICIÓN!"
	if disponible < 60:
		return "REPARTIR MUNICIÓN" if alm.municion + en_transito > 0 else "MUNICIÓN BAJA"
	return ""


func municion_total() -> int:
	var n: int = alm.municion
	for cj in cajas:
		n += cj.mun
	return n


func _ocupantes_ventana(piso: int) -> int:
	var n := 0
	for o in supervivientes:
		if o.accion == "disparar" and o.of == piso:
			n += 1
	return n


func camas() -> Array:
	return navegacion.datos.camas


func _cama(s: Dictionary) -> Dictionary:
	for cama in camas():
		var usada := false
		for o in supervivientes:
			if o.id!=s.id and o.accion=="dormir" and o.cama_id==cama.id:
				usada=true
		if not usada:
			return {"tipo":"dormir","x":cama.acceso_x,"y":cama.acceso_y,"f":cama.f,"cama":cama.id}
	return {"tipo":"pasear","x":ESCALERA_X,"f":1,"dur":3.0}


func puestos_ventana() -> Array:
	var puestos: Array = []
	for piso in range(4):
		for i in range(2):
			puestos.append({"tipo": "disparar", "x": CASA_X1-12.0, "y": 1.1 + i * 2.1, "f": piso, "lado": 1, "puesto": puestos.size()})
	return puestos


func _ventana_peligrosa(puesto: int) -> bool:
	if puesto < 0 or puesto >= barreras.size():return false
	var b: Dictionary = barreras[puesto]
	for z in zombis:
		if z.hp > 0 and not z.dentro and z.entrada == puesto and z.x >= b.x - 6.0 and z.x < b.x + 55.0:
			b.peligro_hasta = t + 4.0
			return true
	return float(b.get("peligro_hasta", -1.0)) > t


func _puesto_ventana(s: Dictionary) -> Dictionary:
	var puestos := puestos_ventana()
	for p in puestos:
		if p.f == 0 and (_ventana_peligrosa(0) or _ventana_peligrosa(1) or s.cartuchos <= 0):
			p.x = TIRO_RESERVA_X
	if s.accion == "disparar" and s.puesto >= 0 and s.puesto < MAX_TIRADORES:
		if s.cartuchos > 0 or cajas[s.puesto].mun > 0:
			return puestos[s.puesto]
		return {}
	for puesto in puestos:
		if s.cartuchos <= 0 and cajas[puesto.puesto].mun <= 0:
			continue
		var ocupado := false
		for o in supervivientes:
			if o.id != s.id and o.accion == "disparar" and o.puesto == puesto.puesto:
				ocupado = true
		if not ocupado:
			return puesto
	return {}


func _comenzar(s: Dictionary, a: Dictionary) -> void:
	var ref_nuevo = a.get("ref", null)
	if a.tipo == s.accion and is_same(ref_nuevo, s.ref):
		# misma acción y mismo objetivo: solo se ajusta el destino
		if a.tipo in ["luchar", "disparar", "volver"]:
			if Vector2(s.ox - a.x, (s.oy - a.get("y", s.oy)) * 25.0).length() > 8.0 or s.of != a.f:
				s.erase("ruta_destino")
				s.llego = false
			s.ox = a.x
			s.of = a.f
			s.lado = a.get("lado", 0)
			s.oy = a.get("y", s.oy)
			s.puesto = a.get("puesto", -1)
		return
	_soltar(s)
	s.trab = 0.0
	s.sin_progreso = 0.0
	if rng.randf() < 0.18:
		_decir(s, a.tipo)
	s.cama_id = a.get("cama",-1)
	s.erase("ruta_destino")
	s.accion = a.tipo
	s.ox = a.x
	s.of = a.f
	s.dur = a.get("dur", 0.0)
	s.lado = a.get("lado", 0)
	s.llego = false
	s.preparando = false
	s.oy = a.get("y", _profundidad_puesto(a.tipo, a.get("ref", null)))
	s.puesto = a.get("puesto", -1)
	var ref = a.get("ref", null)
	if ref != null:
		s.ref = ref
		if ref.has("ocupado"):
			ref.ocupado = true


func _soltar(s: Dictionary) -> void:
	s.puesto = -1
	if s.ref != null and s.ref.has("ocupado"):
		s.ref.ocupado = false
	s.ref = null


func _profundidad_puesto(accion: String, ref: Variant) -> float:
	match accion:
		"cocinar", "construir": return 1.4
		"comer": return 1.2
		"dormir": return 0.6
		"cultivar", "talar": return float(ref.y) if ref != null else PUERTA_Y
		"disparar": return 2.4
		"reparar": return PUERTA_Y
		"recoger": return ALM_ACCESO_Y
	return PASILLO_Y


func _andar_x(s: Dictionary, meta: float, dt: float) -> bool:
	var d: float = meta - s.x
	if absf(d) < 0.05:
		return true
	s.x = move_toward(s.x, meta, VEL_S * dt)
	s.dir = int(signf(d))
	s.camina = true
	return absf(s.x - meta) < 0.05


func _andar_y(s: Dictionary, meta: float, dt: float) -> bool:
	if absf(s.y - meta) > 0.02:
		s.y = move_toward(s.y, meta, 1.4 * dt)
		s.camina = true
	return absf(s.y - meta) < 0.02


func _mover(s: Dictionary, tx: float, tf: int, dt: float) -> bool:
	s.camina=false
	if not s.escalera.is_empty():
		_avanzar_escalera(s,dt)
		return false
	var velocidad: float=s.get("vel",VEL_S)/25.0
	for umbral in [CASA_X0,CASA_X1]:
		if ((s.x>umbral and tx<=umbral) or (s.x<=umbral and tx>umbral)) and s.f==0:
			var destino_umbral: float=umbral+(1.0 if tx>umbral else -1.0)
			if absf(s.y-PUERTA_Y)>.02:destino_umbral=umbral+(5.0 if s.x>umbral else -5.0)
			navegacion.seguir(s,destino_umbral,PUERTA_Y,0,dt,velocidad)
			return false
	if s.f!=tf:
		var entrada:=ESCALERA_X if tf>s.f else ESCALERA_X+40.0
		if navegacion.seguir(s,entrada,PASILLO_Y,s.f,dt,velocidad):
			_empezar_escalera(s,tf)
		return false
	return navegacion.seguir(s,tx,s.oy,tf,dt,velocidad)


func _empezar_escalera(c: Dictionary, destino: int) -> void:
	var hacia := 1 if destino > c.f else -1
	c.escalera = {"desde": c.f, "hasta": c.f + hacia, "p": 0.0}
	c.camina = true


func _avanzar_escalera(c: Dictionary, dt: float) -> void:
	var e: Dictionary = c.escalera
	e.p = minf(1.0, e.p + dt / 3.0)
	var sube: bool = e.hasta > e.desde
	var p: float = e.p if sube else 1.0 - e.p
	var base: float = PISO_Y[mini(e.desde, e.hasta)]
	if p < 0.45:
		var u := p / 0.45
		c.x = ESCALERA_X
		c.y = PASILLO_Y + u * 3.0
		c.vy = base + ceilf(u * 12.0) * 0.2
	elif p < 0.55:
		c.x = lerpf(ESCALERA_X, ESCALERA_X + 40.0, (p - 0.45) / 0.1)
		c.y = PASILLO_Y + 3.0
		c.vy = base + 2.4
	else:
		var u := (p - 0.55) / 0.45
		c.x = ESCALERA_X + 40.0
		c.y = PASILLO_Y + (1.0 - u) * 3.0
		c.vy = base + 2.4 + ceilf(u * 12.0) * 0.2
	c.camina = true
	if e.p >= 1.0:
		c.f = e.hasta
		c.vy = PISO_Y[c.f]
		c.y = PASILLO_Y
		c.escalera = {}
	c.erase("ruta_destino")


func _actuar(s: Dictionary, dt: float) -> void:
	s.llego = _mover(s, s.ox, s.of, dt)
	if not s.llego and not s.camina and s.escalera.is_empty():
		s.sin_progreso = s.get("sin_progreso", 0.0) + dt
		if s.sin_progreso > 2.5:
			_soltar(s)
			s.accion = ""
			s.cd_dec = 0.0
	else:
		s.sin_progreso = 0.0
	match s.accion:
		"comer", "cocinar", "construir", "reparar", "cultivar", "talar", "pasear", "recoger", "entregar":
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
		"cocinar":
			if stock.crudo >= 1:
				stock.crudo -= 1
				stock.comida += 2
				_texto("+2 comida", s.x, PISO_Y[s.f] + 2.1, Color(1, 0.7, 0.3))
		"recoger":
			var d = s.ref
			if d != null:
				if d.get("tipo", "caja") == "cocina":
					var n: int = mini(CARGA_CRUDO, alm.crudo)
					if n > 0:
						alm.crudo -= n
						d.entrante += n
						s.carga = {"dest": d, "n": n, "kind": "crudo"}
						_texto("+%d suministros" % n, s.x, PISO_Y[s.f] + 2.1, Color(0.9, 0.8, 0.5))
				else:
					var n: int = mini(CARGA_MUN, mini(alm.municion, d.max - d.mun - d.entrante))
					if n > 0:
						alm.municion -= n
						d.entrante += n
						s.carga = {"dest": d, "n": n, "kind": "municion"}
						_texto("+%d munición" % n, s.x, PISO_Y[s.f] + 2.1, Color(0.9, 0.8, 0.5))
		"entregar":
			var n: int = s.carga.get("n", 0)
			if n > 0:
				var d: Dictionary = s.carga.dest
				d.entrante = maxi(0, d.entrante - n)
				if s.carga.kind == "crudo":
					stock.crudo += n
					_texto("+%d a cocina" % n, s.x, PISO_Y[s.f] + 2.1, Color(0.9, 0.8, 0.5))
				else:
					d.mun = mini(d.max, d.mun + n)
					_texto("+%d a la caja" % n, s.x, PISO_Y[s.f] + 2.1, Color(0.7, 0.9, 0.5))
				s.carga = {}
		"reparar":
			var r = s.ref
			if r != null and stock.madera >= 1:
				stock.madera -= 1
				r.hp = minf(r.max, r.hp + TABLA_HP)
				_texto("+1 tabla", s.x, PISO_Y[s.f] + 2.0, Color(0.9, 0.75, 0.4))
		"cultivar":
			if s.ref != null:
				s.ref.listo = t + 70.0
				alm.crudo += 2
				_texto("+2 suministros", s.x, 2.1, Color(0.5, 1, 0.5))
		"talar":
			if s.ref != null:
				s.ref.listo = t + 70.0
				stock.madera += 3
				_texto("+3 madera", s.x, 2.1, Color(0.9, 0.7, 0.4))
	_soltar(s)
	s.accion = ""
	s.cd_dec = 0.0


func _linea_tiro_libre(s: Dictionary, z: Dictionary) -> bool:
	var a := Vector2(s.x / 25.0, s.y)
	var b := Vector2(z.x / 25.0, z.y)
	var pasos := maxi(1, ceili(a.distance_to(b) / 0.2))
	for i in range(1, pasos):
		var p := a.lerp(b, float(i) / pasos)
		if not navegacion.transitable(p.x, p.y, s.f):
			return false
	return true


func _reflejo(s: Dictionary) -> void:
	if s.cd_ataque > 0.0 or s.recarga > 0.0 or not s.escalera.is_empty() or s.accion == "dormir":
		return
	var objetivo = null
	var md := 1e9
	var afuera := _fuera(s)
	var en_ventana: bool = s.accion == "disparar" and s.llego and not s.camina and s.puesto >= 0 and s.puesto < MAX_TIRADORES
	var rango_v := 650.0
	for z in zombis:
		if z.hp <= 0.0:
			continue
		var d := 1e9
		if z.dentro:
			if z.f == s.f:
				d = Vector2(z.x - s.x, (z.y - s.y) * 25.0).length()
				if d > 240.0 or not _linea_tiro_libre(s, z):
					d = 1e9
		else:
			if en_ventana or (afuera and z.f == s.f):
				d = absf(z.x - s.x)
				if d > rango_v:
					d = 1e9

		if d < md:
			md = d
			objetivo = z
	if objetivo == null:
		return
	var caja = _caja_de(s)
	if s.cartuchos <= 0 and caja != null and caja.mun > 0:
		s.recarga = ARMAS[s.modelo_arma].recarga
		return
	if s.cartuchos > 0:
		var arma: Dictionary = ARMAS[s.modelo_arma]
		s.cartuchos -= 1
		s.cd_ataque = arma.cadencia / (1.0 + (s.nivel_arma - 1) * 0.12)
		s.flash = 0.065
		s.retroceso = 1.0
		s.tiempo_tiro = 0.0
		s.tiros += 1
		s.apunta_x = objetivo.x
		s.apunta_y = objetivo.y
		s.apunta_z = objetivo.vy + 1.0
		s.dir = 1 if objetivo.x > s.x else -1
		var prob := 0.8 if md < 160.0 else 0.6
		var tiro := {"k":"disparo3d", "x0":s.x+s.dir*(22.0 if s.modelo_arma!="Pistola" else 8.0),"d0":s.y,"z0":s.vy+1.3,"x1":objetivo.x,"d1":objetivo.y,"z1":objetivo.vy+1.0,"ttl":0.045,"origen":s.id}
		disparos.append(tiro)
		fx.append(tiro.duplicate())
		if rng.randf() < prob:
			_dañar_zombi(objetivo, arma.dano * rng.randf_range(0.85, 1.15) * (1.0 + (s.nivel_arma - 1) * 0.2), s)
	elif md < 18.0 and objetivo.f == s.f and objetivo.dentro:
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
		cadaveres.append({"id": "z%d" % z.id, "x": z.x, "y": z.y, "z": z.vy, "tipo": z.tipo, "dir": z.dir, "t": 0.0, "surv": false})
		kills += 1
		s.kills += 1
		_texto("+1", z.x, z.vy + 2.0, Color(0.6, 1, 0.6))


# ---------------------------------------------------------------- zombi

func _objetivo_zombi(z: Dictionary) -> Variant:
	var mejor = null
	var md := 1e9
	for s in supervivientes:
		if s.x < CASA_X0 or s.hp <= 0.0:
			continue # El huerto vallado es una zona segura real, no solo decoracion.
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
	var ventana: Dictionary = barreras[z.entrada]
	if ventana.hp > 0 and z.x >= ventana.x and z.x - ventana.x < 9.0:
		return ventana
	return null


func _zombi(z: Dictionary, dt: float) -> void:
	if z.hp <= 0.0:
		return
	z.cd -= dt
	if not z.escalera.is_empty():
		z.anim += dt * 6.0
		_avanzar_escalera(z, dt)
		return
	z.atac = maxf(0.0, z.atac - dt)
	z.golpe = maxf(0.0, z.golpe - dt)
	z.anim += dt * 6.0
	if not z.dentro and z.x < float(barreras[z.entrada].x) - 6.0:
		z.dentro = true
	if not z.dentro and z.x < float(barreras[z.entrada].x) + 30.0:
		var entrada: Dictionary = barreras[z.entrada]
		z.y = move_toward(z.y, entrada.y, 1.8 * dt)
		if absf(z.y - entrada.y) > 0.15:
			z.camina = true
			return
	var obj = _objetivo_zombi(z)
	if z.dentro and obj!=null:
		if obj.f==z.f and absf(obj.x-z.x)<16.0 and absf(obj.y-z.y)<1.2:
			z.camina=false
			if z.cd<=0:
				obj.hp-=z.dmg;z.cd=1.1;z.atac=.5;obj.golpe=.12
				fx.append({"k":"golpe_s","x":obj.x,"y":obj.y,"z":obj.vy+1.1,"dir":z.dir,"mata":obj.hp<=0})
		else:
			z.oy=obj.y
			_mover(z,obj.x,obj.f,dt)
		return
	var dir := 0
	if obj != null:
		if obj.f != z.f and z.dentro:
			var entrada := ESCALERA_X if obj.f > z.f else ESCALERA_X + 40.0
			if absf(z.x - entrada) < 2.0:
				z.x = entrada
				z.y = move_toward(z.y, PASILLO_Y, 1.2 * dt)
				if absf(z.y - PASILLO_Y) < 0.05:
					_empezar_escalera(z, obj.f)
			else:
				dir = int(signf(entrada - z.x))
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
			var tablas_antes := ceili(ob.hp / TABLA_HP)
			ob.hp = maxf(0.0, ob.hp - z.dps * dt)
			if ceili(ob.hp / TABLA_HP) < tablas_antes:
				fx.append({"k": "tabla", "x": ob.x, "y": ob.y, "z": PISO_Y[ob.f]+1.0, "dir": -1})
			z.camina = false
			z.atac = 0.3
		else:
			var proximo: float = z.x + dir * z.vel * dt
			# Barrido: una zancada grande nunca atraviesa una defensa viva.
			if dir < 0 and not z.dentro:
				var entrada: Dictionary = barreras[z.entrada]
				if entrada.hp > 0 and z.x >= entrada.x and proximo < entrada.x + 4.0:
					proximo = maxf(proximo,entrada.x+4.0)
			z.x = maxf(CASA_X0 + 8.0, proximo)
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
