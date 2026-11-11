extends SceneTree
var fallos := 0
func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos += 1
func _init() -> void:
	var salud := Sim.new(24)
	for tipo in ["normal","corredor","bruto"]:salud.spawn_zombi(1,tipo)
	comprobar(salud.zombis[0].hp==18 and salud.zombis[1].hp==12 and salud.zombis[2].hp==55,"No se aplico la reduccion de vida")
	var sim := Sim.new(81)
	var modelos := {}
	for i in range(50):
		sim.aplicar_regalo("Jugador" + str(i), "GG")
		var s: Dictionary = sim.supervivientes.back()
		modelos[s.modelo_arma] = true
		comprobar(s.cartuchos == Sim.ARMAS[s.modelo_arma].cargador, "Cargador inicial incorrecto")
	comprobar(modelos.size() == 3, "No se reparten pistolas, AK y M4")
	var combate := Sim.new(91)
	combate.aplicar_regalo("Tirador", "GG")
	var s: Dictionary = combate.supervivientes[0]
	s.modelo_arma = "AK"; s.arma = "AK"; s.cartuchos = 1; s.cd_dec = 999
	combate._comenzar(s, combate.puestos_ventana()[0])
	s.x = s.ox; s.f = s.of; s.y = s.oy; s.vy = Sim.PISO_Y[s.f]
	s.llego = true; s.camina = false
	combate.spawn_zombi(1, "bruto")
	combate.zombis[0].x = Sim.CASA_X1 + 70
	combate.zombis[0].hp = 1000000
	combate.stock.municion = 10
	combate._reflejo(s)
	comprobar(s.cartuchos == 0 and s.tiros == 1 and s.retroceso == 1.0, "Disparo no consume cargador/inicia retroceso")
	s.cd_ataque = 0
	combate._reflejo(s)
	comprobar(s.recarga > 0 and combate.stock.municion == 9, "Dispara con cargador vacio")
	for i in range(24): combate._vida(s, 0.1)
	comprobar(s.tiros == 1 and combate.stock.municion == 9, "Dispara durante la recarga")
	for i in range(4): combate._vida(s, 0.1)
	comprobar(s.tiros >= 2 and s.cartuchos > 0, "No termina de recargar/reanuda el fuego")
	comprobar(combate.stock.municion == 10 - s.tiros, "La recarga fabrica o duplica municion")
	var tiros: int = s.tiros
	combate.stock.municion = 0
	for i in range(30): combate._vida(s, 0.1)
	comprobar(s.tiros == tiros, "Dispara sin municion de la reserva")
	print("Armas: reparto aleatorio, cargadores, retroceso, recarga y consumo: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)
