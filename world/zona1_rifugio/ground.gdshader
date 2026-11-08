shader_type spatial;
varying vec3 wp;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(wp.xz*0.8)*0.5+noise(wp.xz*3.0)*0.3+noise(wp.xz*24.0)*0.2;
 vec3 moss=mix(vec3(0.085,0.11,0.066),vec3(0.24,0.25,0.16),n);
 vec3 dirt=mix(vec3(0.13,0.115,0.085),vec3(0.31,0.285,0.23),n);
 float path=1.0-smoothstep(3.5,6.0,abs(wp.x-6.0));
 ALBEDO=mix(moss,dirt,max(path*0.65,smoothstep(8.0,14.0,wp.z)));
 ROUGHNESS=0.96;
}
