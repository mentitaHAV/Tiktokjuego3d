extends SceneTree
## Regresion del almacen: las donaciones llegan al almacen y alguien tiene que llevarlas a cajas y cocina.
## godot --headless --path D:\CasaSobrevivientes --script res://tests/almacen.gd
var fallos := 0


func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos += 1


func _init() -> void:
	var sim := Sim.new(77)
	sim.config.ambiente = false
	for n in ["Ana", "Luis", "Marta", "Pepe", "Sofi", "Rafa"]:
		sim.aplicar_regalo(n, "GG")
	for rec in sim.arboles + sim.huertos:
		rec.listo = 99999.0
	# 1. La donacion cae en el almacen, no en las cajas ni en la cocina.
	var mun0: int = sim.alm.municion
	var cru0: int = sim.alm.crudo
	var cajas0: int = sim.municion_total() - sim.alm.municion
	var cocina0: int = sim.stock.crudo
	sim.aplicar_regalo("Ana", "GG")
	comprobar(sim.alm.municion > mun0 and sim.alm.crudo > cru0, "La donacion no llega al almacen")
	comprobar(sim.municion_total() - sim.alm.municion == cajas0 and sim.stock.crudo == cocina0, "La donacion salta el almacen")
	# 2. Una caja vacia se rellena sola, llevando la municion desde el almacen.
	var caja: Dictionary = sim.cajas[0]
	caja.mun = 0
	var total: int = sim.municion_total()
	var alm_antes: int = sim.alm.municion
	var visto_carga := false
	for i in range(6000):
		sim.step(0.1)
		for s in sim.supervivientes:
			if s.carga.get("n", 0) > 0 and s.carga.kind == "municion":
				visto_carga = true
		if caja.mun >= 40:
			break
	comprobar(visto_carga, "Nadie lleva municion")
	comprobar(caja.mun >= 40, "La caja vacia no se repone (mun=%d)" % caja.mun)
	comprobar(sim.alm.municion < alm_antes, "El almacen no se vacia al repartir")
	var en_manos := 0
	for s in sim.supervivientes:
		en_manos += s.carga.get("n", 0)
	comprobar(sim.municion_total() + en_manos == total, "El reparto crea o pierde municion (%d vs %d)" % [sim.municion_total() + en_manos, total])
	# 3. La cocina se queda sin suministros: se llevan del almacen y se cocinan.
	sim.stock.crudo = 0
	sim.stock.comida = 0
	var cru_alm: int = sim.alm.crudo
	var cocino := false
	for i in range(6000):
		sim.step(0.1)
		for s in sim.supervivientes:
			if s.accion == "cocinar" and s.llego:
				cocino = true
		if sim.stock.comida >= 2:
			break
	comprobar(sim.alm.crudo < cru_alm, "No se llevan suministros a la cocina")
	comprobar(cocino and sim.stock.comida >= 2, "No se cocina lo recibido")
	# 4. Sin municion en el cargador ni en la caja, nadie se queda en el puesto.
	var t := Sim.new(5)
	t.aplicar_regalo("Tirador", "GG")
	var h: Dictionary = t.supervivientes[0]
	h.cartuchos = 0
	t.cajas[0].mun = 0
	t.cajas[1].mun = 0
	var elegido: Dictionary = t._puesto_ventana(h)
	comprobar(elegido.is_empty() or t.cajas[elegido.puesto].mun > 0, "Elige un puesto sin municion")
	# Las ocho cajas tienen acceso libre y reciben un reparto real, incluso entre camas.
	var reparto := Sim.new(77)
	reparto.aplicar_regalo("Repartidor", "GG")
	var repartidor: Dictionary = reparto.supervivientes[0]
	for cj in reparto.cajas:
		comprobar(reparto.navegacion.transitable(cj.ax / 25.0, cj.ay, cj.f), "Acceso bloqueado a caja %d" % cj.puesto)
		comprobar(not reparto.navegacion.transitable((cj.x + 6.0) / 25.0, cj.y, cj.f), "La caja no bloquea el paso")
		reparto._soltar(repartidor)
		repartidor.accion = ""
		repartidor.f = 0
		repartidor.x = Sim.ALM_ACCESO_X
		repartidor.y = Sim.ALM_ACCESO_Y
		reparto.alm.municion = 120
		cj.mun = 0
		reparto._comenzar(repartidor, {"tipo":"recoger", "x":Sim.ALM_ACCESO_X, "y":Sim.ALM_ACCESO_Y, "f":0, "dur":1.2, "ref":cj})
		for i in range(30):
			reparto._actuar(repartidor, 0.1)
			if repartidor.accion == "": break
		reparto._comenzar(repartidor, {"tipo":"entregar", "x":cj.ax, "y":cj.ay, "f":cj.f, "dur":1.0})
		for i in range(1800):
			reparto._actuar(repartidor, 0.1)
			if repartidor.accion == "": break
		comprobar(cj.mun == Sim.CARGA_MUN and repartidor.carga.is_empty(), "No se entrega en caja %d" % cj.puesto)
	# Solo la comida cocinada sacia el hambre.
	t.stock.comida = 0
	t.stock.crudo = 3
	h.hambre = 80.0
	h.accion = "comer"
	t._terminar(h)
	comprobar(t.stock.crudo == 3 and h.hambre == 80.0, "Se come comida sin cocinar")
	t.stock.comida = 1
	h.accion = "comer"
	t._terminar(h)
	comprobar(t.stock.comida == 0 and h.hambre == 20.0, "No se consume comida cocinada")
	# Las balas de los cargadores y las cajas cuentan antes de avisar de agotamiento.
	t.alm.municion = 0
	for cj in t.cajas: cj.mun = 1
	h.cartuchos = 30
	comprobar(t.aviso_municion() == "MUNICIÓN BAJA", "Aviso falso con balas disponibles")
	for cj in t.cajas: cj.mun = 0
	h.cartuchos = 0
	comprobar(t.aviso_municion() == "¡SIN MUNICIÓN!", "No avisa al agotar municion")
	h.carga = {"kind":"municion", "n":45}
	comprobar(t.aviso_municion() == "REPARTIR MUNICIÓN", "Ignora municion en transito")
	h.carga = {}
	t.alm.municion = 100
	comprobar(t.aviso_municion() == "REPARTIR MUNICIÓN", "No distingue reserva de municion lista")
	print("Almacen: donacion, reparto a cajas, cocina y puestos sin municion: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)
