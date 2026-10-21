local Journal={}
local palettes={
 {{.76,.69,.55},{.25,.17,.13},{.48,.29,.14}},
 {{.7,.66,.53},{.2,.23,.19},{.42,.51,.38}},
 {{.64,.6,.66},{.22,.14,.28},{.55,.34,.61}},
 {{.54,.64,.52},{.09,.23,.17},{.29,.55,.36}},
 {{.25,.22,.36},{.79,.72,.87},{.57,.47,.76}},
 {{.09,.055,.19},{.86,.77,1},{.64,.38,.98}}
}
function Journal.theme(region) return palettes[math.max(1,math.min(6,region or 1))] end
function Journal.paper(W,H,region,t)
 local p=Journal.theme(region); local astral=region>=5
 love.graphics.setColor(.007,.005,.018,.98); love.graphics.rectangle('fill',0,0,W,H)
 if astral then
  love.graphics.setColor(p[3][1],p[3][2],p[3][3],.18)
  for i=1,4 do love.graphics.circle('line',W/2,H/2,250+i*38+math.sin(t+i)*7) end
 end
 love.graphics.setColor(.08,.045,.035); love.graphics.rectangle('fill',65,45,W-130,H-90,14)
 for i=5,1,-1 do
  love.graphics.setColor(p[1][1]*.8,p[1][2]*.8,p[1][3]*.8)
  local float=astral and math.sin(t*.7+i)*i*2 or i
  love.graphics.rectangle('fill',78-i,57+float,W-156+i*2,H-114,8)
 end
 love.graphics.setColor(p[1]); love.graphics.rectangle('fill',82,58,W-164,H-116,7)
 for i=1,90 do
  love.graphics.setColor(p[2][1],p[2][2],p[2][3],.045)
  local x=100+(i*137)%(W-210); local y=75+(i*83)%(H-160)
  love.graphics.line(x,y,x+9+i%23,y+math.sin(i)*2)
 end
 for i=1,17 do
  love.graphics.setColor(p[2][1],p[2][2],p[2][3],.1)
  love.graphics.line(110,120+i*28,W-110,120+i*28)
 end
 -- Lomo sombreado y anillas de metal; al fondo se abren en órbitas.
 for i=1,12 do
  love.graphics.setColor(0,0,0,.025); love.graphics.rectangle('fill',W/2-i*2,65,i*4,H-135)
 end
 for i=1,9 do
  local y=110+i*51
  love.graphics.setColor(p[3]); love.graphics.setLineWidth(3)
  if region==6 then
   love.graphics.push(); love.graphics.translate(W/2,y); love.graphics.rotate(t*.3+i)
   love.graphics.polygon('line',0,-13,17,0,0,13,-17,0); love.graphics.pop()
  else love.graphics.ellipse('line',W/2,y,18,7) end
 end
 love.graphics.setLineWidth(1)
 for i=1,4 do
  love.graphics.setColor(p[3][1],p[3][2],p[3][3],.8)
  love.graphics.rectangle('fill',W-84,150+i*81,22,48,4)
 end
 love.graphics.setColor(p[3]); love.graphics.polygon('fill',530,57,555,57,555,139,542,125,530,139)
 if region==4 then
  love.graphics.setColor(p[3][1],p[3][2],p[3][3],.6)
  for i=1,9 do love.graphics.line(94,480+i*10,110+i*4,450+i*12,91,435+i*12) end
 end
 if astral then
  for i=1,22 do
   local x=95+(i*173)%1090; local y=90+(i*97)%490
   love.graphics.setColor(p[3][1],p[3][2],p[3][3],.12+.09*math.sin(t+i))
   love.graphics.circle('line',x,y+math.sin(t+i)*6,3+i%5)
  end
 end
 return p
end
function Journal.pencil(x,y,t,region,alpha)
 local p=Journal.theme(region)
 love.graphics.push(); love.graphics.translate(x,y); love.graphics.rotate(.48+math.sin(t*19)*.035)
 love.graphics.setColor(p[3][1],p[3][2],p[3][3],alpha)
 love.graphics.rectangle('fill',-3,-39,6,29,1)
 love.graphics.setColor(.82,.68,.46,alpha); love.graphics.polygon('fill',-3,-10,3,-10,0,0)
 love.graphics.setColor(p[2][1],p[2][2],p[2][3],alpha); love.graphics.line(0,-3,0,0)
 love.graphics.pop()
end
function Journal.hud(book,region,t,font)
 if not book or book.notice<=0 then return end
 local age=3.4-book.notice; local a=math.min(1,age*5,book.notice*2)
 local p=Journal.theme(region)
 love.graphics.setColor(p[1][1],p[1][2],p[1][3],a*.95)
 love.graphics.rectangle('fill',1180,275,48,46,3)
 love.graphics.setColor(p[2][1],p[2][2],p[2][3],a*.8)
 local progress=math.min(1,age/2.3)
 for i=0,2 do
  local amount=math.max(0,math.min(1,progress*3-i))
  if amount>0 then love.graphics.line(1187,286+i*10,1187+amount*32,286+i*10) end
 end
 local line=math.min(2,math.floor(progress*3))
 Journal.pencil(1187+(progress*3-line)*32,286+line*10+math.sin(t*24),t,region,a)
 love.graphics.setFont(font); love.graphics.setColor(p[3][1],p[3][2],p[3][3],a)
 love.graphics.printf('CUADERNO',1050,334,205,'right')
end
return Journal
