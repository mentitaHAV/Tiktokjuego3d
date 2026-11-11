extends SceneTree
## Prueba sin pantalla: godot --headless --path D:\CasaSobrevivientes --script res://tests/prueba.gd

func _init() -> void:
	var sim := Sim.new(1234)
	var nombres := ["Ana", "Luis", "Marta", "Pepe", "Sofi"]
	for n in nombres:
		sim.aplicar_regalo(n, "Rose", 1)
	print("vivos tras rosas: ", sim.vivos())
	# segunda rosa de Ana -> suministros
	var antes: int = sim.stock.municion
	sim.aplicar_regalo("Ana", "Rose", 1)
	print("municion antes/despues: ", antes, " / ", sim.stock.municion)
	var dt := 0.1
	var seg := 0.0
	var siguiente_print := 0.0
	var gg_lanzados := 0
	while seg < 400.0 and sim.gen < 3:
		sim.step(dt)
		seg += dt
		if seg > 60.0 and gg_lanzados == 0:
			sim.aplicar_regalo("Luis", "GG", 1)
			gg_lanzados += 1
		if seg > 200.0 and gg_lanzados == 1:
			sim.aplicar_regalo("Pepe", "GG", 2)
			gg_lanzados += 1
		if seg > 400.0 and gg_lanzados == 2:
			sim.aplicar_regalo("Marta", "GG", 3)
			gg_lanzados += 1
		if seg >= siguiente_print:
			siguiente_print += 30.0
			var acc := {}
			for s in sim.supervivientes:
				acc[s.accion] = acc.get(s.accion, 0) + 1
			print("t=%4d gen=%d vivos=%d zombis=%2d kills=%2d stock=%s barr=%d puertas=%d/%d acc=%s" % [
				int(seg), sim.gen, sim.vivos(), sim.zombis.size(), sim.kills, str(sim.stock),
				sim.barreras.size(), int(sim.puertas[0].hp), int(sim.puertas[0].max), str(acc)])
	print("historial: ", JSON.stringify(sim.historial))
	quit()
