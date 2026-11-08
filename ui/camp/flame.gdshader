shader_type spatial;
render_mode unshaded,cull_disabled,blend_add,depth_draw_never;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float width=mix(0.7,0.05,1.0-UV.y);
 float sway=sin(UV.y*8.0+TIME*6.0)*0.12;
 float edge=1.0-smoothstep(width*0.35,width,abs(p.x+sway));
 float alpha=edge*smoothstep(0.0,0.15,UV.y)*(1.0-smoothstep(0.7,1.0,UV.y));
 ALBEDO=mix(vec3(1.0,0.18,0.015),vec3(1.0,0.8,0.25),UV.y);
 EMISSION=ALBEDO*2.0;
 ALPHA=alpha*0.8;
}
