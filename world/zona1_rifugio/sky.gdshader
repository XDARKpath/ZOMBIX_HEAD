shader_type sky;
// Cielo d'estate: azzurro pieno in alto, orizzonte chiaro, alone caldo attorno al sole.
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y); }
void sky() {
 float h=max(EYEDIR.y,0.0);
 vec3 c=mix(vec3(0.80,0.86,0.90),vec3(0.30,0.55,0.86),pow(h,0.45));
 vec2 uv=EYEDIR.xz/(h+0.18)*1.6+vec2(TIME*0.002,0.0);
 float n=noise(uv)*0.55+noise(uv*2.1)*0.28+noise(uv*4.3)*0.17;
 float clouds=smoothstep(0.55,0.80,n)*smoothstep(0.0,0.15,h);
 c=mix(c,vec3(0.96,0.97,0.98),clouds*0.55);
 float sun=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
 c+=vec3(1.0,0.80,0.52)*(pow(sun,8.0)*0.35+pow(sun,400.0)*3.0);
 COLOR=c;
}