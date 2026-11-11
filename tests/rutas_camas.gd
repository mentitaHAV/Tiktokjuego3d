extends SceneTree
var fallos:=0
func comprobar(ok: bool,msg: String) -> void:
	if not ok:
		if fallos<8:push_error(msg)
		fallos+=1
func _init() -> void:
	var sim:=Sim.new(33)
	sim.aplicar_regalo("Prueba","GG")
	var s: Dictionary=sim.supervivientes[0]
	for cama in sim.camas():
		sim._soltar(s);s.accion="";s.erase("ruta_destino")
		s.x=Sim.ESCALERA_X;s.y=Sim.PASILLO_Y;s.f=cama.f;s.vy=Sim.PISO_Y[s.f];s.escalera={}
		sim._comenzar(s,{"tipo":"dormir","x":cama.acceso_x,"y":cama.acceso_y,"f":cama.f,"cama":cama.id})
		var llego:=false
		for i in range(2000):
			sim._actuar(s,.1)
			comprobar(sim.navegacion.transitable(s.x/25.0,s.y,s.f),"Camina por un mueble, cama "+str(cama.id))
			if s.llego:llego=true;break
		comprobar(llego,"No llega al acceso de cama "+str(cama.id))
		comprobar(absf(s.x-cama.x)>10 or s.y<cama.y-1.05,"El acceso esta encima del colchon")
	print("Rutas: 50 camas accesibles sin pisar colchones ni tabiques: ","OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
