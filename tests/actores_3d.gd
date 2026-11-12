extends SceneTree
var fallos:=0
func comprobar(ok: bool,msg: String) -> void:
	if not ok:push_error(msg);fallos+=1
func _initialize() -> void:call_deferred("probar")
func probar() -> void:
	var sim:=Sim.new(23)
	sim.aplicar_regalo("Modelo","GG")
	var actor:=preload("res://scripts/actor_3d.gd").new();root.add_child(actor)
	var s: Dictionary=sim.supervivientes[0]
	actor.crear(s,false);actor.actualizar(s,.1,sim.camas())
	comprobar(actor.modelo.find_children("*","MeshInstance3D",true,false).size()>20,"No hay cuerpo 3D articulado")
	comprobar(actor.boca is Node3D,"El arma no tiene boca 3D")
	var antes: Vector3=actor.pies[0].position
	s.camina=true;s.anim+=2
	actor.actualizar(s,.1,sim.camas())
	comprobar(actor.pies[0].position.distance_to(antes)>.05,"No articula las piernas")
	s.carga={"n":12,"kind":"crudo"};s.accion="entregar";s.llego=false
	actor.actualizar(s,.1,sim.camas())
	comprobar(actor.carga_visual.visible and not actor.arma.visible,"No lleva la caja con las manos libres")
	s.carga={};s.accion="cocinar";s.llego=true
	actor.actualizar(s,.1,sim.camas())
	comprobar(not actor.carga_visual.visible and actor.cuchara.visible and not actor.arma.visible,"Cocina con el arma en lugar del utensilio")
	var cama: Dictionary=sim.camas()[34]
	s.cama_id=cama.id;s.accion="dormir";s.llego=true;s.f=cama.f;s.vy=Sim.PISO_Y[cama.f]
	s.x=cama.acceso_x;s.y=cama.acceso_y;s.camina=false
	for i in range(6):actor.actualizar(s,.1,sim.camas())
	comprobar(actor.position.y>Sim.PISO_Y[cama.f]+.4 and not actor.arma.visible,"No se tumba sobre su cama")
	comprobar(sim.navegacion.transitable(s.x/25.0,s.y,s.f),"Dormir modifica la posicion logica sobre el colchon")
	print("Actores: cuerpo/arma 3D, articulaciones y dormir desde acceso libre: ","OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
