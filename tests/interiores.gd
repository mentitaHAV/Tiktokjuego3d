extends SceneTree
## Regresion de puestos, escalera y fabricacion dentro de la casa.
var fallos := 0

func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos += 1

func recorrer(sim: Sim, s: Dictionary, accion: Dictionary, limite: int = 3000) -> void:
	sim._comenzar(s, accion)
	for i in range(limite):
		var antes_x: float = s.x
		var subiendo: bool = not s.escalera.is_empty()
		sim._actuar(s, 0.1)
		if (antes_x <= Sim.CASA_X1 and s.x > Sim.CASA_X1) or (antes_x > Sim.CASA_X1 and s.x <= Sim.CASA_X1):
			comprobar(s.f == 0 and absf(s.y - Sim.PUERTA_Y) < 0.03, "Cruza la pared fuera de la puerta")
		if subiendo:
			comprobar(s.x >= Sim.ESCALERA_X - 0.1 and s.x <= Sim.ESCALERA_X + 40.1 and s.y >= 0.59 and s.y <= 3.61, "Cambia de planta fuera de los tramos de escalera")
			comprobar(absf(s.vy / 0.2 - roundf(s.vy / 0.2)) < 0.01, "Los pies no apoyan sobre una contrahuella")
		if s.accion == "" or (s.accion == "dormir" and s.llego):
			return
	comprobar(false, "No alcanza/completa el puesto: " + str(accion.tipo))

func _init() -> void:
	var sim := Sim.new(23)
	sim.aplicar_regalo("Ana", "GG")
	var s: Dictionary = sim.supervivientes[0]
	s.x = Sim.CASA_X1 + 100.0
	s.y = 3.2
	var comida: int = sim.stock.comida
	recorrer(sim, s, {"tipo": "cocinar", "x": Sim.COCINA_X, "f": 0, "dur": 1.0})
	comprobar(sim.stock.comida == comida + 2, "No produce comida en cocina")
	comprobar(absf(s.x - Sim.COCINA_X) < 0.1 and absf(s.y - 1.4) < 0.03, "Cocina fuera del puesto")
	recorrer(sim,s,sim._cama(s))
	comprobar(s.f == 2 and is_equal_approx(s.vy, Sim.PISO_Y[2]) and absf(s.y - 0.9) < 0.03, "Duerme sin alcanzar la cama/planta")
	recorrer(sim, s, {"tipo": "comer", "x": Sim.MESA_X, "f": 0, "dur": 1.0})
	comprobar(s.f == 0 and s.vy == 0 and absf(s.y - 1.2) < 0.03, "No vuelve al comedor")
	# Ahora la madera solo se instala y repara en las ventanas, desde dentro.
	var ventana: Dictionary = sim.barreras[1]
	ventana.hp = 0
	recorrer(sim,s,{"tipo":"reparar","x":ventana.px-8,"y":ventana.y,"f":ventana.f,"dur":0.8,"ref":ventana})
	comprobar(ventana.hp == Sim.TABLA_HP and s.x < Sim.CASA_X1 and s.f == ventana.f,"No repara la ventana desde su planta")
	# No se comparte una cama reservada, aunque haya mas humanos que camas.
	for cama in sim.camas():
		var otro := sim._nuevo_superviviente("Cama" + str(cama.x) + str(cama.f))
		otro.accion = "dormir"
		otro.ox = cama.acceso_x
		otro.cama_id = cama.id
		otro.of = cama.f
		sim.supervivientes.append(otro)
	comprobar(sim._cama(s).tipo != "dormir", "Asigna una cama ya ocupada")
	print("Interiores: puestos, cambio de planta y taller: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)
