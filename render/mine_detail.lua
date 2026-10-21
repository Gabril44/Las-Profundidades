-- Visual-only geology. Never changes tiles, collision or puzzle state.
local M={}
local palettes={{.38,.29,.23},{.3,.38,.32},{.34,.34,.43},{.25,.42,.25},{.4,.3,.5},{.44,.34,.65}}
local function noise(n) local v=math.sin(n*12.9898)*43758.5453; return v-math.floor(v) end
local function tint(c,a,k) love.graphics.setColor(c[1]*(k or 1),c[2]*(k or 1),c[3]*(k or 1),a) end

function M.background(cam,region,w,h,t)
 local g=love.graphics; local c=palettes[region]; local astral=(region-1)/5
 for layer=1,2 do
  local parallax=.16+layer*.16; local step=410-layer*45
  for ix=math.floor(cam.x*parallax/step)-1,math.ceil((cam.x*parallax+w)/step)+1 do
   for iy=math.floor(cam.y*parallax/420)-1,math.ceil((cam.y*parallax+h)/420)+1 do
    local seed=ix*73+iy*131; local x=cam.x+ix*step-cam.x*parallax
    local y=cam.y+iy*420-cam.y*parallax+noise(seed)*65
    local drift=region>=5 and math.sin(t*.24+seed)*12*astral or 0
    y=y+drift
    tint(c,.15+layer*.055,.5)
    -- Distant tunnel mouths and their broken masonry shoulders.
    g.rectangle('fill',x,y,145,230,66,66)
    g.setColor(.006,.007,.013,.55); g.rectangle('fill',x+18,y+24,109,207,50,50)
    tint(c,.19); g.arc('line','open',x+72,y+75,64,math.pi,2*math.pi)
    for rib=0,4 do g.line(x-15,y+95+rib*30,x+5,y+90+rib*30) end
    if region<=3 then
     tint(c,.22,.7); g.rectangle('fill',x-31,y-20,9,255)
     g.rectangle('fill',x-35,y-20,198,8)
     g.line(x-30,y+190,x+155,y+181,x+step,y+207)
     g.line(x-30,y+200,x+155,y+191,x+step,y+217)
     g.circle('line',x+172,y+143,26); g.circle('line',x+172,y+143,8)
     for spoke=1,6 do local a=spoke*math.pi/3; g.line(x+172,y+143,x+172+math.cos(a)*25,y+143+math.sin(a)*25) end
    else
     tint(c,.15+astral*.08)
     for shard=1,4 do
      local sx=x+164+shard*18; local sy=y+160-shard*29+drift
      g.polygon('line',sx,sy,sx+23,sy-12,sx+35,sy+9,sx+12,sy+21)
     end
    end
   end
  end
 end
end

function M.rock(x,y,tx,ty,region,tileAt,player,lights,t,flashIntensity)
 local g=love.graphics; local c=palettes[region]; local seed=tx*91+ty*47
 local top=tileAt(tx,ty-1)~='#'; local bottom=tileAt(tx,ty+1)~='#'
 -- Facets sit inside the collision silhouette; hanging chips are at most 5px.
 tint(c,.24); g.polygon('fill',x+2,y+9,x+19,y+3,x+44,y+15,x+31,y+30,x+7,y+25)
 tint(c,.15); g.polygon('fill',x+9,y+32,x+32,y+25,x+46,y+39,x+39,y+46,x+3,y+45)
 g.setColor(.015,.014,.024,.48)
 local offset=seed%17
 g.line(x+4,y+17+offset,x+18,y+13+offset,x+27,y+22+offset,x+43,y+18+offset)
 tint(c,.32); g.line(x+5,y+16+offset,x+18,y+12+offset)
 if top then
  tint(c,.8); g.line(x,y+1,x+48,y+1)
  for i=1,4 do local px=x+i*10; tint(c,.5); g.polygon('fill',px-5,y+2,px+3,y+2,px+6,y+5+noise(seed+i)*4,px-2,y+7) end
  -- Sparse traces, never a new interactive marker or a written solution.
  if seed%19==0 then
   g.setColor(.19,.14,.1,.8); g.line(x+13,y-1,x+18,y-13,x+30,y-10,x+33,y-1)
   g.line(x+17,y-8,x+29,y-6); g.line(x+18,y-13,x+19,y-22)
  elseif region==4 and seed%4==0 then
   g.setColor(.22,.32,.13,.7); g.line(x+9,y+3,x+15,y+12,x+10,y+24,x+18,y+37)
  end
 end
 if bottom then
  tint(c,.5,.7); g.polygon('fill',x+3,y+46,x+10,y+53,x+19,y+47,x+33,y+51,x+45,y+46)
 end
 -- Local surface response: range falloff, not a screen-wide bright overlay.
 local px,py=player.x+player.w/2,player.y+player.h*.4
 local dx,dy=x+24-px,y+24-py; local d=math.sqrt(dx*dx+dy*dy)
 local strength=0
 if player.lanternOn and (player.light or 0)>0 and dx*(player.facing or 1)>-30 then strength=math.max(0,1-d/235)*.26 end
 strength=math.max(strength,math.max(0,1-d/305)*math.min(1,(player.flashTimer or 0)/.42)*.55*(flashIntensity or 1))
 local red,green,blue=1,.72,.36
 for _,light in ipairs(lights) do
  local lx,ly=x+24-light.x,y+24-light.y; local a=math.max(0,1-math.sqrt(lx*lx+ly*ly)/light.radius)*light.alpha
  if a>strength then strength=a; red,green,blue=light.r,light.g,light.b end
 end
 if strength>0 then
  g.setColor(red,green,blue,strength*.4); g.rectangle('fill',x+1,y+1,46,46)
  g.setColor(red,green,blue,strength); g.line(x+2,y+2,x+46,y+2)
  g.line(x+3,y+15+offset,x+18,y+11+offset)
 end
 if region>=5 and seed%7==0 then
  tint(c,.2+.08*math.sin(t*.6+seed)); g.line(x+15,y+8,x+23,y+21,x+19,y+30,x+31,y+41)
 end
end

function M.fixture(x,y,region,kind)
 local g=love.graphics; local c=palettes[region]
 if kind=='A' or kind=='V' then
  g.setColor(.065,.06,.07,.9); g.polygon('fill',x+9,y+13,x+22,y+5,x+39,y+13,x+38,y+37,x+23,y+42,x+8,y+32)
  tint(c,.8); g.rectangle('line',x+12,y+11,24,27,3)
  for _,p in ipairs({{15,14},{33,14},{15,34},{33,34}}) do g.circle('fill',x+p[1],y+p[2],1.5) end
 elseif kind=='Z' or kind=='T' then
  tint(c,.65); g.ellipse('line',x+24,y+46,23,4)
  g.setColor(.08,.065,.09,.7); g.polygon('fill',x+2,y+46,x+9,y+40,x+36,y+40,x+46,y+46,x+38,y+49,x+8,y+49)
 end
end

function M.lights(refuges,tileAt,x1,x2,y1,y2,t)
 local result={}
 for _,r in ipairs(refuges) do
  if r.x>(x1-6)*48 and r.x<(x2+6)*48 and r.y>(y1-6)*48 and r.y<(y2+6)*48 then
   result[#result+1]={x=r.x,y=r.y-12,radius=210,alpha=.35+math.sin(t*4.7+r.x)*.025,r=1,g=.48,b=.15}
  end
 end
 for y=y1,y2 do for x=x1,x2 do if tileAt(x,y)=='Z' then
  result[#result+1]={x=(x-1)*48+24,y=(y-1)*48+38,radius=100,alpha=.22,r=.46,g=.78,b=.78}
 end end end
 return result
end
return M
