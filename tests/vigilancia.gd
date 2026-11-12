extends SceneTree
## Siempre hay alguien vigilando en una ventana, de dia y de noche, con o sin zombis.
## godot --headless --path D:\CasaSobrevivientes --script res://tests/vigilancia.gd
var fallos := 0


func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos += 1


func medir(sim: Sim, segundos: float, gracia: float) -> Dictionary:
	var sin_guardia := 0.0
	var max_tiradores := 0
	var t := 0.0
	while t < segundos:
		sim.step(0.1)
		t += 0.1
		if t > gracia:
			if not sim.guardia_cubierta():
				sin_guardia += 0.1
			max_tiradores = maxi(max_tiradores, sim._contar("disparar"))
	return {"hueco": sin_guardia, "tiradores": max_tiradores}


func _init() -> void:
	# Casa pequena, tres dias y noches sin zombis.
	var sim := Sim.new(31)
	sim.config.ambiente = false
	for n in ["Ana", "Luis", "Marta", "Pepe", "Sofi"]:
		sim.aplicar_regalo(n, "GG")
	var r := medir(sim, 400.0, 40.0)
	comprobar(r.hueco < 2.0, "Sin zombis hay huecos de vigilancia: %.1f s" % r.hueco)
	comprobar(r.tiradores <= 3, "Demasiados vigilantes en calma: %d" % r.tiradores)
	# Una guardia agotada se relaja solo cuando llega el relevo.
	var guardia = null
	for o in sim.supervivientes:
		if o.accion == "disparar" and o.llego:
			guardia = o
	comprobar(guardia != null, "No hay nadie en la ventana")
	if guardia != null:
		guardia.energia = 25.0
		var r2 := medir(sim, 120.0, 0.0)
		comprobar(r2.hueco < 2.0, "Al relevar a un agotado se queda la ventana vacia: %.1f s" % r2.hueco)
		comprobar(not (guardia.accion == "disparar" and guardia.llego) or guardia.energia > 5.0, "El agotado sigue de guardia indefinidamente")
	# Si el vigilante muere, otro ocupa su lugar.
	var uno := Sim.new(32)
	uno.config.ambiente = false
	for n in ["A", "B", "C"]:
		uno.aplicar_regalo(n, "GG")
	medir(uno, 90.0, 999.0)
	for o in uno.supervivientes:
		if o.accion == "disparar":
			o.hp = 0.0
	uno.step(0.1)
	var r3 := medir(uno, 90.0, 30.0)
	comprobar(r3.hueco < 2.0, "Tras morir el vigilante nadie le sustituye: %.1f s" % r3.hueco)
	# Cincuenta residentes con oleadas: la guardia no se pierde nunca tras el arranque.
	var gran := Sim.new(33)
	gran.config.ambiente = false
	for i in range(50):
		gran.aplicar_regalo("V%d" % i, "GG")
	gran.aplicar_regalo("Zombi", "Rose", 1)
	var r4 := medir(gran, 300.0, 60.0)
	comprobar(r4.hueco < 4.0, "Con 50 residentes hay huecos de vigilancia: %.1f s" % r4.hueco)
	print("Vigilancia permanente: calma, relevo, baja del vigilante y 50 residentes: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)
