shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y); }
void sky() {
 float h=max(EYEDIR.y,0.0);
 vec3 c=mix(vec3(0.76,0.43,0.23),vec3(0.10,0.22,0.30),pow(h,0.35));
 vec2 uv=EYEDIR.xz/(h+0.18)*1.6+vec2(TIME*0.002,0.0);
 float n=noise(uv)*0.55+noise(uv*2.1)*0.28+noise(uv*4.3)*0.17;
 float clouds=smoothstep(0.48,0.74,n)*smoothstep(0.0,0.15,h);
 c=mix(c,mix(vec3(0.31,0.33,0.35),vec3(0.80,0.61,0.43),pow(1.0-h,3.0)),clouds*0.8);
 float sun=dot(EYEDIR,normalize(vec3(-0.5,0.22,-0.75)));
 c+=vec3(1.0,0.64,0.28)*pow(max(sun,0.0),180.0)*1.7;
 COLOR=c;
}
