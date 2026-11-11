extends SceneTree
## Captura reproducible de la animacion real. Requiere display.
## godot --path . --script res://tools/grabar.gd -- --destino=/tmp/armas-frames
var vista: Node
var tiempo := 0.0
var fotograma := 0
var destino := "/tmp/armas-frames"
var ventanas_danadas := false
var interior := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--destino="): destino = arg.substr(10)
		if arg == "--ventanas-danadas": ventanas_danadas = true
		if arg == "--interior": interior = true
	DirAccess.make_dir_recursive_absolute(destino)
	call_deferred("iniciar")
func iniciar() -> void:
	vista = load("res://main.tscn").instantiate()
	root.add_child(vista)
	vista._demo_50(true)
	if interior:
		vista.sim.zombis.clear();vista.sim.cola_zombis.clear();vista.sim.avisos.clear()
		for s in vista.sim.supervivientes:
			s.cd_dec=999;s.hambre=0;s.energia=100;s.dice_ttl=0
			vista.sim._comenzar(s,{"tipo":"pasear","x":s.x,"y":s.y,"f":s.f,"dur":30})
		for i in range(4):
			var s: Dictionary=vista.sim.supervivientes[40+i]
			var cama: Dictionary=vista.sim.camas()[36+i*4]
			var habitacion: Dictionary=vista.sim.navegacion.datos.habitaciones[i]
			s.x=(habitacion.x0+habitacion.x1)*12.5;s.y=.6;s.f=4;s.vy=Sim.PISO_Y[4]
			vista.sim._comenzar(s,{"tipo":"dormir","x":cama.acceso_x,"y":cama.acceso_y,"f":4,"cama":cama.id})
			s.cd_dec=999
	if ventanas_danadas:
		vista.sim.barreras[0].hp = 60
		vista.sim.barreras[1].hp = 90
func _process(delta: float) -> bool:
	if vista == null: return false
	tiempo += delta
	if tiempo >= (fotograma + 1) * 0.1:
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png(destino.path_join("frame%03d.png" % fotograma))
			fotograma += 1
	return fotograma >= 48
