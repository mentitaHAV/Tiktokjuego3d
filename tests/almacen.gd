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
	print("Almacen: donacion, reparto a cajas, cocina y puestos sin municion: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)
