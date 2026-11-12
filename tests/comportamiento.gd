extends SceneTree
var fallos := 0
func comprobar(ok: bool, texto: String) -> void:
	if not ok:
		push_error(texto)
		fallos += 1
func _init() -> void:
	var sim := Sim.new(17)
	sim.aplicar_regalo("Ana", "GG")
	var h: Dictionary = sim.supervivientes[0]
	sim._comenzar(h, sim.puestos_ventana()[0])
	h.x=h.ox; h.y=h.oy; h.llego=true
	sim._decidir(h)
	comprobar(h.accion == "disparar" and h.puesto == 0, "El unico vigilante abandona la ventana")
	sim.aplicar_regalo("Luis", "GG")
	var relevo: Dictionary = sim.supervivientes[1]
	sim._comenzar(relevo, sim.puestos_ventana()[1])
	relevo.x = relevo.ox; relevo.y = relevo.oy; relevo.llego = true
	sim._decidir(h)
	comprobar(h.accion != "disparar" and h.puesto == -1, "No abandona una ventana sin enemigos cuando ya hay otro vigilando")
	sim._comenzar(h, {"tipo":"cocinar", "x":Sim.COCINA_X, "f":0, "dur":5.0})
	var destino: float = h.ox
	for i in range(15): sim._decidir(h)
	comprobar(h.accion == "cocinar" and h.ox == destino, "Cambia de tarea antes de terminar sin una amenaza")
	# El enemigo dentro interrumpe el trabajo; se dispara desde una distancia util.
	h.x=690;h.y=.6;h.f=0;h.vy=0;h.cartuchos=30
	sim.spawn_zombi(1,"bruto")
	var z: Dictionary = sim.zombis[0]
	z.x=760;z.y=.6;z.dentro=true;z.hp=10000
	sim._decidir(h)
	comprobar(h.accion == "luchar", "No prioriza una brecha sobre cocinar")
	comprobar(absf(h.ox-h.x)<1, "Se acerca innecesariamente a un enemigo que ya puede disparar")
	for i in range(30):sim._vida(h,.1)
	comprobar(h.tiros>0 and z.hp<10000, "No se defiende disparando dentro de casa")
	comprobar(absf(h.x-690)<2, "Oscila de posicion durante el fuego interior")
	# Una barrera o mueble interpuesto impide disparar a traves.
	sim.navegacion.cajas_obstaculos.append({"f":0,"x0":28.5,"x1":28.8,"y0":0,"y1":1.2})
	comprobar(not sim._linea_tiro_libre(h,z), "Dispara a traves de obstaculos")
	# La caja cercana permite recargar al defenderse lejos de la postura fija de ventana.
	h.x=sim.cajas[0].ax;h.y=sim.cajas[0].ay;h.accion="luchar"
	comprobar(sim._caja_de(h)!=null, "No puede usar una caja cercana para defenderse")
	z.hp=0
	sim._decidir(h)
	comprobar(h.accion != "luchar", "Continua peleando al terminar la invasion")
	print("Comportamiento: abandonar ventanas, continuidad de tareas, defensa interior y linea de tiro: ", "OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
