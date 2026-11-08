shader_type canvas_item;
uniform float hurt : hint_range(0.0,1.0)=0.0;
uniform float cinematic : hint_range(0.0,1.0)=0.0;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float edge=smoothstep(0.35,1.35,length(p*vec2(0.85,1.0)));
 float grain=fract(sin(dot(UV+TIME*0.001,vec2(127.1,311.7)))*43758.5453);
 COLOR=vec4(mix(vec3(0.015,0.025,0.03),vec3(0.45,0.015,0.01),hurt),edge*(0.23+cinematic*0.14+hurt*0.42)+grain*0.018);
}
