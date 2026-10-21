local EnemyRender = {}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a,b,t) return a+(b-a)*t end

local function rune(x,y,r,angle,color,alpha)
    love.graphics.push(); love.graphics.translate(x,y); love.graphics.rotate(angle)
    love.graphics.setColor(color[1],color[2],color[3],alpha)
    love.graphics.polygon("line",0,-r,r*.72,0,0,r,-r*.72,0)
    love.graphics.line(-r*.42,0,r*.42,0,0,-r*.52,0,r*.52)
    love.graphics.pop()
end

local function drawCustodian(e)
    local cx, cy = e.x + e.w / 2, e.y + e.h / 2
    local speed = math.abs(e.vx or 0)
    local gait = math.sin(e.phase * (2.4 + speed / 38))
    local breathe = math.sin(e.phase * 1.45)
    local wind = clamp((e.windup or 0) / .8, 0, 1)
    local charge = e.charging and 1 or 0
    local stun = clamp((e.stun or 0) / 1.35, 0, 1)
    local notice=clamp((e.noticeTimer or 0)/.72,0,1)
    local facing = (e.vx or 0) < 0 and -1 or 1
    local lean = facing * (charge * .28 - wind * .13)+math.sin(notice*math.pi)*facing*.1

    love.graphics.push()
    love.graphics.translate(cx, cy + math.abs(gait) * speed / 240)
    love.graphics.rotate(lean)
    love.graphics.scale(1 + wind * .18 + charge * .1 - stun * .08, 1 - wind * .13 + stun * .08)
    love.graphics.translate(-cx, -cy)

    if charge > 0 then
        for i = 1, 3 do
            love.graphics.setColor(.8, .12, .08, .13 / i)
            love.graphics.ellipse("fill", cx - facing * i * 13, cy, e.w / 2 + 4, e.h / 2 - 2)
        end
    end

    -- Dense contact shadow gives this enemy the weight its charge promises.
    love.graphics.setColor(.025,.015,.022,.5)
    love.graphics.ellipse("fill",cx,e.y+e.h+2,e.w*.58+charge*8,5-charge)

    local body = e.windup > 0 and {1, .5, .14} or (e.charging and {.84, .09, .08} or (e.awake and {.49, .1, .14} or {.16, .12, .18}))
    love.graphics.setColor(body)
    love.graphics.ellipse("fill", cx, cy - 1, e.w / 2 + 2, e.h / 2)
    love.graphics.setColor(.1, .075, .105)
    love.graphics.polygon("fill", e.x + 2, e.y + 13, e.x + 9, e.y + 2, e.x + 15, e.y + 14)
    love.graphics.polygon("fill", e.x + e.w - 2, e.y + 13, e.x + e.w - 9, e.y + 2, e.x + e.w - 15, e.y + 14)

    -- Chipped shoulder rims, rivets and an off-centre fracture keep every
    -- Custodian from reading as one smooth red blob.
    love.graphics.setColor(.48+.28*wind,.27,.2)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line","open",cx,cy-1,e.w/2-2,3.48,5.96)
    love.graphics.line(cx-facing*3,e.y+4,cx-facing*6,e.y+13,cx-facing*2,e.y+18)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(.72,.39,.23)
    love.graphics.circle("fill",e.x+7,e.y+18,1.4); love.graphics.circle("fill",e.x+e.w-7,e.y+18,1.4)
    if e.variant==2 then
        love.graphics.setColor(.19,.09,.1); love.graphics.line(e.x+4,e.y+7,e.x+14,e.y+18,e.x+9,e.y+27)
    elseif e.variant==3 then
        love.graphics.setColor(.55,.3,.18); love.graphics.circle("line",e.x+e.w-5,e.y+20,5)
        love.graphics.line(e.x+e.w,e.y+24,e.x+e.w+5,e.y+32)
    end

    -- Armor plates slide over one another while the body gathers force.
    love.graphics.setColor(.31, .2, .23)
    for i = 0, 3 do
        local px = e.x + 5 + i * 8
        love.graphics.line(px, e.y + 8 + math.abs(i - 1.5) * 2, px - facing * wind * 4, e.y + 28)
    end
    local corePulse=.55+.45*math.sin(e.phase*5)
    love.graphics.setColor(1,.28+.34*wind,.08,(e.awake and .38 or .12)+wind*.5)
    love.graphics.circle("fill",cx-facing*wind*3,cy+5,2.3+wind*3+corePulse)
    love.graphics.setColor(.12,.06,.075,.8)
    love.graphics.circle("line",cx,cy+5,5+wind*2)
    love.graphics.setColor(1, .16 + wind * .35, .1)
    local eyeY = e.y + 12 - wind * 2
    love.graphics.ellipse("fill", e.x + 11+facing*notice*2, eyeY, 3 + wind * 2+notice*2, 2+notice)
    love.graphics.ellipse("fill", e.x + 27+facing*notice*2, eyeY, 3 + wind * 2+notice*2, 2+notice)

    love.graphics.setColor(.09, .065, .085)
    love.graphics.setLineWidth(5)
    local stride = gait * clamp(speed / 80, 0, 1) * 5
    love.graphics.line(e.x + 9, e.y + 25, e.x + 6 + stride, e.y + 37)
    love.graphics.line(e.x + 29, e.y + 25, e.x + 32 - stride, e.y + 37)
    love.graphics.setLineWidth(1)
    love.graphics.pop()

    if notice>0 then
        local reveal=math.sin((1-notice)*math.pi)
        love.graphics.setColor(1,.27,.08,.18+reveal*.45)
        love.graphics.circle("line",cx,cy,24+(1-notice)*25)
        love.graphics.setColor(1,.5,.16,.22*notice)
        love.graphics.line(cx,cy,cx+facing*(34+notice*12),cy-4)
    end

    if e.windup > 0 then
        love.graphics.setColor(1, .2, .08, .22 + (1 - wind) * .35)
        love.graphics.circle("line", cx, cy, 23 + (1 - wind) * 18)
        love.graphics.setColor(1, .3, .12, .38)
        love.graphics.line(cx, cy, e.targetX, cy)
    end
end

local function drawTrappedCustodian(e)
    local cx,base=e.x+e.w/2,e.y+e.h
    local capture=clamp((e.trapTimer or 0)/1.05,0,1)
    local struggle=math.sin((e.trappedTime or 0)*7.5)*2.2*(1-capture*.65)
    local slam=math.sin((1-capture)*math.pi)*8
    love.graphics.push()
    love.graphics.translate(struggle,slam)
    love.graphics.translate(cx,base); love.graphics.scale(1+capture*.34,1-capture*.38); love.graphics.translate(-cx,-base)
    love.graphics.setColor(.26,.075,.09)
    love.graphics.ellipse("fill",cx,e.y+17,e.w/2+3,e.h/2-2)
    love.graphics.setColor(.38,.16,.17)
    for i=0,3 do love.graphics.line(e.x+6+i*8,e.y+7,e.x+4+i*9,e.y+29) end
    love.graphics.setColor(1,.13+.12*math.abs(math.sin((e.trappedTime or 0)*4)),.07)
    love.graphics.ellipse("fill",e.x+11,e.y+12,3,2); love.graphics.ellipse("fill",e.x+27,e.y+12,3,2)
    love.graphics.setColor(.08,.055,.07); love.graphics.setLineWidth(5)
    love.graphics.line(e.x+9,e.y+25,e.x+5,e.y+35); love.graphics.line(e.x+29,e.y+25,e.x+33,e.y+35)
    love.graphics.setLineWidth(1); love.graphics.pop()

    -- Las abrazaderas se dibujan por encima del cuerpo y permanecen cerradas.
    local close=1-capture
    love.graphics.setColor(.46,.29,.13)
    love.graphics.rectangle("fill",e.x-7+close*8,e.y+18,10,e.h-10,3)
    love.graphics.rectangle("fill",e.x+e.w-3-close*8,e.y+18,10,e.h-10,3)
    love.graphics.setColor(.9,.61,.18)
    love.graphics.line(e.x+1+close*7,e.y+21,e.x+e.w-1-close*7,e.y+28)
    love.graphics.line(e.x+1+close*7,e.y+31,e.x+e.w-1-close*7,e.y+20)
    love.graphics.circle("fill",cx,base-5,4)
    -- The prison remains a physical object after the puzzle: hooked feet,
    -- crossed chains and a locking rune pulse whenever the captive struggles.
    love.graphics.setColor(.18,.12,.09)
    love.graphics.rectangle("fill",e.x-10,base-4,e.w+20,6,2)
    love.graphics.setColor(.62,.42,.2)
    for i=0,5 do
        local x=e.x-4+i*8
        love.graphics.circle("line",x,base-8+(i%2)*2,3)
    end
    love.graphics.line(e.x-3,e.y+17,e.x+e.w+3,base-7)
    love.graphics.line(e.x+e.w+3,e.y+17,e.x-3,base-7)
    rune(cx,base-6,5,(e.trappedTime or 0)*.12,{1,.55,.16},.35+.2*math.abs(struggle))
    if capture>0 then
        for i=1,5 do
            local a=i*1.37+(1-capture)*4
            love.graphics.setColor(1,.58,.16,capture*.65)
            love.graphics.rectangle("fill",cx+math.cos(a)*(18+slam),base-10+math.sin(a)*15,3,3)
        end
    end
end

local function drawDefeatedCustodian(e)
    local t=e.deathTimer or 0
    local fall=clamp(t/.72,0,1); fall=fall*fall*(3-2*fall)
    local settle=clamp((t-.55)/1.1,0,1)
    local facing=e.defeatFacing or 1
    local cx=e.x+e.w/2
    local floorY=e.y+e.h
    local recoil=math.sin(math.min(1,t/.34)*math.pi)*12
    local breathe=math.sin(t*2.1)*(1-settle*.72)

    love.graphics.setColor(.025,.014,.018,.58)
    love.graphics.ellipse("fill",cx-facing*fall*13,floorY+2,24+fall*15,4+fall*2)
    love.graphics.push()
    love.graphics.translate(cx-facing*fall*13,floorY-17-recoil*(1-fall))
    love.graphics.rotate(facing*fall*1.48)
    love.graphics.scale(1+fall*.23,1-fall*.13+breathe*.015)
    love.graphics.setColor(.22,.065,.075)
    love.graphics.ellipse("fill",0,0,e.w/2+3,e.h/2)
    love.graphics.setColor(.32,.14,.15)
    for i=-1,2 do love.graphics.line(i*8,-13,i*7+facing*3,12) end
    -- Ojos casi apagados y una placa hundida: abatido, no evaporado.
    love.graphics.setColor(.45,.07,.055,.5-settle*.22)
    love.graphics.ellipse("fill",-8,-6,3,1.2); love.graphics.ellipse("fill",8,-6,3,1.2)
    love.graphics.setColor(.09,.05,.06)
    love.graphics.setLineWidth(5)
    love.graphics.line(-10,10,-17,18+fall*3); love.graphics.line(10,10,17,18+fall*3)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(.47,.25,.17,.7)
    love.graphics.arc("line","open",0,0,e.w/2-2,3.5,5.8)
    love.graphics.pop()

    if t<1.1 then
        for i=1,8 do
            local a=i*2.21
            local travel=t*(32+i*4)
            love.graphics.setColor(.5,.2,.13,(1-clamp(t/1.1,0,1))*.55)
            love.graphics.rectangle("fill",cx+math.cos(a)*travel,floorY-3+math.sin(a)*travel*.3,2+i%3,2+i%2)
        end
    end
end

local function drawListener(e)
    local cx, cy = e.x + e.w / 2, e.y + e.h / 2
    local listening = (e.soundTimer or 0) > 0
    local crawl = math.sin(e.phase * (listening and 10 or 3.2))
    local breath = math.sin(e.phase * 2.1)
    local airborne=not e.grounded or e.listenerLeap~=nil
    local stretch = listening and .13 or .03 * breath
    if airborne then stretch=stretch+.18 end

    love.graphics.setColor(.12, .48, .38, .08)
    love.graphics.ellipse("fill", cx, cy + 2, 31 + stretch * 30, 22 - stretch * 12)
    love.graphics.setColor(.055, .13, .125)
    love.graphics.ellipse("fill", cx, cy, 23 + stretch * 10, 15 - stretch * 5)
    if airborne then
        love.graphics.setColor(.22,.68,.5,.14)
        love.graphics.ellipse("line",cx,cy+13,26,8)
        if e.listenerLeap then
            local leap=e.listenerLeap
            love.graphics.setColor(.38,.95,.67,.18*(1-leap.t))
            love.graphics.arc("line","open",cx,cy,34+leap.t*18,math.pi*.12,math.pi*.88)
        end
    end

    -- Overlapping shell segments contract towards the listening membrane.
    love.graphics.setColor(.1,.29,.25,.72)
    for i=-2,2 do
        local sx=cx+i*7
        love.graphics.arc("line","open",sx,cy+1,8+math.abs(i)*1.5,.35,math.pi-.35)
    end

    -- The head is a closed listening membrane, not a face.
    love.graphics.setColor(.27, .72, .55, listening and .8 or .42)
    love.graphics.arc("line", "open", cx, cy - 2, 13 + breath, .12, math.pi - .12)
    love.graphics.arc("line", "open", cx, cy - 1, 8, math.pi + .25, math.pi * 2 - .25)
    love.graphics.setColor(.08, .24, .2)
    for i = 0, 5 do
        local rootX = e.x + 1 + i * 7.2
        local tip = crawl * (i % 2 == 0 and 4 or -4)
        love.graphics.line(rootX, e.y + 23, rootX - 5 + tip, e.y + 39)
        love.graphics.circle("fill",rootX-5+tip,e.y+39,1.7)
    end
    love.graphics.setColor(.34, .8, .61, .35)
    love.graphics.line(cx - 12, cy + 5, cx + 12, cy + 5)
    for i = -2, 2 do love.graphics.line(cx + i * 5, cy + 5, cx + i * 4, cy + 10) end
    if e.variant==2 then
        love.graphics.setColor(.2,.55,.43,.45); love.graphics.arc("line","open",cx-7,cy-4,19,2.8,5.5)
    elseif e.variant==3 then
        love.graphics.setColor(.32,.7,.54,.4); love.graphics.line(cx+10,cy-13,cx+20,cy-23,cx+23,cy-12)
    end

    -- Fine whiskers sample vibrations before the whole creature commits.
    love.graphics.setColor(.42,.83,.66,listening and .62 or .2)
    for side=-1,1,2 do
        for i=1,3 do
            local sway=math.sin(e.phase*3+i)*2
            love.graphics.line(cx+side*16,cy-3+i*3,cx+side*(27+i*4),cy-8+i*7+sway)
        end
    end

    if listening then
        for i = 1, 3 do
            local radius = 18 + ((e.phase * 38 + i * 17) % 58)
            love.graphics.setColor(.38, .95, .67, clamp(1 - radius / 80, 0, .32))
            love.graphics.circle("line", cx, cy - 4, radius)
        end
    end
end

local function drawSealedListener(e)
    local cx,cy=e.x+e.w/2,e.y+e.h/2
    local t=e.sealedTime or love.timer.getTime()
    local snap=clamp(t/.72,0,1)
    local slam=math.sin(snap*math.pi)*9
    local struggle=math.sin(t*7.3)*1.4*(.35+.65*snap)
    -- The seal announces the capture once, then settles into a living prison.
    if t<1.25 then
        for i=1,4 do
            local progress=clamp(t*1.7-i*.07,0,1)
            love.graphics.setColor(.32,1,.65,(1-progress)*.34)
            love.graphics.circle("line",cx,cy,18+progress*(42+i*13))
        end
    end
    love.graphics.push()
    love.graphics.translate(struggle,slam*(1-snap))
    love.graphics.scale(1+math.sin(snap*math.pi)*.18,1-math.sin(snap*math.pi)*.22)
    drawListener(e)
    love.graphics.pop()
    -- The green seal remains visible as a physical prison instead of turning
    -- the creature into a corpse that slowly disappears.
    love.graphics.setColor(.18,.82,.58,.12)
    love.graphics.circle("fill",cx,cy,31+math.sin(t*2.4)*2)
    love.graphics.setColor(.38,1,.72,.72)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line",cx,cy,25)
    love.graphics.line(cx-25,cy,cx,cy-25,cx+25,cy,cx,cy+25,cx-25,cy)
    -- Four hooked restraints close from the corners and keep twitching under
    -- the creature's pressure instead of becoming a static cage sprite.
    for i=0,3 do
        local a=i*math.pi*.5+math.pi*.25
        local reach=54-(30*snap)+math.sin(t*6+i)*1.5
        local outerX,outerY=cx+math.cos(a)*reach,cy+math.sin(a)*reach*.72
        local innerX,innerY=cx+math.cos(a)*17,cy+math.sin(a)*13
        love.graphics.setColor(.12,.5,.34,.78)
        love.graphics.setLineWidth(4)
        love.graphics.line(outerX,outerY,lerp(outerX,innerX,.56),lerp(outerY,innerY,.56),innerX,innerY)
        love.graphics.setColor(.5,1,.73,.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line",innerX,innerY,4)
    end
    for i=0,3 do
        local a=t*.22+i*math.pi*.5
        local x,y=cx+math.cos(a)*33,cy+math.sin(a)*20
        rune(x,y,4,-a,{.42,1,.7},.48)
    end
    love.graphics.setColor(.52,1,.75,.1+.08*math.abs(math.sin(t*4.2)))
    love.graphics.circle("fill",cx,cy,38+math.sin(t*2.1)*3)
    love.graphics.setLineWidth(1)
end

local function drawAstral(e)
    local cx, cy = e.x + e.w / 2, e.y + e.h / 2
    local hover = math.sin(e.phase * 1.7) * 5
    local pulse = 1 + math.sin(e.phase * 3.7) * .08
    local hurt = clamp((e.stun or 0) / 1.35, 0, 1)
    local windup=clamp((e.astralWindup or 0)/.72,0,1)
    local dashing=(e.astralDash or 0)>0
    cy = cy + hover

    -- Su cercanía sostiene la arquitectura imposible. El borde incompleto del
    -- halo permite leer el alcance sin convertirlo en una interfaz perfecta.
    local aura=e.astralAuraRadius or 340
    love.graphics.setLineWidth(2)
    for i=0,19 do
        local a=e.phase*.035+i*(math.pi*2/20)
        local wobble=math.sin(e.phase*.7+i*2.1)*5
        love.graphics.setColor(.58,.3,.9,.045+(i%3)*.012)
        love.graphics.arc("line","open",cx,cy,aura+wobble,a,a+.17)
    end
    love.graphics.setColor(.5,.25,.85,.018)
    love.graphics.circle("fill",cx,cy,aura)
    love.graphics.setLineWidth(1)

    if e.astralPhasing then
        for i=1,3 do
            local direction=(e.vy or 0)<0 and 1 or -1
            love.graphics.setColor(.68,.35,1,.055*i)
            love.graphics.ellipse("line",cx,cy+direction*i*13,24+i*5,12+i*2)
        end
    end

    if dashing then
        local direction=e.astralDashDX or e.astralDashDirection or 1
        local vertical=e.astralDashDY or 0
        for i=5,1,-1 do
            love.graphics.setColor(.65,.26,1,.035*i)
            love.graphics.push(); love.graphics.translate(-direction*i*14,-vertical*i*14)
            love.graphics.polygon("fill",cx,cy-29,cx+27,cy,cx+12,cy+29,cx-14,cy+29,cx-28,cy)
            love.graphics.pop()
        end
    end

    for echo = 3, 1, -1 do
        local drift = math.sin(e.phase * 2 + echo) * echo * 3
        love.graphics.setColor(.52, .18, .9, .035 * echo)
        love.graphics.polygon("fill", cx + drift, cy - 31, cx + 30, cy, cx + 14, cy + 31, cx - 15, cy + 31, cx - 30, cy)
    end
    love.graphics.setColor(.48, .2, .75, .13 + hurt * .18)
    love.graphics.circle("fill", cx, cy, 43 * pulse)
    love.graphics.setColor(.2 + hurt * .22, .07, .36 + hurt * .2)
    love.graphics.polygon("fill", cx, cy - 32, cx + 30, cy, cx + 14, cy + 30, cx - 14, cy + 30, cx - 30, cy)

    -- A second, translucent internal body rotates against the outer one.
    love.graphics.push(); love.graphics.translate(cx,cy); love.graphics.rotate(-e.phase*.18)
    love.graphics.setColor(.68,.34,.9,.18+hurt*.2)
    love.graphics.polygon("fill",0,-22,17,0,0,23,-17,0)
    love.graphics.setColor(.9,.7,1,.32)
    love.graphics.line(0,-18,0,18,-13,0,13,0)
    love.graphics.pop()

    -- Broken halos rotate in opposite directions, selling its impossible depth.
    love.graphics.setLineWidth(2)
    love.graphics.setColor(.67, .38, .92, .7)
    love.graphics.arc("line", "open", cx, cy, 34, e.phase, e.phase + 1.8)
    love.graphics.arc("line", "open", cx, cy, 39, -e.phase * .7 + 2, -e.phase * .7 + 4.15)
    love.graphics.setLineWidth(1)

    if windup>0 then
        for i=1,3 do
            local r=28+(1-windup)*(28+i*12)
            love.graphics.setColor(.86,.55,1,windup*(.24+i*.06))
            love.graphics.arc("line","open",cx,cy,r,e.phase+i,e.phase+i+math.pi*1.18)
        end
    end

    for i=1,5 do
        local a=e.phase*(i%2==0 and -.22 or .16)+i*1.257
        local radius=46+(i%2)*8
        rune(cx+math.cos(a)*radius,cy+math.sin(a)*radius*.62,4+i%2,-a*.7,{.72,.44,1},.2+hurt*.24)
    end

    local pupil = 2 + (1 - math.abs(math.sin(e.phase * .9))) * 4
    love.graphics.setColor(.83, .56, 1)
    love.graphics.ellipse("fill", cx, cy - 4, 10 + hurt * 5, 7 - hurt * 3)
    love.graphics.setColor(.98, .92, 1)
    love.graphics.ellipse("fill", cx, cy - 4, pupil, 2)
    if e.variant==2 then
        love.graphics.setColor(.7,.4,1,.4); rune(cx-22,cy+4,7,e.phase*.3,{.72,.44,1},.45)
    elseif e.variant==3 then
        love.graphics.setColor(.75,.48,1,.38); love.graphics.arc("line","open",cx,cy,47,.2,2.4)
    end
    for i = 0, 3 do
        local sway = math.sin(e.phase * 2.4 + i * 1.3) * 7
        love.graphics.setColor(.57, .3, .82, .72 - i * .08)
        love.graphics.line(cx - 20 + i * 13, cy + 23, cx - 27 + i * 17 + sway, cy + 47 + i * 3)
    end
end

local function drawAstralDeparture(e)
    local cx,cy=e.x+e.w/2,e.y+e.h/2
    local t=e.astralDeathTime or 0
    local progress=clamp(t/3.05,0,1)
    local implode=clamp((progress-.7)/.3,0,1)
    local bodyScale=(1-implode)^2*(1+math.sin(t*19)*.08)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(.46,.16,.92,.055*(1-implode))
    love.graphics.circle("fill",cx,cy,90+t*64)
    for ring=1,5 do
        local radius=24+((t*105+ring*47)%210)
        love.graphics.setColor(.72,.42,1,(1-radius/245)*.42*(1-implode*.7))
        love.graphics.circle("line",cx,cy,radius)
    end
    for i=1,24 do
        local seed=i*2.399
        local radius=(42+i*5)*(1-implode*.82)+math.sin(t*4+i)*8
        local angle=seed+t*(.55+i%3*.18)
        rune(cx+math.cos(angle)*radius,cy+math.sin(angle)*radius*.72,
            3+i%4,-angle-t*1.4,{.78,.48,1},(.25+progress*.45)*(1-implode))
    end

    love.graphics.push()
    love.graphics.translate(cx,cy)
    love.graphics.scale(math.max(.01,bodyScale),math.max(.01,bodyScale))
    love.graphics.rotate(t*t*.32)
    love.graphics.setColor(.7,.34,1,.45+progress*.45)
    love.graphics.polygon("fill",0,-38,35,0,15,35,-15,35,-35,0)
    love.graphics.setColor(.97,.88,1,.75)
    love.graphics.polygon("fill",0,-25,19,0,0,26,-19,0)
    love.graphics.setColor(1,1,1,.95)
    love.graphics.ellipse("fill",0,-4,12+progress*7,4+progress*2)
    love.graphics.pop()

    if implode>.35 then
        love.graphics.setColor(.9,.7,1,implode*.8)
        love.graphics.circle("line",cx,cy,8+implode*115)
        love.graphics.circle("fill",cx,cy,math.max(1,(1-implode)*18))
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(1)
end

local function drawResonant(e)
    local cx, cy = e.x + e.w / 2, e.y + e.h / 2
    local speed = math.sqrt((e.vx or 0)^2 + (e.vy or 0)^2)
    local flap = math.sin(e.phase * (e.awake and 13 or 5.5))
    local spread = 17 + math.abs(flap) * 14 + clamp(speed / 24, 0, 12)
    local lift = flap * 9
    local alarm = clamp((e.noise or 0) / 3, 0, 1)
    local diving=e.luredToChime~=nil

    if diving then
        -- Committed resonance tunnel: repeated silhouettes point unambiguously
        -- towards the bell and explain why ordinary rock no longer diverts it.
        for i=5,1,-1 do
            love.graphics.setColor(.82,.35,.7,.035*i)
            love.graphics.ellipse("line",cx-(e.vx or 0)*.016*i,cy-(e.vy or 0)*.016*i,13+i*3,8+i)
        end
        rune(cx,cy,19+math.sin(e.phase*11)*3,-e.phase*1.4,{1,.48,.82},.45)
    end

    if e.awake then
        for i = 1, 3 do
            local trail = i * 8
            love.graphics.setColor(.42, .18, .38, .07 / i)
            love.graphics.polygon("fill", cx-(e.vx or 0)*.018*i,cy-(e.vy or 0)*.018*i,
                cx-spread-trail,cy+lift, cx-spread*.45,cy+9)
        end
    end

    love.graphics.setColor(.16 + alarm*.16+(diving and .12 or 0), .07, .15 + alarm*.08)
    love.graphics.ellipse("fill", cx, cy, 13, 10)
    love.graphics.setColor(.29, .11, .27)
    love.graphics.polygon("fill", cx-5,cy-3, cx-spread,cy-8-lift, cx-spread*.68,cy+8, cx-7,cy+5)
    love.graphics.polygon("fill", cx+5,cy-3, cx+spread,cy-8-lift, cx+spread*.68,cy+8, cx+7,cy+5)
    -- Finger-like wing bones and torn membrane slots make each beat readable.
    love.graphics.setColor(.48,.2,.43,.72)
    love.graphics.setLineWidth(1.4)
    for side=-1,1,2 do
        for finger=1,3 do
            local rootX=cx+side*5
            local tipX=cx+side*(spread*(.48+finger*.17))
            local tipY=cy-lift*(.35+finger*.18)-7+finger*5
            love.graphics.line(rootX,cy-2,tipX,tipY)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(.62, .29, .53, .65)
    love.graphics.line(cx-7,cy, cx-spread,cy-8-lift, cx-spread*.68,cy+8)
    love.graphics.line(cx+7,cy, cx+spread,cy-8-lift, cx+spread*.68,cy+8)

    -- It has no eyes: the white crescent is a vibrating mouth membrane.
    love.graphics.setColor(.06, .035, .06)
    love.graphics.polygon("fill", cx-8,cy-9, cx-4,cy-18, cx,cy-9)
    love.graphics.polygon("fill", cx+8,cy-9, cx+4,cy-18, cx,cy-9)
    love.graphics.setColor(.37,.14,.31)
    love.graphics.line(cx-3,cy+7,cx,cy+15,cx+3,cy+7)
    love.graphics.setColor(.84, .55, .72, e.awake and .9 or .42)
    love.graphics.arc("line", "open", cx, cy+1, 7, .12, math.pi-.12)
    if e.variant==2 then
        love.graphics.setColor(.58,.25,.48,.7); love.graphics.line(cx-spread*.62,cy-1,cx-spread*.78,cy+6)
    elseif e.variant==3 then
        love.graphics.setColor(.7,.34,.58,.65); love.graphics.circle("line",cx+9,cy-1,4)
    end
    if alarm>.35 then
        love.graphics.setColor(1,.68,.82,.45+alarm*.4)
        for tooth=-1,1,2 do love.graphics.polygon("fill",cx+tooth*3,cy+2,cx+tooth*1.6,cy+6,cx+tooth*5,cy+3) end
    end

    if e.awake then
        for i=1,2 do
            local radius=15+((e.phase*55+i*22)%55)
            love.graphics.setColor(.75,.32,.62,clamp(1-radius/74,0,.25))
            love.graphics.circle("line",cx,cy,radius)
        end
    end
end

local function drawMood(e)
    if e.dead or e.boundPlate or e.sealed then return end
    local cx,cy=e.x+e.w/2,e.y+e.h/2
    local t=e.moodTime or 0
    if e.mood=="searching" then
        love.graphics.setColor(.72,.64,.5,.12)
        for i=1,3 do
            local a=t*.9+i*2.1
            love.graphics.arc("line","open",cx,cy,21+i*9,a,a+.7)
        end
    elseif e.mood=="alert" then
        local pulse=.18+.14*math.abs(math.sin(t*10))
        love.graphics.setColor(1,.44,.2,pulse)
        love.graphics.circle("line",cx,cy,math.max(e.w,e.h)*.7+math.sin(t*12)*3)
    elseif e.mood=="curious" then
        love.graphics.setColor(.58,.74,.68,.09)
        love.graphics.ellipse("line",cx,cy,e.w*.72+math.sin(t*4)*2,e.h*.72)
    end
end

function EnemyRender.draw(e)
    drawMood(e)
    if e.kind=="blind" and e.sealed then drawSealedListener(e); return end
    if e.kind=="astral" and e.astralDying then drawAstralDeparture(e); return end
    if e.dead then
        if e.kind=="custodian" then drawDefeatedCustodian(e); return end
        local alpha = clamp(1 - (e.deathTimer or 0) * .08, .22, 1)
        local t=e.deathTimer or 0
        local cx,cy=e.x+e.w/2,e.y+e.h/2
        love.graphics.setColor(e.kind == "astral" and {.28, .12, .4, alpha} or {.13, .08, .1, alpha})
        love.graphics.ellipse("fill", cx, e.y + e.h - 4, e.w / 2 + 8+t*2, 6-alpha*2)
        -- Incluso después de caer, cada criatura se desarma según su naturaleza:
        -- piedra, eco o escritura astral; nunca desaparece con un simple fade.
        for i=1,9 do
            local seed=i*2.17+(e.id or 1)*.73
            local rise=t*(8+i*1.8)
            local drift=math.sin(seed+t*.7)*(5+i*1.3)
            local moteAlpha=alpha*clamp(1-t*.045,0,1)
            if e.kind=="astral" then
                rune(cx+drift,cy-rise+i*2,3+i%3,-t*.5+seed,{.68,.36,1},moteAlpha*.55)
            elseif e.kind=="bat" or e.kind=="blind" then
                love.graphics.setColor(e.kind=="bat" and {.58,.2,.47,moteAlpha*.42} or {.2,.65,.46,moteAlpha*.4})
                love.graphics.circle("line",cx+drift,cy-rise+i*2,2+(i%3)+t*.4)
            else
                love.graphics.setColor(.42,.19,.13,moteAlpha*.45)
                love.graphics.rectangle("fill",cx+drift,cy-rise+i*2,2+i%3,2+i%2)
            end
        end
        return
    end
    if e.kind == "blind" then drawListener(e)
    elseif e.kind == "astral" then drawAstral(e)
    elseif e.kind == "bat" then drawResonant(e)
    elseif e.boundPlate then drawTrappedCustodian(e)
    else drawCustodian(e) end
end

return EnemyRender
