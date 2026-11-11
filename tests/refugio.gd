extends SceneTree
var fallos := 0
func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		push_error(mensaje)
		fallos += 1

func _init() -> void:
	identidades()
	capacidad_y_ventanas()
	barricadas_y_huerto()
	escalera_zombi()
	print("Refugio: identidad GG, rosas, 50 residentes/camas, 8 ventanas, reconstruccion y huerto: ", "OK" if fallos == 0 else "FALLO")
	quit(0 if fallos == 0 else 1)

func identidades() -> void:
	var sim := Sim.new(11)
	sim.config.ambiente = false
	sim.aplicar_regalo("Juanito", "GG", 2)
	comprobar(sim.vivos() == 1, "Dos GG crean dos copias del usuario")
	var juan: Dictionary = sim.supervivientes[0]
	comprobar(juan.nombre == "Juanito" and juan.aportes == 1 and juan.nivel_arma == 2, "GG repetido no entrega equipo/arma")
	var municion: int = sim.alm.municion
	sim.aplicar_regalo(" JUANITO ", "gg")
	comprobar(sim.vivos() == 1 and sim.alm.municion > municion and juan.nivel_arma == 3, "Identidad no normalizada")
	sim.aplicar_regalo("OtraPersona", "Rose", 2)
	comprobar(sim.vivos() == 1 and sim.cola_zombis.size() == 12, "Las rosas no invocan la cantidad de oleadas")
	sim._procesar_cola()
	comprobar(sim.zombis.size() > 0 and sim.zombis[0].x > Sim.CASA_X1, "Zombis no aparecen por la derecha")
	# Una identidad muerta no se duplica/revive con el siguiente GG de la misma generacion.
	sim.aplicar_regalo("Ana", "GG")
	juan.hp = 0
	sim.step(0.1)
	sim.aplicar_regalo("Juanito", "GG")
	comprobar(sim._buscar_vivo("Juanito") == null and sim.vivos() == 1, "GG duplica una identidad muerta")

func capacidad_y_ventanas() -> void:
	var sim := Sim.new(19)
	sim.config.ambiente = false
	for i in range(51): sim.aplicar_regalo("Vecino" + str(i), "GG")
	comprobar(sim.vivos() == 50 and sim.camas().size() == 50, "Capacidad o camas no son 50")
	sim.aplicar_regalo("Vecino0", "GG", 2)
	comprobar(sim.vivos() == 50 and sim.supervivientes[0].nivel_arma == 3, "El refugio lleno bloquea mejoras de un jugador existente")
	var reservadas := {}
	for s in sim.supervivientes:
		var cama := sim._cama(s)
		var clave := str(cama.cama)
		comprobar(not reservadas.has(clave), "Dos humanos reservan la misma cama")
		reservadas[clave] = true
		sim._comenzar(s, cama)
	for s in sim.supervivientes:
		sim._soltar(s)
		s.accion = ""
		s.hambre = 0
		s.energia = 100
		s.x = Sim.ESCALERA_X
	sim.spawn_zombi(1, "bruto")
	var z: Dictionary = sim.zombis[0]
	z.x = Sim.CASA_X1 + 70
	z.hp = 100000
	z.max = z.hp
	for s in sim.supervivientes: sim._decidir(s)
	comprobar(sim._contar("disparar") == 8, "No se reservan exactamente ocho puestos de ventana")
	var puestos := {}
	for s in sim.supervivientes:
		if s.accion == "disparar":
			comprobar(not puestos.has(s.puesto), "Dos tiradores comparten puesto")
			puestos[s.puesto] = true
			s.x = s.ox; s.f = s.of; s.vy = Sim.PISO_Y[s.f]; s.y = s.oy
			s.llego = true; s.camina = false; s.cd_ataque = 0
		else:
			# Permanecer junto a ventanas no otorga un noveno puesto de disparo.
			s.x = Sim.VENTANA_DER
			s.f = 0; s.vy = 0
		sim._reflejo(s)
	comprobar(sim.disparos.size() == 8, "No disparan ocho a la vez, o dispara un noveno")

func barricadas_y_huerto() -> void:
	var sim := Sim.new(31)
	sim.aplicar_regalo("Carpintero","GG")
	var s: Dictionary = sim.supervivientes[0]
	comprobar(sim.barreras.size()==2 and sim.puertas.is_empty(),"Quedan barricadas fuera de las ventanas")
	for defensa in sim.barreras:
		comprobar(defensa.x==defensa.px+14 and defensa.px<Sim.CASA_X1 and defensa.f==0,"Madera situada en el patio")
	var defensa: Dictionary = sim.barreras[0]
	defensa.hp=0
	var madera: int = sim.stock.madera
	sim._comenzar(s,{"tipo":"reparar","x":defensa.px-8,"f":defensa.f,"y":defensa.y,"dur":0.8,"ref":defensa})
	for i in range(3000):
		sim._actuar(s,0.1)
		if s.accion=="":break
	comprobar(defensa.hp==30 and sim.stock.madera==madera-1,"No reconstruye una tabla")
	comprobar(s.x<Sim.CASA_X1,"Repara desde fuera de la casa")
	for i in range(150):sim.step(0.1)
	comprobar(defensa.hp==150 and sim.stock.madera==madera-5,"La IA no reconstruye la ventana completa")
	sim.spawn_zombi(1,"bruto")
	var z: Dictionary = sim.zombis[0]
	z.entrada=0; z.x=defensa.x+5; z.y=defensa.y
	defensa.hp=1
	sim._zombi(z,0.1)
	comprobar(defensa.hp==0 and sim.barreras.size()==2,"No rompe/conserva la ventana")
	for i in range(100):sim._zombi(z,0.1)
	comprobar(z.dentro,"No entra por su ventana rota aunque otra siga intacta")
	z.dentro=false; z.entrada=1; z.x=sim.barreras[1].x+20; z.y=sim.barreras[1].y; z.vel=300
	sim._zombi(z,0.2)
	comprobar(z.x>=sim.barreras[1].x,"Atraviesa una ventana intacta con paso grande")
	s.x=30; s.f=0; s.vy=0
	z.x=Sim.CASA_X0+9;z.dentro=true
	for i in range(300):sim._zombi(z,0.1)
	comprobar(z.x>=Sim.CASA_X0 and sim._objetivo_zombi(z)==null,"Atraviesa la malla del huerto")


func escalera_zombi() -> void:
	var sim := Sim.new(52)
	sim.aplicar_regalo("Arriba", "GG")
	var s: Dictionary = sim.supervivientes[0]
	s.x = 680; s.f = 4; s.vy = Sim.PISO_Y[4]; s.y = Sim.PASILLO_Y
	sim.spawn_zombi(1, "corredor")
	var z: Dictionary = sim.zombis[0]
	z.x = 600; z.y = Sim.PASILLO_Y; z.dentro = true
	var vio_escalera := false
	for i in range(3000):
		sim._zombi(z, 0.1)
		if not z.escalera.is_empty():
			vio_escalera = true
			comprobar(z.x >= 489.9 and z.x <= 530.1 and z.y >= 0.59 and z.y <= 3.61, "Zombi se sale de los tramos")
		if z.f == 4: break
	comprobar(vio_escalera and z.f == 4 and is_equal_approx(z.vy, Sim.PISO_Y[4]), "Zombi no recorre las cuatro escaleras hasta la ultima planta")
