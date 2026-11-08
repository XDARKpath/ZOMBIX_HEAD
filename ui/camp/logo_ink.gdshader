shader_type canvas_item;
void fragment(){
 vec4 ink=texture(TEXTURE,UV)*COLOR;
 float grain=fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453);
 float scratches=step(0.975,grain);
 float warmth=0.5+0.5*sin(TIME*1.3)*sin(TIME*2.1);
 ink.rgb*=mix(0.93,1.0,warmth);
 ink.a*=1.0-scratches*0.38;
 COLOR=ink;
}
