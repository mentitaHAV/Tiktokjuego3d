extends SceneTree
func _initialize() -> void:call_deferred("comprobar")
func comprobar() -> void:
	var vista: Node=load("res://main.tscn").instantiate()
	root.add_child(vista)
	vista.set_process(false)
	for i in range(100):
		vista._gore({"k":"golpe","x":900,"y":1.1,"z":1.1,"dir":1,"mata":true,"tipo":"normal"})
	var correcto: bool=vista.parts.size()<=180 and vista.manchas.size()<=450
	for p in vista.parts:correcto=correcto and p.c in vista.SANGRE
	for m in vista.manchas:correcto=correcto and m[4] in vista.SANGRE
	for i in range(40):vista._particulas(.1)
	correcto=correcto and vista.parts.is_empty()
	print("Efectos: sangre limitada, sin fragmentos verdes/morados y particulas que desaparecen: ","OK" if correcto else "FALLO")
	quit(0 if correcto else 1)
