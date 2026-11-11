shader_type spatial;
render_mode diffuse_burley;
varying vec3 local;
void vertex(){ local=VERTEX; }
void fragment(){
 float fibra=sin(local.x*115.0+sin(local.y*75.0)*1.5+sin(local.x*13.0));
 float veta=sin(local.x*23.0+local.y*170.0);
 float mezcla=clamp(0.48+fibra*0.12+veta*0.12,0.0,1.0);
 ALBEDO=mix(vec3(0.105,0.065,0.035),vec3(0.36,0.245,0.12),mezcla);
 ROUGHNESS=0.94;
}
