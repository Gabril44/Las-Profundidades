local Puzzles={}
local function near(e,m,r) local dx,dy=(e.x+e.w/2)-(m.x+24),(e.y+e.h/2)-(m.y+24); return dx*dx+dy*dy<r*r end
local function crossedPlate(e,m)
 local now=e.x+e.w/2
 local before=(e.previousX or e.x)+e.w/2
 local plateX=m.x+24
 local left,right=math.min(before,now)-12,math.max(before,now)+12
 local feet=e.y+e.h
 return plateX>=left and plateX<=right and math.abs(feet-(m.y+48))<30
end

function Puzzles.create(findChars)
 local plates=findChars("f")
 for _,plate in ipairs(findChars("j")) do plates[#plates+1]=plate end
 return {plates=plates,requiredPlates=2,crystals=findChars("Y"),resonance=0,quiet=0,counterweight=false,counterweightSolved=false,shadowTimer=0,rootLightBlend=1,astralAlive=false,astralRadius=340}
end

function Puzzles.astralInfluence(s,x,y)
 if not s or not s.astralAlive or not s.astralX then return 0 end
 local dx,dy=x-s.astralX,y-s.astralY
 local distance=math.sqrt(dx*dx+dy*dy)
 local radius=s.astralRadius or 340
 return math.max(0,math.min(1,(radius+90-distance)/90))
end

function Puzzles.solid(s,c,p,tx,ty,tile)
 if c=="p" then return s.counterweight end
 if c=="g" then return s.resonance>.16 end
 if c=="r" then return s and (s.rootLightBlend or 0)>=.72 or (not s and p and p.lanternOn) end
 if c=="o" then return s and (s.rootLightBlend or 1)<=.28 or (not s and p and not p.lanternOn) end
 if c=="i" then return s.shadowTimer>0 end
 if c=="m" then
  if not tx or not ty or not s.astralAlive then return false end
  tile=tile or 48
  local cx,cy=(tx-.5)*tile,(ty-.5)*tile
  local dx,dy=cx-s.astralX,cy-s.astralY
  local radius=s.astralRadius or 340
  return dx*dx+dy*dy<=radius*radius
 end
 if c=="b" then return not s.counterweightSolved end
 if c=="s" then return s.shadowTimer<=0 end
 -- La antigua compuerta dependía de abrir el mapa. Queda como vestigio
 -- espectral, nunca como pared invisible ni como regla de interfaz.
 if c=="n" then return false end
 return false
end

function Puzzles.noise(s,x,y,power,region,play,message)
 if region~=3 then return end
 local touched=false
 for _,c in ipairs(s.crystals) do local dx,dy=x-c.x-24,y-c.y-24; if dx*dx+dy*dy<(250+power*55)^2 then c.ring=1; touched=true end end
 if touched then
  local before=s.resonance; s.resonance=math.min(1,s.resonance+power*.22); s.quiet=0
  if before<.55 and s.resonance>=.55 then play("crystalAlarm",.03); message("La cámara aprendió tu voz.",3.5) end
 end
end

function Puzzles.flash(s,region) if region==5 then s.shadowTimer=4.2 end end
function Puzzles.targetPlate(s,e,enemies,preferredDirection)
 local best,bestDistance
 local hasLower=false
 for _,plate in ipairs(s.plates) do
  local reserved=false
  for _,other in ipairs(enemies or {}) do
   if other~=e and not other.dead and not other.boundPlate and other.counterTarget==plate then reserved=true break end
  end
  if not plate.locked and not reserved and plate.y+48>e.y+e.h+24 then hasLower=true break end
 end
 for _,plate in ipairs(s.plates) do
  local reserved=false
  for _,other in ipairs(enemies or {}) do
   if other~=e and not other.dead and not other.boundPlate and other.counterTarget==plate then reserved=true break end
  end
  local isLower=plate.y+48>e.y+e.h+24
  if not plate.locked and not reserved and (not hasLower or isLower) then
   local dx,dy=(e.x+e.w/2)-(plate.x+24),(e.y+e.h)-(plate.y+48)
   -- Horizontal travel matters more than height because a charging Custodian
   -- can deliberately leave a ledge, then correct towards either free clamp.
   local distance=math.abs(dx)+math.abs(dy)*.32
   local plateDirection=dx==0 and 0 or (dx>0 and -1 or 1)
   -- El destello compromete al Custodio con ese lado del escenario. Si hay
   -- una trampa libre allí, nunca debe elegir primero otra a sus espaldas.
   if preferredDirection and preferredDirection~=0 and plateDirection~=preferredDirection then
    distance=distance+10000
   end
   if not bestDistance or distance<bestDistance then best,bestDistance=plate,distance end
  end
 end
 return best
end

function Puzzles.update(s,dt,game,region,play,message)
 s.resonance=math.max(0,s.resonance-dt*.075); s.shadowTimer=math.max(0,s.shadowTimer-dt)
 s.astralAlive=false
 for _,enemy in ipairs(game.enemies or {}) do
  if enemy.kind=="astral" and not enemy.dead then
   s.astralAlive=true
   s.astralX,s.astralY=enemy.x+enemy.w*.5,enemy.y+enemy.h*.5
   s.astralRadius=enemy.astralAuraRadius or 340
   enemy.astralAuraRadius=s.astralRadius
   break
  end
 end
 s.quiet=s.resonance<.16 and s.quiet+dt or 0
 for _,c in ipairs(s.crystals) do c.ring=math.max(0,(c.ring or 0)-dt*1.5) end
 local active=0
 for _,plate in ipairs(s.plates) do
  plate.active=plate.locked and true or false
  if not plate.locked then
   for _,e in ipairs(game.enemies or {}) do
    local sameFloor=math.abs((e.y+e.h)-(plate.y+48))<30
    local inChannel=sameFloor and math.abs((e.x+e.w/2)-(plate.x+24))<190
    if not e.dead and e.kind=="custodian" and not e.boundPlate and (near(e,plate,52) or crossedPlate(e,plate) or inChannel) then
     plate.locked,plate.active,e.boundPlate=true,true,plate; e.vx,e.vy,e.awake=0,0,false
     e.x,e.y=plate.x+5,plate.y+48-e.h
     e.trapTimer,e.trappedTime,plate.clampTimer=1.05,0,1.05
     game.shake=math.max(game.shake or 0,.7); game.hitstop=math.max(game.hitstop or 0,.06); game.puzzleDirty=true
     play("counterweight",.04); message("El hierro acepta el peso.",3.5); break
    end
   end
  end
  if plate.active then active=active+1 end
 end
 for _,plate in ipairs(s.plates) do plate.clampTimer=math.max(0,(plate.clampTimer or 0)-dt) end
 for _,e in ipairs(game.enemies or {}) do
  if e.boundPlate then
   e.x=e.boundPlate.x+5; e.y=e.boundPlate.y+48-e.h; e.vx,e.vy,e.awake=0,0,false
   e.trapTimer=math.max(0,(e.trapTimer or 0)-dt); e.trappedTime=(e.trappedTime or 0)+dt
  end
 end
 local was=s.counterweightSolved
 if active>=(s.requiredPlates or 2) then s.counterweightSolved=true end
 s.counterweight=s.counterweightSolved
 if s.counterweightSolved and not was then play("counterweight",.03); play("deepRumble",.008); message("Dos ausencias encuentran equilibrio.",4) end
 local lit=game.player.lanternOn
 s.rootLightBlend=s.rootLightBlend+(lit and 1 or -1)*dt*1.65
 s.rootLightBlend=math.max(0,math.min(1,s.rootLightBlend))
 if region==4 and s.lastLightState~=nil and lit~=s.lastLightState then play("roots",.04) end
 s.lastLightState=lit
end

local function rootNoise(seed)
 local value=math.sin(seed*12.9898+78.233)*43758.5453
 return (value-math.floor(value))*2-1
end

local function rootStrand(x,y,c,index,hardness,t)
 local hard=hardness>.5
 local vertical=c=="r"
 local seed=x*.071+y*.113+index*19.7+(vertical and 3.1 or 8.4)
 local points={}
 local sway=(2.1+math.sin(t*.75+seed)*1.15)*(1-hardness)+.65*hardness
 local base=9+index*12+rootNoise(seed)*4
 for step=0,7 do
  local progress=step/7
  local bend=rootNoise(seed+step*2.31)*3.8+math.sin(progress*5.4+seed)*sway
  if vertical then
   points[#points+1]=x+base+bend
   points[#points+1]=y+52-progress*58
  else
   points[#points+1]=x-5+progress*58
   points[#points+1]=y+base+bend
  end
 end

 local width=(4.4+hardness*3)+(3-index)*.65
 -- Sombra de contacto, cambium oscuro, corteza y humedad: cuatro capas dan
 -- volumen sin necesitar una textura rasterizada.
 love.graphics.setLineJoin("bevel")
 love.graphics.setLineWidth(width+5); love.graphics.setColor(.018,.025,.018,hard and .82 or .48); love.graphics.line(points)
 love.graphics.setLineWidth(width+2); love.graphics.setColor(hard and {.105,.16,.095,.98} or {.075,.12,.075,.72}); love.graphics.line(points)
 love.graphics.setLineWidth(width); love.graphics.setColor(hard and {.27,.34,.18,.98} or {.18,.3,.16,.78}); love.graphics.line(points)
 love.graphics.setLineWidth(math.max(1,width*.2)); love.graphics.setColor(.55,.58,.3,hard and .5 or .24); love.graphics.line(points)

 -- Cicatrices transversales de la corteza y pequeñas lenticelas.
 for step=1,6 do
  local px,py=points[step*2+1],points[step*2+2]
  local scar=width*.62
  love.graphics.setLineWidth(1)
  love.graphics.setColor(.045,.07,.035,hard and .9 or .55)
  if vertical then love.graphics.line(px-scar,py+rootNoise(seed+step)*2,px+scar,py-rootNoise(seed+step)*2)
  else love.graphics.line(px+rootNoise(seed+step)*2,py-scar,px-rootNoise(seed+step)*2,py+scar) end
  if step%2==0 then
   love.graphics.setColor(.65,.72,.39,hard and .28 or .13)
   love.graphics.ellipse("fill",px+(vertical and width*.3 or 0),py+(vertical and 0 or width*.3),1.3,2.1)
  end
 end

 -- Raíces laterales que se afinan en dos etapas y pelos radiculares casi
 -- transparentes. Su asimetría es determinista para que la planta no titile.
 for branch=2,6,2 do
  local px,py=points[branch*2+1],points[branch*2+2]
  local side=rootNoise(seed+branch*7)>0 and 1 or -1
  local length=8+math.abs(rootNoise(seed+branch))*8
  local twitch=hard and 0 or math.sin(t*1.15+seed+branch)*1.4
  love.graphics.setColor(.14,.24,.12,hard and .92 or .58); love.graphics.setLineWidth(math.max(1.3,width*.34))
  if vertical then
   love.graphics.line(px,py,px+side*length*.55,py-4+twitch,px+side*length,py-10+twitch)
   love.graphics.setColor(.43,.5,.26,hard and .28 or .18); love.graphics.setLineWidth(.7)
   love.graphics.line(px+side*length*.55,py-4,px+side*(length+6),py-1+twitch)
  else
   love.graphics.line(px,py,px+5,py+side*length*.55+twitch,px+11,py+side*length+twitch)
   love.graphics.setColor(.43,.5,.26,hard and .28 or .18); love.graphics.setLineWidth(.7)
   love.graphics.line(px+5,py+side*length*.55,px+2,py+side*(length+6)+twitch)
  end
 end

 -- Nudo húmedo y una gota que captura la linterna.
 local knotStep=2+(index%3)
 local kx,ky=points[knotStep*2+1],points[knotStep*2+2]
 love.graphics.setColor(.055,.085,.045,.9); love.graphics.ellipse("fill",kx,ky,width*.55,width*.72)
 love.graphics.setColor(.46,.55,.29,hard and .48 or .28); love.graphics.ellipse("line",kx,ky,width*.38,width*.52)
 love.graphics.setColor(.68,.8,.58,hard and .2 or (.18+.08*math.sin(t+seed)))
 love.graphics.circle("fill",kx-width*.18,ky-width*.2,1.15)
end

local function drawRoots(s,c,x,y,t,p)
 local hardness=c=="r" and (s.rootLightBlend or 0) or (1-(s.rootLightBlend or 0))
 local hard=hardness>.5
 -- Masa profunda: otras raíces quedan insinuadas detrás de las principales.
 love.graphics.setColor(.018,.04,.022,hard and .8 or .45)
 if c=="r" then love.graphics.rectangle("fill",x+4,y,40,48) else love.graphics.rectangle("fill",x,y+7,48,38) end
 for index=1,3 do rootStrand(x,y,c,index,hardness,t) end
 love.graphics.setLineWidth(1); love.graphics.setLineJoin("miter")
end

function Puzzles.draw(s,c,x,y,t,p)
 if c=="f" or c=="j" then
  local active,clamp=false,0; for _,plate in ipairs(s.plates) do if plate.x==x and plate.y==y then active,clamp=plate.active,plate.clampTimer or 0 end end
  local snap=active and math.max(0,math.min(1,1-clamp/1.05)) or 0
  love.graphics.setColor(.16,.13,.1); love.graphics.rectangle("fill",x+3,y+35,42,10,2)
  love.graphics.setColor(active and {.9,.7,.22} or {.48,.34,.2}); love.graphics.rectangle("line",x+5,y+33,38,11,2)
  love.graphics.polygon("fill",x+4+snap*9,y+34,x+14+snap*8,y+24,x+18+snap*5,y+36)
  love.graphics.polygon("fill",x+44-snap*9,y+34,x+34-snap*8,y+24,x+30-snap*5,y+36)
  if active then love.graphics.setColor(.95,.68,.18,.18+.12*math.sin(t*7)); love.graphics.circle("line",x+24,y+31,18+math.sin(t*5)*2) end
 elseif c=="Y" then
  local ring=0; for _,crystal in ipairs(s.crystals) do if crystal.x==x and crystal.y==y then ring=crystal.ring or 0 end end
  love.graphics.setColor(.25,.72,.68,.12+ring*.3); love.graphics.circle("fill",x+24,y+25,19+ring*5)
 love.graphics.setColor(.42,.9,.84); love.graphics.polygon("line",x+24,y+4,x+37,y+34,x+24,y+44,x+11,y+34)
 elseif c=="r" or c=="o" then
  drawRoots(s,c,x,y,t,p)
 elseif c=="p" or c=="i" or c=="m" then
  local influence=c=="m" and Puzzles.astralInfluence(s,x+24,y+24) or 0
  local visible=c=="m" and influence>=1 or Puzzles.solid(s,c,p)
  local col=c=="p" and {.62,.42,.18} or c=="i" and {.28,.2,.42} or {.55,.4,.82}
  local alpha=c=="m" and (.04+influence*.84) or (visible and .88 or .1)
  love.graphics.setColor(col[1],col[2],col[3],alpha)
  love.graphics.rectangle(visible and "fill" or "line",x,y+8,48,40)
  if c=="m" and influence>0 then
   love.graphics.setColor(.82,.67,1,.1+influence*.32)
   love.graphics.line(x+5,y+13,x+20,y+20,x+11,y+31,x+42,y+43)
   love.graphics.circle("fill",x+24,y+27,1.2+influence*1.8)
  end
 elseif c=="b" or c=="s" or c=="n" then
  local closed=Puzzles.solid(s,c,p); local col=c=="b" and {.72,.47,.18} or c=="s" and {.32,.18,.46} or {.64,.42,.88}
  love.graphics.setColor(col[1],col[2],col[3],closed and .9 or .13)
  if closed then love.graphics.rectangle("fill",x+7,y,34,48) else love.graphics.line(x+7,y,x+41,y+48,x+7,y+48,x+41,y) end
 elseif c=="g" then
  love.graphics.setColor(.25,.8,.72,.18+s.resonance*.55); love.graphics.rectangle("fill",x+14,y,20,48)
 end
end
return Puzzles
