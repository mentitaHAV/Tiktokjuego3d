extends SceneTree
var fallos:=0
func comprobar(ok: bool,texto: String) -> void:
	if not ok:push_error(texto);fallos+=1
func _init() -> void:
	var sim:=Sim.new(35)
	for nombre in ["Ana","Luis"]:sim.aplicar_regalo(nombre,"GG")
	for i in range(2):
		var h: Dictionary=sim.supervivientes[i]
		sim._comenzar(h,sim.puestos_ventana()[i])
		h.x=h.ox;h.y=h.oy;h.f=0;h.llego=true;h.cd_dec=999
		h.modelo_arma="AK";h.cartuchos=30
	# Un solo atacante a la primera barrera obliga a separar ambos tiradores de los huecos.
	sim.spawn_zombi(1,"bruto")
	var z: Dictionary=sim.zombis[0]
	z.x=Sim.CASA_X1+4;z.y=1.1;z.entrada=0;z.hp=100000
	sim._zombi(z,.1)
	comprobar(sim.barreras[0].hp<sim.barreras[0].max and z.atac>0,"El escenario no esta golpeando una barricada real")
	for h in sim.supervivientes:
		var puesto: Dictionary=sim._puesto_ventana(h)
		comprobar(puesto.x==Sim.TIRO_RESERVA_X,"Mantiene un puesto pegado a una barricada atacada")
		sim._vida(h,.1)
		comprobar(h.x>Sim.TIRO_RESERVA_X+20,"La retirada teletransporta al defensor")
	for i in range(50):
		for h in sim.supervivientes:sim._vida(h,.1)
	for h in sim.supervivientes:
		comprobar(h.x<=Sim.TIRO_RESERVA_X+1 and h.llego,"No completa la retirada caminando")
		comprobar(h.tiros>0,"No dispara a los atacantes desde atras")
		comprobar(sim._caja_de(h)!=null,"No puede reponer desde la posicion segura")
	# No se puede extraer municion de una caja alejada desde el mismo hueco.
	var h: Dictionary=sim.supervivientes[0]
	h.x=Sim.CASA_X1-12;h.y=1.1;h.llego=true
	comprobar(sim._caja_de(h)==null,"Recarga a distancia desde la ventana")
	# Los pisos altos conservan sus posiciones y el reparador no se acerca bajo presion.
	h.accion="";h.cartuchos=30
	var alto: Dictionary=sim.puestos_ventana()[2]
	sim._comenzar(h,alto)
	comprobar(sim._puesto_ventana(h).x==alto.x,"Desplaza tambien los puestos de plantas superiores")
	sim.barreras[0].hp=60
	comprobar(sim._dañado()==null,"Envia a reparar mientras estan golpeando las tablas")
	sim._comenzar(h,{"tipo":"reparar","x":768.0,"y":1.1,"f":0,"ref":sim.barreras[0],"dur":.8})
	h.x=768;h.y=1.1;h.f=0;h.escalera={}
	sim._vida(h,.1)
	comprobar(h.accion!="reparar" and h.ox<=Sim.TIRO_RESERVA_X,"El reparador no abandona el peligro")
	z.hp=0
	comprobar(sim._ventana_peligrosa(0),"No mantiene un margen tras el ultimo golpe")
	sim.t+=5
	comprobar(not sim._ventana_peligrosa(0),"La ventana no vuelve a estar disponible al despejarse")
	comprobar(sim._dañado()!=null,"No reanuda las reparaciones cuando es seguro")
	print("Retirada: dos defensores atras, disparo, recarga cercana y reparacion segura: ","OK" if fallos==0 else "FALLO")
	quit(0 if fallos==0 else 1)
