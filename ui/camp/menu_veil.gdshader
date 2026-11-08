shader_type canvas_item;
uniform float strength : hint_range(0.0,1.0)=1.0;
void fragment(){
 // Un'unica sfumatura continua; nessun rettangolo alle spalle delle voci.
 float side=1.0-smoothstep(0.0,0.55,UV.x);
 vec2 p=UV*2.0-1.0;
 float vignette=smoothstep(0.35,1.35,length(p*vec2(0.8,1.0)));
 float flicker=0.5+0.5*sin(TIME*1.9)*sin(TIME*3.1);
 vec3 shade=mix(vec3(0.018,0.028,0.030),vec3(0.065,0.032,0.014),flicker*0.3);
 COLOR=vec4(shade,(side*0.72+vignette*0.20)*strength);
}
