shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 panel_size = vec2(500.0,280.0);
uniform float opacity = 0.6;
uniform float circular = 0.0;
uniform float radius = 10.0;
void fragment(){
 float r=min(radius,min(panel_size.x,panel_size.y)*0.5);
 vec2 q=abs((UV-0.5)*panel_size)-(panel_size*0.5-vec2(r));
 float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-r;
 if(circular>0.5) d=(length(UV-0.5)-0.495)*panel_size.x;
 float mask=1.0-smoothstep(-1.0,1.0,d);
 // Vetro smerigliato: sfocatura più ampia, così si legge il mondo dietro senza disturbare il testo.
 vec3 blur=textureLod(screen_tex,SCREEN_UV,3.4).rgb;
 vec3 tint=mix(vec3(0.05,0.09,0.10),vec3(0.12,0.18,0.19),1.0-UV.y);
 vec3 col=mix(blur*0.92,tint,opacity);
 // Riflesso morbido nella parte alta, come una lastra curva.
 col+=vec3(1.0,0.97,0.9)*pow(max(0.0,1.0-UV.y),3.0)*0.055;
 // Bordo ambrato sottile e luminoso, più caldo verso destra; un filo chiaro sul lato alto.
 float edge=(1.0-smoothstep(0.0,1.2,abs(d+1.0)))*0.30;
 col+=mix(vec3(0.82,0.56,0.26),vec3(0.98,0.74,0.40),UV.x)*edge;
 col+=vec3(1.0,0.95,0.85)*edge*smoothstep(0.55,0.0,UV.y)*0.35;
 // Un poco di trasparenza anche nel vetro stesso: i pannelli non sono scatole piene.
 COLOR=vec4(col,mask*mix(0.82,1.0,opacity));
}
