extends SceneTree
var fallos := 0
func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos+=1
func _initialize() -> void:
	call_deferred("probar")
func probar() -> void:
	var sim := Sim.new(30)
	var script := load("res://scripts/ventanas_3d.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var mundo = script.new()
	root.add_child(mundo)
	mundo.actualizar(sim.barreras,0)
	comprobar(mundo.tablas.size()==2,"No limita las tablas a las dos ventanas de planta baja")
	for piezas in mundo.tablas.values():
		comprobar(piezas.size()==5,"No crea cinco tablas por ventana")
		for pieza in piezas:
			comprobar(pieza is MeshInstance3D and pieza.visible,"La tabla no es un mesh 3D visible")
	for piezas in mundo.tablas.values():
		var marco: Node3D = piezas[0].get_parent()
		comprobar(absf(marco.position.x-(Sim.CASA_X1/25.0+0.005))<0.001,"Tabla fuera del plano comun de pared")
		comprobar(absf(marco.rotation.y-PI/2.0)<0.001 and marco.position.y==0,"Ventana inclinada o en planta superior")
	sim.barreras[0].hp=0
	mundo.actualizar(sim.barreras,0)
	for pieza in mundo.tablas[0]:comprobar(not pieza.visible,"La tabla rota sigue dibujada")
	sim.barreras[0].hp=30
	mundo.actualizar(sim.barreras,0)
	var visibles:=0
	for pieza in mundo.tablas[0]:
		if pieza.visible:visibles+=1
	comprobar(visibles==1,"Reparar una tabla no se refleja en el mesh")
	mundo.actualizar_cajas(sim.cajas)
	comprobar(mundo.cajas_municion.size()==8,"No crea cajas fisicas para las ocho ventanas")
	for cj in sim.cajas:
		var nodo: Node3D=mundo.cajas_municion[cj.puesto]
		comprobar(is_equal_approx(nodo.position.y,Sim.PISO_Y[cj.f]),"Caja flotando sobre el suelo")
	# Las defensas de plantas superiores se ignoran incluso si llega una entrada incorrecta.
	mundo.actualizar([{"id":99,"f":3}],0)
	comprobar(not mundo.tablas.has(99),"Se dibuja una barricada superior")
	mundo.disparar({"x0":770.0,"d0":1.1,"z0":1.3,"x1":1100.0,"d1":1.1,"z1":1.0})
	var balas:=0
	for fx in mundo.efectos:
		if fx.tipo=="bala":
			balas+=1
			comprobar(fx.nodo.mesh is CapsuleMesh,"La bala no tiene volumen 3D")
	comprobar(balas==1,"No aparece un proyectil por tiro")
	mundo.actualizar(sim.barreras,0)
	mundo.actualizar(sim.barreras,1)
	comprobar(mundo.efectos.is_empty(),"Los efectos 3D no caducan")
	# La demo no puede volver a introducir enemigos con vida artificialmente elevada.
	var vista: Node = load("res://main.tscn").instantiate()
	root.add_child(vista)
	vista._demo_50(true)
	for z in vista.sim.zombis:
		var esperado: float = {"normal":18.0,"corredor":12.0,"bruto":55.0}[z.tipo]
		comprobar(z.max == esperado,"La demo altera la vida real de los zombis")
	print("Render 3D: dos ventanas de planta baja, tablas/rotura/reparacion, proyectiles y efectos: ","OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
