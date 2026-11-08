shader_type spatial;
uniform float head_height=0.38;
varying float height;
void vertex(){height=VERTEX.y;}
void fragment(){
 float head=step(head_height,height);
 ALBEDO=mix(vec3(0.21,0.12,0.055),vec3(0.4,0.45,0.46),head);
 METALLIC=head*0.7;
 ROUGHNESS=mix(0.9,0.4,head);
}


