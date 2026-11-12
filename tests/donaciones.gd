extends SceneTree
## Reglas de TikTok: 1 like = 1 zombi, cada moneda = 5 zombis, GG = persona.
## godot --headless --path D:\CasaSobrevivientes --script res://tests/donaciones.gd
var fallos := 0


func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos += 1


func _init() -> void:
	var sim := Sim.new(41)
	sim.aplicar_regalo("Ana", "like", 1)
	comprobar(sim.cola_zombis.size() == 1, "1 like no es 1 zombi (%d)" % sim.cola_zombis.size())
	sim.aplicar_regalo("Ana", "like", 7)
	comprobar(sim.cola_zombis.size() == 8, "7 likes mas no suman 8 zombis")
	sim.cola_zombis.clear()
	sim.aplicar_regalo("Luis", "Rose", 1)
	comprobar(sim.cola_zombis.size() == 5, "Una rosa (1 moneda) no son 5 zombis")
	sim.cola_zombis.clear()
	sim.aplicar_regalo("Luis", "Lion", 1, 30)
	comprobar(sim.cola_zombis.size() == 150, "30 monedas no son 150 zombis (%d)" % sim.cola_zombis.size())
	sim.cola_zombis.clear()
	sim.aplicar_regalo("Luis", "Rose", 3, 3)
	comprobar(sim.cola_zombis.size() == 15, "Tres rosas de 1 moneda no son 15 zombis")
	sim.cola_zombis.clear()
	sim.aplicar_regalo("Pepe", "GG", 1, 1)
	comprobar(sim.cola_zombis.is_empty() and sim.vivos() == 1, "GG no crea una persona sin zombis")
	# Escalonado y tope: un diluvio no se queda sin limite.
	sim.aplicar_regalo("Mil", "like", 5000)
	comprobar(sim.cola_zombis.size() <= Sim.MAX_COLA, "La cola de zombis no tiene tope")
	var ultimo: float = 0.0
	for c in sim.cola_zombis:
		ultimo = maxf(ultimo, c.cuando)
	comprobar(ultimo > 1.0, "Los zombis salen todos de golpe")
	# Salen de verdad por la derecha en el tiempo.
	var s2 := Sim.new(42)
	s2.aplicar_regalo("A", "GG")
	s2.aplicar_regalo("B", "like", 20)
	for i in range(100):
		s2.step(0.1)
	comprobar(s2.zombis.size() + s2.kills >= 10, "Los zombis de los likes no aparecen")
	print("Donaciones: likes, monedas x5, GG y tope de cola: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)
