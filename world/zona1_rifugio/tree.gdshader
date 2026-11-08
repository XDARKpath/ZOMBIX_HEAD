shader_type spatial;
render_mode cull_disabled;
varying vec3 local_pos;
void vertex(){
 local_pos=VERTEX;
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*0.8+wp.x*0.4+wp.z*0.5)*max(0.0,VERTEX.y-1.2)*0.008;
}
void fragment(){
 float variation=sin(local_pos.x*9.0+local_pos.z*5.0)*0.5+0.5;
 vec3 leaf=mix(vec3(0.055,0.105,0.075),vec3(0.12,0.19,0.10),variation);
 vec3 bark=mix(vec3(0.12,0.10,0.078),vec3(0.21,0.19,0.145),variation);
 ALBEDO=mix(bark,leaf,smoothstep(0.7,1.4,local_pos.y));
 ROUGHNESS=0.95;
}
