class_name Navegacion
extends RefCounted
const CELDA := 0.2
const RADIO := 0.14
var datos: Dictionary
var mapas := {}
func _init() -> void:
	datos = JSON.parse_string(FileAccess.get_file_as_string("res://arte/interiores.json"))
func transitable(x: float, y: float, f: int) -> bool:
	if f>0 and (x<6.15 or x>31.45 or y<0.05 or y>6.8):return false
	if f>0 and x>18.9 and x<21.85 and y>0.85 and y<4.3:return false
	for o in datos.obstaculos:
		if o.f==f and x>o.x0-RADIO and x<o.x1+RADIO and y>o.y0-RADIO and y<o.y1+RADIO:return false
	return true
func mapa(f: int) -> AStarGrid2D:
	if mapas.has(f):return mapas[f]
	var grid:=AStarGrid2D.new()
	grid.region=Rect2i(0,0,255,41)
	grid.cell_size=Vector2(CELDA,CELDA)
	grid.offset=Vector2(0,-0.8)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for i in range(255):
		for j in range(41):
			if not transitable(i*CELDA,j*CELDA-.8,f):grid.set_point_solid(Vector2i(i,j))
	mapas[f]=grid
	return grid
func celda(p: Vector2) -> Vector2i:return Vector2i(roundi(p.x/CELDA),roundi((p.y+.8)/CELDA))
func libre(grid: AStarGrid2D, p: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(p) and not grid.is_point_solid(p):return p
	for radio in range(1,8):
		for dx in range(-radio,radio+1):
			for dy in range(-radio,radio+1):
				var q:=p+Vector2i(dx,dy)
				if grid.is_in_boundsv(q) and not grid.is_point_solid(q):return q
	return Vector2i(-1,-1)
func seguir(c: Dictionary, tx: float, ty: float, f: int, dt: float, velocidad: float) -> bool:
	var inicio:=Vector2(c.x/25.0,c.y)
	var destino:=Vector2(tx/25.0,ty)
	var clave:=Vector3(destino.x,destino.y,f)
	if not c.has("ruta_destino") or c.ruta_destino!=clave:
		var grid:=mapa(f)
		var a:=libre(grid,celda(inicio));var b:=libre(grid,celda(destino))
		c.ruta=[];c.ruta_destino=clave
		if a.x<0 or b.x<0:return false
		for p in grid.get_point_path(a,b):c.ruta.append(p)
		if transitable(destino.x,destino.y,f):c.ruta.append(destino)
	var presupuesto:=velocidad*dt
	while presupuesto>0.0001 and not c.ruta.is_empty():
		var p: Vector2=c.ruta[0]
		var v: Vector2=p-inicio
		var d:=v.length()
		if d<0.005:c.ruta.pop_front();continue
		var avance:=minf(d,presupuesto)
		var siguiente:=inicio+v/d*avance
		if not transitable(siguiente.x,siguiente.y,f):
			c.erase("ruta_destino")
			return false
		inicio=siguiente;presupuesto-=avance;c.camina=true
		if absf(v.x)>.01:c.dir=1 if v.x>0 else -1
		c.x=inicio.x*25;c.y=inicio.y
	return c.ruta.is_empty() and inicio.distance_to(destino)<0.18
