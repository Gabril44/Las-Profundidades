local Bestiary={}
local Journal=require('render.journal')
local utf8=require('utf8')

local ORDER={"custodian","bat","blind","astral"}
local DATA={
    custodian={name="EL CUSTODIO",first="Una masa que aprendió a esperar.",behavior="Antes del estruendo, el suelo contiene el aliento.",resolved="Todo peso termina encontrando una forma."},
    bat={name="EL RESONANTE",first="El techo respira aun cuando nada se mueve.",behavior="Hay sonidos que no buscan oídos.",resolved="Dos voces opuestas pueden cerrar un mismo eco."},
    blind={name="EL OYENTE",first="Aquello que no ve jamás deja de escuchar.",behavior="Sus patas recuerdan el lugar donde murió el ruido.",resolved="Hasta el hambre puede dormirse dentro de un signo."},
    astral={name="EL VIGÍA ASTRAL",first="Una mirada llegada desde detrás del mundo.",behavior="Su cercanía persuade a lo imposible.",resolved="La luz que lo sostuvo también supo despedirlo."}
}

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end

function Bestiary.create(saved)
    local book={entries={},selected=1,notice=0,noticeKind=nil}
    for _,kind in ipairs(ORDER) do book.entries[kind]={stage=saved and saved[kind] or 0,witness=0} end
    return book
end

local function signature(e)
    if e.kind=="custodian" then return e.charging or (e.windup or 0)>0 end
    if e.kind=="bat" then return e.luredToChime~=nil or ((e.noise or 0)>2.3 and e.awake) end
    if e.kind=="blind" then return e.listenerLeap~=nil or (e.soundTimer or 0)>1 end
    return e.astralPhasing or (e.astralDash or 0)>0 or (e.astralWindup or 0)>0
end

local function resolved(e)
    return e.dead or e.boundPlate~=nil or e.sealed or e.astralDying
end

function Bestiary.update(book,enemies,player,regionForRow,tile,dt)
    if not book or not player then return nil end
    book.notice=math.max(0,(book.notice or 0)-dt)
    local changed
    for _,e in ipairs(enemies or {}) do
        local entry=book.entries[e.kind]
        if entry then
            local er=regionForRow(math.floor((e.homeY or e.y)/tile)+1)
            local pr=regionForRow(math.floor(player.y/tile)+1)
            local dx=(e.x+e.w/2)-(player.x+player.w/2)
            local dy=(e.y+e.h/2)-(player.y+player.h/2)
            local visible=er==pr and dx*dx+dy*dy<520*520
            if visible and entry.stage<1 then entry.stage=1; entry.fresh=true; entry.revealAt=nil; changed=e.kind end
            if visible and signature(e) then
                entry.witness=(entry.witness or 0)+dt
                if entry.stage<2 and entry.witness>.42 then entry.stage=2; entry.fresh=true; entry.revealAt=nil; changed=e.kind end
            end
            if resolved(e) and entry.stage<3 then entry.stage=3; entry.fresh=true; entry.revealAt=nil; changed=e.kind end
        end
    end
    if changed then book.notice=3.4; book.noticeKind=changed end
    return changed
end

function Bestiary.move(book,direction)
    book.selected=((book.selected-1+direction)%#ORDER)+1
end

function Bestiary.stages(book)
    local out={}
    for _,kind in ipairs(ORDER) do out[#out+1]=book.entries[kind].stage end
    return out
end

local function drawUnknown(cx,cy,t,font)
    love.graphics.setColor(.22,.18,.2,.6)
    for i=1,7 do
        local a=i*2.1
        love.graphics.circle("line",cx+math.sin(a)*70,cy+math.cos(a*.7)*90,8+i%3)
    end
    love.graphics.setFont(font); love.graphics.printf("?",cx-35,cy-14,70,"center")
end

local function drawCreature(kind,cx,cy,stage,t,ink)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(ink[1],ink[2],ink[3],.88)
    if kind=="custodian" then
        love.graphics.ellipse("line",cx,cy,96,62)
        love.graphics.polygon("line",cx-82,cy-26,cx-56,cy-72,cx-31,cy-30)
        love.graphics.polygon("line",cx+82,cy-26,cx+56,cy-72,cx+31,cy-30)
        if stage>=2 then love.graphics.line(cx-155,cy+73,cx+155,cy+73); love.graphics.line(cx-126,cy+62,cx-162,cy+82) end
    elseif kind=="bat" then
        local flap=math.sin(t*4)*13
        love.graphics.ellipse("line",cx,cy,39,27)
        love.graphics.polygon("line",cx-28,cy,cx-145,cy-70-flap,cx-102,cy+43,cx-34,cy+18)
        love.graphics.polygon("line",cx+28,cy,cx+145,cy-70-flap,cx+102,cy+43,cx+34,cy+18)
        if stage>=2 then for r=70,150,32 do love.graphics.arc("line","open",cx,cy,r,.15,math.pi-.15) end end
    elseif kind=="blind" then
        love.graphics.ellipse("line",cx,cy,112,47)
        for i=-4,4 do love.graphics.line(cx+i*22,cy+33,cx+i*25+math.sin(t*3+i)*8,cy+94) end
        if stage>=2 then for r=65,145,28 do love.graphics.circle("line",cx,cy-10,r) end end
    else
        love.graphics.polygon("line",cx,cy-108,cx+92,cy,cx+42,cy+106,cx-42,cy+106,cx-92,cy)
        love.graphics.ellipse("line",cx,cy-8,40,15)
        if stage>=2 then love.graphics.circle("line",cx,cy,155+math.sin(t)*5); love.graphics.circle("line",cx,cy,183) end
    end
    love.graphics.setLineWidth(1)
end

function Bestiary.draw(book,W,H,font,smallFont,usingGamepad,region)
    region=region or 1
    local kind=ORDER[book.selected]
    local entry=book.entries[kind]
    local data=DATA[kind]
    local t=love.timer.getTime()
    if entry.fresh and not entry.revealAt then entry.revealAt=t end
    local revealProgress=entry.fresh and clamp((t-(entry.revealAt or t))/3.2,0,1) or 1
    if revealProgress>=1 then entry.fresh=false end
    local theme=Journal.paper(W,H,region,t)
    local ink=theme[2]
    love.graphics.setFont(smallFont); love.graphics.setColor(ink)
    love.graphics.print(string.format("CUADERNO DE CAMPO   %d / %d",book.selected,#ORDER),112,88)
    if entry.stage==0 then
        drawUnknown(350,350,t,font)
        love.graphics.setFont(font); love.graphics.printf("PÁGINA SIN NOMBRE",120,520,460,"center")
        love.graphics.setFont(smallFont); love.graphics.printf("La mina todavía no dejó una forma en el papel.",140,561,420,"center")
    else
        drawCreature(kind,350,335,entry.stage,t,ink)
        love.graphics.setColor(ink)
        love.graphics.setFont(font); love.graphics.printf(data.name,120,514,460,"center")
        -- Sin contador: una libreta real no anuncia cuántas observaciones le
        -- faltan. El dibujo simplemente gana detalles cuando el explorador
        -- comprende algo nuevo.
    end
    love.graphics.setColor(ink)
    love.graphics.setFont(font); love.graphics.printf(entry.stage>0 and data.name or "SIN REGISTRO",710,110,420,"left")
    love.graphics.setFont(smallFont)
    local lines={data.first,data.behavior,data.resolved}
    local noteY={184,302,438}
    for i=1,entry.stage do
        local y=noteY[i]
        local tilt=math.sin(i*3.7)*3
        local writing=(i==entry.stage and entry.fresh) and revealProgress or 1
        love.graphics.setColor(ink[1],ink[2],ink[3],.94)
        -- Una pequeña raya irregular funciona como comienzo de apunte; no es
        -- un casillero, nivel ni indicador de progreso.
        love.graphics.setLineWidth(2)
        love.graphics.line(724,y+9+tilt,739,y+6,746,y+10)
        love.graphics.setLineWidth(1)
        local _,wrapped=smallFont:getWrap(lines[i],342)
        local count=0
        for _,line in ipairs(wrapped) do count=count+utf8.len(line) end
        local remaining=math.floor(count*writing)
        local pencilX,pencilY=758,y
        for row,line in ipairs(wrapped) do
            local n=math.min(remaining,utf8.len(line))
            local ending=utf8.offset(line,n+1) or (#line+1)
            local portion=line:sub(1,ending-1)
            local rowY=y+(row-1)*smallFont:getHeight()*smallFont:getLineHeight()
            if remaining>0 then
                love.graphics.print(portion,758,rowY)
                pencilX,pencilY=758+smallFont:getWidth(portion),rowY+smallFont:getHeight()*.8
            end
            remaining=math.max(0,remaining-n)
        end
        love.graphics.setColor(.31,.22,.19,.16)
        love.graphics.line(758,y+55,1000+math.sin(i)*42,y+53+tilt)
        if writing<1 and writing>.02 then
            Journal.pencil(pencilX,pencilY,t,region,.9)
        end
    end
    -- El papel que todavía no fue usado queda realmente vacío. Sólo conserva
    -- roces y manchas muy leves, sin frases fantasma que revelen el sistema.
    for i=entry.stage+1,3 do
        local y=noteY[i]
        love.graphics.setColor(.29,.22,.18,.035)
        love.graphics.line(730,y+18,790+i*31,y+16+math.sin(i)*4)
        love.graphics.circle("fill",820+i*47,y+31,1.5+i*.35)
    end
    love.graphics.setColor(.75,.69,.8)
    love.graphics.printf(usingGamepad and "LB / RB  VOLVER AL MAPA     CRUCETA  HOJEAR     B  CERRAR" or "Q / E  VOLVER AL MAPA     A / D  HOJEAR     TAB / ESC  CERRAR",0,661,W,"center")
end

function Bestiary.order() return ORDER end
function Bestiary.data() return DATA end

return Bestiary
