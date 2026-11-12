extends SceneTree
var fallos:=0
func comprobar(ok: bool,texto: String) -> void:
	if not ok:push_error(texto);fallos+=1
func _initialize() -> void:call_deferred("probar")
func probar() -> void:
	var vista: Node=load("res://main.tscn").instantiate();root.add_child(vista)
	vista.set_process(false)
	vista.sim=Sim.new(55)
	vista.sim.aplicar_regalo("Ana","GG")
	comprobar(vista._estado_refugio().texto=="EN CALMA","No identifica la calma")
	vista.sim.spawn_zombi(1,"normal")
	comprobar(vista._estado_refugio().texto=="BAJO ATAQUE","No indica un ataque")
	vista.sim.zombis[0].dentro=true
	comprobar(vista._estado_refugio().texto=="BRECHA EN LA CASA","No prioriza una invasion interior")
	vista.rotulos_ocupados.clear()
	for i in range(5):vista._colocar_rotulo(Vector2(150,250),40)
	for i in range(5):
		for j in range(i+1,5):comprobar(not vista.rotulos_ocupados[i].intersects(vista.rotulos_ocupados[j]),"Se superponen los nombres")
	var borde: Vector2=vista._colocar_rotulo(Vector2(0,20),60)
	comprobar(borde.x>=34 and borde.y>=53,"El nombre queda fuera de pantalla o sobre la cabecera")
	var mundo: Node=vista.ventanas_3d
	mundo.actualizar_cocina(vista.sim,.5)
	comprobar(mundo.fogones.size()==4,"No crea los fogones sobre los puestos reales")
	comprobar(not mundo.fogones[0].fuego.visible,"El fuego queda encendido sin cocinar")
	var h: Dictionary=vista.sim.supervivientes[0]
	h.accion="cocinar";h.llego=true;h.ox=Sim.COCINA_X
	mundo.actualizar_cocina(vista.sim,.5)
	comprobar(mundo.fogones[0].fuego.visible and mundo.fogones[0].luz.light_energy>0,"No ilumina el fogon activo")
	h.accion="pasear"
	mundo.actualizar_cocina(vista.sim,1)
	comprobar(not mundo.fogones[0].fuego.visible and mundo.fogones[0].luz.light_energy==0,"No apaga el fogon tras cocinar")
	vista.sim.supervivientes.clear()
	comprobar(vista._estado_refugio().texto=="REFUGIO CAÍDO","No identifica el final de partida")
	print("Presentacion: prioridades de avisos, nombres sin solaparse y fogones activos: ","OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
