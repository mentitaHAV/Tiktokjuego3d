extends SceneTree
func _initialize() -> void:call_deferred("crear")
func crear() -> void:
	root.size=Vector2i(960,540)
	var mundo:=Node3D.new();root.add_child(mundo)
	var ambiente:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("101820")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("637389");env.ambient_light_energy=.3
	ambiente.environment=env;mundo.add_child(ambiente)
	var luz:=DirectionalLight3D.new();mundo.add_child(luz)
	luz.rotation_degrees=Vector3(-45,-25,0);luz.light_color=Color("edc495");luz.light_energy=1.5;luz.shadow_enabled=true
	var lateral:=OmniLight3D.new();mundo.add_child(lateral);lateral.position=Vector3(-2,3,-2);lateral.light_color=Color("718cbe");lateral.light_energy=4;lateral.omni_range=8
	var plano:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(20,20);plano.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color("25323a");plano.material_override=material;mundo.add_child(plano)
	var sim:=Sim.new(42)
	for i in range(3):
		var s: Dictionary
		if i<2:
			s=sim._nuevo_superviviente("Modelo"+str(i));s.modelo_arma="Pistola" if i==0 else "AK"
			s.accion="disparar";s.llego=true;s.apunta_x=75;s.apunta_y=0;s.apunta_z=1.4
		else:
			sim.spawn_zombi(1,"normal");s=sim.zombis[0]
		s.x=(i-1)*37.0;s.y=0;s.vy=0;s.f=0;s.camina=false;s.dir=1
		var actor:=preload("res://scripts/actor_3d.gd").new();mundo.add_child(actor);actor.crear(s,i==2);actor.actualizar(s,.1,sim.camas())
	var cam:=Camera3D.new();mundo.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=2.65
	cam.position=Vector3(3.0,2.0,4.6);cam.look_at(Vector3(0,.9,0));cam.current=true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/modelos-3d-detalle.png")
	quit()
