extends SceneTree
var fallos := 0
func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos+=1
func _init() -> void:
	var sim:=Sim.new(55)
	for nombre in ["Ana","Luis","Marta","Pepe","Sofi"]:sim.aplicar_regalo(nombre,"GG")
	var comida_inicial: int=sim.stock.comida
	var vio_cocina:=false
	var vio_huerto:=false
	var vio_carga:=false
	var max_comida:=comida_inicial
	for i in range(2400):
		sim.step(.1)
		sim.fx.clear()
		max_comida=maxi(max_comida,sim.stock.comida)
		var cocinas: Array=[]
		for h in sim.supervivientes:
			if h.accion=="cocinar":
				comprobar(h.ox not in cocinas,"Dos cocineros ocupan el mismo puesto")
				cocinas.append(h.ox)
				if h.llego:vio_cocina=true
			if h.accion=="cultivar" and h.llego:vio_huerto=true
			if h.carga.get("n",0)>0:vio_carga=true
	comprobar(vio_cocina and max_comida>=sim.objetivo_comida(),"No prepara reservas durante la calma")
	comprobar(vio_huerto,"No atiende el huerto en la calma")
	comprobar(vio_carga,"No mueve suministros o municion")
	comprobar(max_comida<=sim.objetivo_comida()+2,"Cocina sin limite aunque hay reservas")
	comprobar(sim.vivos()==5 and sim.zombis.is_empty(),"La rutina de calma pierde residentes")
	comprobar(sim.barreras.size()==2,"Se crean barricadas de mas")
	for b in sim.barreras:comprobar(b.f==0,"Se crean barricadas en plantas altas")
	print("Casa en calma: reserva de comida, puestos exclusivos, huerto, reparto y cinco vivos: ","OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
