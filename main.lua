local game = {}
local Audio = require("systems.audio")
local Input = require("systems.input")
local Configuration = require("systems.configuration")
local ConfigurationRender = require("render.configuration")
local Save = require("game.save")
local Settings = require("game.settings")
local World = require("game.world")
local Rope = require("render.rope")
local Lighting = require("render.lighting")
local Atmosphere = require("render.atmosphere")
local MineDetail = require("render.mine_detail")
local ClueDetails = require("render.clue_details")
local Credits = require("render.credits")
local Camera = require("systems.camera")
local Particles = require("systems.particles")
local Content = require("game.content")
local Player = require("game.player")
local Enemies = require("systems.enemies")
local EnemyRender = require("render.enemies")
local PlayerRender = require("render.player")
local PlayerAnimation = require("systems.player_animation")
local Puzzles = require("systems.puzzles")
local Bestiary = require("systems.bestiary")
local Journal = require("render.journal")

local DESIGN_W, DESIGN_H = 1280, 720
local TILE = 48
local GRAVITY = 1450

local MAP_W, MAP_H = World.width, World.height
local map = World.build()
local REGION_NAMES, DEBUG_SPAWNS = World.regionNames, World.debugSpawns
local REGION_COUNT = #REGION_NAMES
local regionForRow = World.regionForRow

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function sign(v) return v < 0 and -1 or 1 end
local function dist(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function tileAt(tx, ty)
    if ty < 1 or ty > #map or tx < 1 or tx > #map[1] then return "#" end
    return map[ty]:sub(tx, tx)
end

local function solidTile(c, tx, ty)
    return c == "#" or c == "B" or c == "X" or c == "R" or c == "W" or
        (c == "H" and game.hookLevel and game.hookLevel >= 4) or
        (game.puzzles and Puzzles.solid(game.puzzles,c,game.player,tx,ty,TILE))
end

local function rectHitsSolid(x, y, w, h)
    local x1, x2 = math.floor(x / TILE) + 1, math.floor((x + w - 1) / TILE) + 1
    local y1, y2 = math.floor(y / TILE) + 1, math.floor((y + h - 1) / TILE) + 1
    for ty = y1, y2 do
        for tx = x1, x2 do
            if solidTile(tileAt(tx, ty), tx, ty) then return true, tx, ty end
        end
    end
    return false
end

local function setTile(tx, ty, value)
    local row = map[ty]
    map[ty] = row:sub(1, tx - 1) .. value .. row:sub(tx + 1)
end

local function makeDust(count)
    local dust = {}
    for i = 1, count do
        dust[i] = {
            x = math.random() * #map[1] * TILE,
            y = math.random() * #map * TILE,
            speed = 5 + math.random() * 12,
            phase = math.random() * math.pi * 2,
            size = math.random() < .15 and 2 or 1
        }
    end
    return dust
end

local function findChar(char)
    for y, row in ipairs(map) do
        local x = row:find(char, 1, true)
        if x then return (x - 1) * TILE, (y - 1) * TILE end
    end
end

local function findChars(char)
    local result = {}
    for y, row in ipairs(map) do
        for x = 1, #row do
            if row:sub(x, x) == char then
                result[#result + 1] = {x = (x - 1) * TILE, y = (y - 1) * TILE}
            end
        end
    end
    return result
end

local function nearestMarker(char, x, y, wantedRegion)
    local best, bestDistance
    for _, marker in ipairs(findChars(char)) do
        local markerRegion = regionForRow(math.floor(marker.y / TILE) + 1)
        local d = dist(x, y, marker.x + TILE / 2, marker.y + TILE / 2)
        if (not wantedRegion or markerRegion == wantedRegion) and (not bestDistance or d < bestDistance) then
            best, bestDistance = marker, d
        end
    end
    return best, bestDistance
end

local function allThreatsDefeated()
    for _,enemy in ipairs(game.enemies or {}) do
        local region=regionForRow(math.floor((enemy.homeY or enemy.y)/TILE)+1)
        local boundToCounterweight=region==2 and enemy.kind=="custodian" and game.puzzles and game.puzzles.counterweightSolved
        if not enemy.dead and not boundToCounterweight then return false end
    end
    return true
end

local function threatProgress()
    local resolved,total=0,0
    for _,enemy in ipairs(game.enemies or {}) do
        total=total+1
        local region=regionForRow(math.floor((enemy.homeY or enemy.y)/TILE)+1)
        local bound=region==2 and enemy.kind=="custodian" and game.puzzles and game.puzzles.counterweightSolved
        if enemy.dead or bound then resolved=resolved+1 end
    end
    return resolved,total
end

local function regionThreatsDefeated(region)
    for _, enemy in ipairs(game.enemies or {}) do
        local enemyRegion = regionForRow(math.floor(enemy.y / TILE) + 1)
        if enemyRegion == region and not enemy.dead then return false end
    end
    return true
end

local function enemyKindAlive(kind, region)
    for _, enemy in ipairs(game.enemies or {}) do
        if enemy.kind == kind and not enemy.dead and (not region or regionForRow(math.floor(enemy.y/TILE)+1)==region) then return true end
    end
    return false
end

-- Los sonidos corporales de los monstruos no son una banda sonora global.
-- Sólo existen para el jugador cuando comparte su estrato y está lo bastante
-- cerca. Los golpes, destellos y otras reacciones explícitas se reproducen por
-- sus propios eventos y no pasan por este filtro.
local function enemyAudible(e, radius)
    local p = game.player
    if not p then return false end
    local playerRegion = regionForRow(math.floor((p.y + p.h * .5) / TILE) + 1)
    local enemyRegion = regionForRow(math.floor(((e.homeY or e.y) + e.h * .5) / TILE) + 1)
    if playerRegion ~= enemyRegion then return false end
    return dist(p.x + p.w * .5, p.y + p.h * .5,
        e.x + e.w * .5, e.y + e.h * .5) <= (radius or 480)
end

local function resetPlayer(x, y)
    game.player = Player.create(x,y,TILE)
end

local function saveCheckpoint()
    local p = game.player
    game.checkpoint = {x = p.x, y = p.y}
    if game.clues and game.enemies then Save.write(game) end
end

local function loadCheckpoint()
    local x, y = 3 * TILE, 2 * TILE
    if game.checkpoint then x, y = game.checkpoint.x, game.checkpoint.y end
    resetPlayer(x, y)
    -- Guardados viejos o cambios de geometría nunca deben reaparecer dentro de
    -- una raíz, una pared dinámica o en contacto inevitable con una criatura.
    local attempts=0
    while rectHitsSolid(game.player.x,game.player.y,game.player.w,game.player.h) and attempts<10 do
        game.player.y=game.player.y-TILE
        attempts=attempts+1
    end
    game.player.invuln=1.35
end

local function addMessage(text, seconds)
    game.message = text
    game.messageTimer = seconds or 4
end

local function playSound(name, jitter)
    Audio.play(game.sounds, name, jitter)
end

local function spawnFX(x, y, count, color, forceX, forceY)
    Particles.spawn(game.fx, x, y, count, color, forceX, forceY)
end

local function anchors()
    local result = {}
    for ty, row in ipairs(map) do
        for tx = 1, #row do
            local marker = row:sub(tx, tx)
            if marker == "A" or marker == "V" then
                result[#result + 1] = {x = (tx - .5) * TILE, y = (ty - .5) * TILE, runic = marker == "V"}
            end
        end
    end
    return result
end

local function mouseWorld()
    local sw, sh = love.graphics.getDimensions()
    local scale = math.min(sw / DESIGN_W, sh / DESIGN_H)
    local ox, oy = (sw - DESIGN_W * scale) / 2, (sh - DESIGN_H * scale) / 2
    local mx, my = love.mouse.getPosition()
    return (mx - ox) / scale + game.camera.x, (my - oy) / scale + game.camera.y
end

local function nearestAnchor(px, py, maxRange, excludeX, excludeY)
    local best, bestD, bestScore
    for _, a in ipairs(game.anchors) do
        local d = dist(px, py, a.x, a.y)
        local excluded = excludeX and dist(a.x, a.y, excludeX, excludeY) < 4
        -- Al ascender, un agarre situado debajo recibe una penalización para
        -- que E prefiera naturalmente el siguiente punto de la cadena.
        local score = d + (a.y > py + 24 and 120 or 0)
        local available = not a.runic or (game.hookLevel or 1) >= 3
        if available and not excluded and d <= maxRange and (not bestScore or score < bestScore) then
            best, bestD, bestScore = a, d, score
        end
    end
    return best, bestD
end

local function aimedAnchor()
    local p = game.player
    local px, py = p.x + p.w / 2, p.y + p.h / 2
    if p.chainAssistTimer > 0 and p.chainTarget and
       dist(px, py, p.chainTarget.x, p.chainTarget.y) <= 520 then
        return p.chainTarget
    end
    local excludeX = p.hookCooldown > 0 and p.lastHookX or nil
    local excludeY = p.hookCooldown > 0 and p.lastHookY or nil
    if Input.usingAimStick() then
        local best, bestScore
        local aimLength = math.sqrt(Input.aimX * Input.aimX + Input.aimY * Input.aimY)
        for _, a in ipairs(game.anchors) do
            local dx, dy = a.x - px, a.y - py
            local range = math.max(1, math.sqrt(dx * dx + dy * dy))
            local available = not a.runic or (game.hookLevel or 1) >= 3
            local alignment = (dx / range) * (Input.aimX / aimLength) + (dy / range) * (Input.aimY / aimLength)
            if available and range <= (game.hookLevel >= 2 and 550 or 500) * game.settings.hookAssist and alignment > .45 then
                local score = range - alignment * 220
                if not bestScore or score < bestScore then best, bestScore = a, score end
            end
        end
        if best then return best end
    end
    -- Soltar el stick no significa cambiar de intención. Conservamos el último
    -- aro elegido con joystick mientras siga siendo válido y alcanzable.
    if Input.usingGamepad() and game.selectedAnchor then
        local a = game.selectedAnchor
        local range = dist(px, py, a.x, a.y)
        local excluded = excludeX and dist(a.x, a.y, excludeX, excludeY) < 4
        local available = not a.runic or (game.hookLevel or 1) >= 3
        local maxRange = (game.hookLevel and game.hookLevel >= 2 and 550 or 500) * game.settings.hookAssist
        if available and not excluded and range <= maxRange then return a end
    end
    -- El cursor sólo participa mientras teclado/mouse sea el dispositivo
    -- activo. Así un cursor quieto no roba el anclaje al jugar con joystick.
    if game.mouseUsed and not Input.usingGamepad() then
        local mx, my = mouseWorld()
        local best, bestScore
        for _, a in ipairs(game.anchors) do
            local range = dist(px, py, a.x, a.y)
            local excluded = excludeX and dist(a.x, a.y, excludeX, excludeY) < 4
            local available = not a.runic or (game.hookLevel or 1) >= 3
            if available and not excluded and range <= (game.hookLevel and game.hookLevel >= 2 and 550 or 500) * game.settings.hookAssist then
                local cursorDistance = dist(mx, my, a.x, a.y)
                local score = cursorDistance + range * .08
                if cursorDistance < 210 and (not bestScore or score < bestScore) then
                    best, bestScore = a, score
                end
            end
        end
        if best then return best end
    end
    return nearestAnchor(px, py, (game.hookLevel and game.hookLevel >= 2 and 520 or 470) * game.settings.hookAssist, excludeX, excludeY)
end

local function nextChainAnchor(px, py, oldX, oldY)
    local best, bestScore
    for _, a in ipairs(game.anchors) do
        local d = dist(px, py, a.x, a.y)
        local old = dist(a.x, a.y, oldX, oldY) < 4
        local available = not a.runic or (game.hookLevel or 1) >= 3
        if available and not old and d <= (game.hookLevel and game.hookLevel >= 2 and 570 or 520) * game.settings.hookAssist and a.y < py + 24 then
            -- Favorece altura y continuidad horizontal, sin exigir que el
            -- cursor ya esté exactamente sobre el siguiente aro.
            local heightGain = py - a.y
            local score = d + math.abs(a.x - px) * .12 - heightGain * .35
            if not bestScore or score < bestScore then best, bestScore = a, score end
        end
    end
    return best
end

local function tryHook()
    local p = game.player
    if p.hook then
        p.hook = nil; p.releaseTimer = .24
        PlayerAnimation.trigger(p, "release", .24, 1)
        Particles.emit(game.fx, {x=p.x+p.w/2,y=p.y+p.h/2,count=7,color={.72,.58,.32},speed=90,kind="spark",gravity=90,life=.3})
        playSound("release")
        return true
    end
    local cx, cy = p.x + p.w / 2, p.y + p.h / 2
    local a = game.selectedAnchor or aimedAnchor()
    local d = a and dist(cx, cy, a.x, a.y) or nil
    if a then
        local aimX, aimY = (a.x - cx) / math.max(1, d), (a.y - cy) / math.max(1, d)
        p.hook = {
            x=a.x,y=a.y,length=math.max(82,d),deploying=true,
            shotTime=0,shotDuration=clamp(d/1150,.11,.38),
            originX=cx+p.facing*7,originY=cy-3
        }
        p.chainTarget, p.chainAssistTimer, p.hookBuffer = nil, 0, 0
        p.hookKick = .48
        PlayerAnimation.trigger(p, "hook", p.hook.shotDuration, 1)
        p.hookAimX, p.hookAimY = aimX, aimY
        p.vx = p.vx - aimX * 18
        p.vy = p.vy - aimY * 9
        playSound("hook")
        Particles.emit(game.fx, {x=cx+p.facing*8,y=cy-3,count=6,color={1,.72,.25},speed=125,angle=math.atan2(aimY,aimX),spread=.65,kind="spark",gravity=70,life=.28})
        return true
    else
        return false
    end
end

local function jumpFromHook()
    local p = game.player
    if not p.hook then return false end
    if p.hook.deploying then return true end
    local oldHookX, oldHookY = p.hook.x, p.hook.y
    local cx, cy = p.x + p.w / 2, p.y + p.h / 2
    local nextAnchor = nextChainAnchor(cx, cy, oldHookX, oldHookY)
    p.lastHookX, p.lastHookY = p.hook.x, p.hook.y
    p.hook = nil
    p.releaseTimer = .24
    PlayerAnimation.trigger(p, "release", .24, 1.25)
    p.hookCooldown = .55
    p.chainTarget = nextAnchor
    p.chainAssistTimer = nextAnchor and .9 or 0
    game.selectedAnchor = nextAnchor
    if nextAnchor and nextAnchor.y < cy + 40 then
        local dx, dy = nextAnchor.x - cx, nextAnchor.y - cy
        local length = math.max(1, math.sqrt(dx * dx + dy * dy))
        p.vx = clamp(p.vx * .7 + dx / length * 315, -480, 480)
        p.vy = math.min(p.vy - 315 + dy / length * 75, -475)
        p.facing = dx < 0 and -1 or 1
    else
        p.vx = clamp(p.vx + p.facing * 175, -450, 450)
        p.vy = math.min(p.vy - 315, -455)
    end
    playSound("release")
    Particles.emit(game.fx, {x=cx,y=cy,count=10,color={.86,.67,.32},speed=145,angle=math.pi/2,spread=1.9,kind="spark",gravity=120,life=.34})
    p.jumpBuffer = 0
    if not game.taughtHookJump then
        game.taughtHookJump = true
        addMessage("Impulso de gancho — En el aire, usá E para agarrar el siguiente anclaje.", 4)
    end
    return true
end

local function nearFinalDoor()
    local lx, ly = findChar("L")
    if not lx then return false end
    local p = game.player
    return dist(p.x + p.w / 2, p.y + p.h / 2, lx + TILE / 2, ly + TILE / 2) < 82
end

local function tryFinalDoor()
    if not nearFinalDoor() then return false end
    if not allThreatsDefeated() then
        addMessage("La puerta no reconoce tu descenso. Algo todavía permanece libre detrás tuyo.", 4)
    else
        game.won = true
        game.winTimer = 0
        game.winCue = 0
        game.winStartX = game.player.x
        playSound("doorOpen")
        playSound("deepRumble", .006)
        saveCheckpoint()
    end
    return true
end

local function pickDirection(p)
    if Input.usingAimStick() then
        local length = math.max(.001, math.sqrt(Input.aimX^2 + Input.aimY^2))
        return Input.aimX / length, Input.aimY / length
    end
    if game.mouseUsed and not Input.usingGamepad() then
        local mx, my = mouseWorld()
        local dx, dy = mx - (p.x + p.w / 2), my - (p.y + p.h / 2)
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 5 then return dx / length, dy / length end
    end
    return p.facing, 0
end

local function chimeAtTile(tx, ty)
    for index, chime in ipairs(game.chimes or {}) do
        if math.floor(chime.x / TILE) + 1 == tx and math.floor(chime.y / TILE) + 1 == ty then return chime, index end
    end
end

local function breakWall()
    local p = game.player
    if p.pickTimer > 0 then return end
    local aimX, aimY = pickDirection(p)
    p.pickAimX, p.pickAimY = aimX, aimY
    if math.abs(aimX) > .15 then p.facing = aimX < 0 and -1 or 1 end
    p.pickTimer = .32
    PlayerAnimation.trigger(p, "pick", .32, 1)
    playSound("pick")
    local cx, cy = p.x + p.w / 2, p.y + p.h * .55
    local impactX, impactY, tx, ty, hitKind = cx + aimX * 62, cy + aimY * 62
    for reach = 20, 70, 5 do
        local px, py = cx + aimX * reach, cy + aimY * reach
        local probeX, probeY = math.floor(px / TILE) + 1, math.floor(py / TILE) + 1
        local probeKind = tileAt(probeX, probeY)
        local probeChime = probeKind == "T" and chimeAtTile(probeX, probeY) or nil
        if solidTile(probeKind, probeX, probeY) or (probeChime and not probeChime.broken) then
            impactX, impactY, tx, ty, hitKind = px, py, probeX, probeY, tileAt(probeX, probeY)
            break
        end
    end

    Particles.emit(game.fx, {x=impactX,y=impactY,count=hitKind and 12 or 5,color=hitKind=="B" and {.82,.58,.3} or {.9,.66,.28},
        speed=hitKind and 185 or 85,angle=math.atan2(-aimY,-aimX),spread=.9,kind="spark",gravity=300,life=.32})
    if game.puzzles then Puzzles.noise(game.puzzles,impactX,impactY,hitKind and 1.5 or .7,game.currentRegion,playSound,addMessage) end

    -- El pico produce un punto sonoro en el mundo. El Oyente persigue ese
    -- lugar, no al jugador: así la herramienta resuelve encuentros sin daño.
    for _, enemy in ipairs(game.enemies) do
        local playerRegion = regionForRow(math.floor(game.player.y/TILE)+1)
        local enemyHomeRegion = regionForRow(math.floor((enemy.homeY or enemy.y)/TILE)+1)
        if not enemy.dead and enemy.kind == "bat" and playerRegion >= enemyHomeRegion and dist(enemy.x, enemy.y, impactX, impactY) < 760 then
            enemy.noise = math.min(5, (enemy.noise or 0) + (hitKind and 1.65 or .8))
            if not enemy.luredToChime then
                enemy.soundTargetX, enemy.soundTargetY = impactX, impactY
                if enemy.noise >= 2.4 then
                    enemy.awake, enemy.soundTimer = true, 4.5
                    enemy.voiceTimer = math.min(enemy.voiceTimer or 0, .2)
                end
            end
        elseif not enemy.dead and enemy.kind == "blind" and dist(enemy.x, enemy.y, impactX, impactY) < 620 then
            enemy.soundTargetX, enemy.soundTargetY = impactX, impactY
            enemy.soundTimer, enemy.awake = 5.5, true
            enemy.voiceTimer = math.min(enemy.voiceTimer or 0, .25)
        elseif not enemy.dead and dist(enemy.x, enemy.y, impactX, impactY) < 280 then
            enemy.awake = true
        end
    end

    if hitKind == "T" then
        local chime, chimeIndex = chimeAtTile(tx, ty)
        if chime and not chime.broken then
            chime.ringing = 2.4
            playSound("mineralBell", .045)
            playSound("batRoar", .065)
            local chimeRegion=regionForRow(math.floor(chime.y/TILE)+1)
            local lured=false
            for _, enemy in ipairs(game.enemies) do
                local enemyRegion=regionForRow(math.floor((enemy.homeY or enemy.y)/TILE)+1)
                if enemy.kind == "bat" and not enemy.dead and enemyRegion==chimeRegion then
                    enemy.noise, enemy.awake = 4, true
                    enemy.soundTimer, enemy.luredToChime = 16, chimeIndex
                    enemy.soundTargetX, enemy.soundTargetY = chime.x + TILE/2, chime.y + TILE/2
                    enemy.lurePulse=1
                    lured=true
                end
            end
            if lured then
                addMessage("El eco eligió un rumbo.", 4)
            else
                addMessage("La campana responde, pero ningún Resonante vive en este estrato.", 4)
            end
        end
    elseif hitKind == "B" then
        setTile(tx, ty, ".")
        for _, brittle in ipairs(game.breakables or {}) do
            if brittle.x == (tx - 1) * TILE and brittle.y == (ty - 1) * TILE then brittle.broken = true end
        end
        game.shake, game.hitstop = .18, .035
        playSound("rockCrack", .08)
        for _ = 1, 8 do game.debris[#game.debris+1] = {x=impactX,y=impactY,vx=(math.random()-.5)*220,vy=-math.random()*170,life=.45+math.random()*.35} end
        addMessage("La veta hueca cede. Algo respiraba detrás.", 2.8)
        Save.write(game)
    elseif hitKind == "X" then
        p.pickFailTimer=.52
        addMessage("La veta no responde a tus manos.", 3)
    elseif hitKind then
        p.pickFailTimer=.42
        game.shake = .08
        addMessage("La piedra devuelve el golpe.", 1.4)
    elseif not game.taughtPickNoise then
        game.taughtPickNoise = true
        addMessage("El golpe viaja lejos por la mina. Algo podría oírlo.", 4)
    end
end

local function beginAstralDeparture(e)
    e.astralDying=true
    e.astralDeathTime=0
    e.astralDeathCue=0
    e.deathParticleTimer=0
    e.vx,e.vy,e.stun=0,0,0
    game.astralCinematic=e
    game.astralDefeatFlash=.18
    playSound("astralScream",.025)
    playSound("deepRumble",.008)
    addMessage("Los tres círculos pronuncian una misma ausencia.",4)
end

local function activateAstralSeal(e,contactRadius)
    if not e or e.dead or e.kind~="astral" then return false end
    local seal,sealDistance=nearestMarker("Z",e.x+e.w/2,e.y+e.h/2,6)
    if not seal or sealDistance>(contactRadius or 72) then return false end
    local sealKey=tostring(seal.x)..":"..tostring(seal.y)
    if e.usedSeals[sealKey] or e.usedSeals[seal.x] then return false end
    -- Conservamos también la clave X para partidas anteriores y para el dibujo
    -- de sellos, pero la clave completa evita ambigüedades si se reubican.
    e.usedSeals[sealKey],e.usedSeals[seal.x]=true,true
    e.impacts=(e.impacts or 0)+1
    e.stun=1.35
    game.hitstop=.065
    game.shake=.65
    playSound("impact")
    playSound("astralHurt",.08)
    spawnFX(e.x+e.w/2,e.y+e.h/2,18,{.72,.42,1},210,170)
    if e.impacts>=3 then
        -- El último sello no lo mata como a una criatura física: comienza su
        -- expulsión. Durante unos segundos conserva el aura y el mundo se llena
        -- de su luz antes de devolverlo al plano del que vino.
        beginAstralDeparture(e)
    else
        addMessage("Otro círculo recuerda su paso.",4)
    end
    return true
end

local function flashLantern()
    local p = game.player
    if p.light < 18 then
        addMessage("No queda batería suficiente para un destello.", 2.5)
        return
    end
    p.light = p.light - 18
    game.lightFlashPulse = 1
    game.lightSpent = 18
    p.flashTimer = .42
    PlayerAnimation.trigger(p, "flash", .42, 1)
    Particles.emit(game.fx, {x=p.x+p.w/2+p.facing*18,y=p.y+18,count=16,color={1,.88,.48},speed=165,spread=math.pi*2,kind="ring",gravity=-20,drag=.35,life=.38,size=2})
    playSound("flash")
    if game.puzzles then Puzzles.flash(game.puzzles,game.currentRegion) end
    local resonantProvoked = false
    for _, candidate in ipairs(game.enemies) do
        local playerRegion = regionForRow(math.floor(p.y/TILE)+1)
        local enemyHomeRegion = regionForRow(math.floor((candidate.homeY or candidate.y)/TILE)+1)
        if not candidate.dead and candidate.kind == "bat" and playerRegion >= enemyHomeRegion and dist(p.x,p.y,candidate.x,candidate.y) < 900 then
            -- The flash is a loud point source. Unlike a bell lure, this attack
            -- commits to the player's position at the instant of the burst.
            candidate.soundTargetX = p.x + p.w / 2
            candidate.soundTargetY = p.y + p.h / 2
            candidate.soundTimer = 5.2
            candidate.noise = 4
            candidate.awake = true
            candidate.luredToChime = nil
            candidate.flashCharge = 2.4
            candidate.voiceTimer = .08
            resonantProvoked = true
        end
    end
    local e, nearestDistance
    for _, candidate in ipairs(game.enemies) do
        local d = dist(p.x, p.y, candidate.x, candidate.y)
        -- El Resonante ya procesa el ruido del destello arriba. No debe ocupar
        -- también el único turno de reacción y silenciar a un Custodio cercano.
        if not candidate.dead and not candidate.boundPlate and candidate.kind~="bat" and d < 430 and (not nearestDistance or d < nearestDistance) then
            e, nearestDistance = candidate, d
        end
    end
    if e and e.kind=="custodian" and regionForRow(math.floor(e.y/TILE)+1)==2 and e.stun<=0 and not e.charging and e.windup<=0 then
        local preferredDirection=sign((p.x+p.w/2)-(e.x+e.w/2))
        local plate=Puzzles.targetPlate(game.puzzles,e,game.enemies,preferredDirection)
        if plate then
            e.counterTarget=plate
            e.counterPreferredDirection=preferredDirection
            local plateBelow=(plate.y+48)>(e.y+e.h+TILE)
            e.counterDropDirection=plateBelow and sign((plate.x+24)-(e.x+e.w/2)) or nil
            e.windup=.8
            e.targetX=e.counterDropDirection and (e.x+e.counterDropDirection*900) or plate.x+24
            e.awake=true
            playSound("alert")
            addMessage("Algo vacío reclama su peso.",4)
        end
    elseif e and e.kind=="custodian" and e.stun<=0 and not e.charging and e.windup<=0 then
        -- Fuera de la sala de contrapesos, la luz lo compromete con una carga
        -- completa. En la Cámara Resonante esto permite usarlo contra la veta X.
        e.windup=.8
        e.targetX=p.x+p.w/2
        e.awake=true
        playSound("alert")
        addMessage("La luz despierta aquello que no sabe detenerse.",3)
    elseif resonantProvoked then
        playSound("batRoar", .045)
        addMessage("La luz también tiene voz.", 4)
    elseif e and e.kind == "blind" then
        e.soundTargetX = p.x + p.w / 2
        e.soundTargetY = p.y
        e.soundTimer = 5
        e.awake = true
        playSound("alert")
        addMessage("Todo eco busca un lugar donde morir.", 4)
    elseif e and e.kind == "astral" then
        if not activateAstralSeal(e,92) then
            e.repulse = 1
            addMessage("La luz lo aparta. Los círculos no olvidan.", 3)
        end
    elseif e and e.stun <= 0 and not e.charging and e.windup <= 0 then
        e.windup = .8
        e.targetX = p.x + p.w / 2
        e.awake = true
        playSound("alert")
        addMessage("La luz despierta aquello que no sabe detenerse.", 3)
    else
        addMessage("El destello se pierde en la oscuridad.", 1.8)
    end
end

local function moveAxis(p, amount, axis)
    local steps = math.ceil(math.abs(amount) / 6)
    if steps == 0 then return end
    local delta = amount / steps
    for _ = 1, steps do
        local nx, ny = p.x, p.y
        if axis == "x" then nx = nx + delta else ny = ny + delta end
        if rectHitsSolid(nx, ny, p.w, p.h) then
            if axis == "x" then p.vx = 0 else
                if delta > 0 then p.grounded = true end
                p.vy = 0
            end
            return
        end
        p.x, p.y = nx, ny
    end
end

local function resolveOverlap(p)
    if not rectHitsSolid(p.x, p.y, p.w, p.h) then return false end
    -- Busca la salida libre más cercana. La prioridad vertical evita quedar
    -- incrustado en el techo al retraer el gancho bajo una plataforma.
    for offset = 1, TILE + p.h do
        local candidates = {
            {p.x, p.y + offset, "y"},
            {p.x, p.y - offset, "y"},
            {p.x - offset, p.y, "x"},
            {p.x + offset, p.y, "x"}
        }
        for _, c in ipairs(candidates) do
            if not rectHitsSolid(c[1], c[2], p.w, p.h) then
                p.x, p.y = c[1], c[2]
                if c[3] == "x" then p.vx = 0 else p.vy = 0 end
                p.hook = nil
                return true
            end
        end
    end
    return false
end

local function tryHookMantle(p)
    if not p.hook or p.hook.deploying or not Input.isDown("up") or p.hook.length > 112 then return false end
    local tx = math.floor(p.hook.x / TILE) + 1
    local ty = math.floor(p.hook.y / TILE) + 1
    if not solidTile(tileAt(tx, ty + 1), tx, ty + 1) then return false end
    local platformTop = ty * TILE
    local candidates = {
        {p.hook.x - p.w / 2, platformTop - p.h},
        {p.hook.x - TILE * .72 - p.w / 2, platformTop - p.h},
        {p.hook.x + TILE * .72 - p.w / 2, platformTop - p.h}
    }
    for _, spot in ipairs(candidates) do
        if not rectHitsSolid(spot[1], spot[2], p.w, p.h) then
            p.vx, p.vy = 0, 0
            p.grounded = false
            p.lastHookX, p.lastHookY = p.hook.x, p.hook.y
            p.hook = nil
            p.hookCooldown = .3
            p.mantle = {
                fromX = p.x, fromY = p.y,
                toX = spot[1], toY = spot[2],
                t = 0, duration = .34
            }
            PlayerAnimation.trigger(p, "mantle", .34, 1)
            Particles.emit(game.fx, {x=spot[1]+p.w/2,y=platformTop,count=7,color={.42,.36,.31},speed=80,angle=-math.pi/2,spread=1.4,kind="dust",gravity=160,life=.38})
            playSound("mantle")
            if not game.taughtMantle then
                game.taughtMantle = true
                addMessage("Subida asistida — Mantené W para trepar sobre la plataforma.", 4)
            end
            return true
        end
    end
    return false
end

local function damagePlayer(fromX, amount, astral)
    local p = game.player
    if p.invuln > 0 then return end
    p.hp = p.hp - (amount or 1)
    playSound("hurt")
    p.invuln = 1.2
    p.hurtTimer = .58
    p.bellyVX=(p.bellyVX or 0)-sign(p.x-fromX)*95
    p.packVelocity=(p.packVelocity or 0)+sign(p.x-fromX)*2.4
    p.helmetVelocity=(p.helmetVelocity or 0)-sign(p.x-fromX)*2
    p.vx = sign(p.x - fromX) * 310
    p.vy = -260
    game.shake = .5
    if game.settings.vibration and Input.joystick and Input.joystick:isGamepad() then
        pcall(function() Input.joystick:setVibration(.42,.7,.16) end)
    end
    if astral then
        p.astralEcho=1
        game.astralVision=1.05
        game.astralVisionSeed=math.random()*100
        playSound("deepRumble",.012)
    end
    if p.hp <= 0 then
        game.deaths = (game.deaths or 0) + 1
        loadCheckpoint()
        addMessage("La oscuridad te devuelve a la última fogata.", 4)
    end
end

local function hasFloorAhead(entity, direction, distance)
    if direction == 0 then return true end
    distance = distance or 7
    local probeX = direction > 0 and entity.x + entity.w + distance or entity.x - distance
    local probeY = entity.y + entity.h + 8
    local tx,ty=math.floor(probeX / TILE) + 1,math.floor(probeY / TILE) + 1
    return solidTile(tileAt(tx,ty),tx,ty)
end

local function edgeAwareness(entity,direction)
    -- Read the next tile well before the boot reaches the void. Four probes
    -- turn the old on/off pose into a gradual, anticipatory performance.
    if not entity.grounded or entity.hook then return 0 end
    local factor=0
    for _,probe in ipairs({30,22,14,7}) do
        if not hasFloorAhead(entity,direction,probe) then factor=factor+.25 end
    end
    return factor
end

local function presentEncounter(key, title, subtitle)
    if game.encounterSeen[key] then return end
    game.encounterSeen[key] = true
    game.encounterTitle = {title = title, subtitle = subtitle, timer = 3.4}
    game.shake = .18
    playSound("alert", .025)
    playSound("deepRumble", .012)
end

local function updatePlayer(dt)
    local p = game.player
    game.lightFlashPulse=math.max(0,(game.lightFlashPulse or 0)-dt*2.45)
    game.lightRechargePulse=math.max(0,(game.lightRechargePulse or 0)-dt*1.7)
    game.saveNotice=math.max(0,(game.saveNotice or 0)-dt)
    for _,refuge in ipairs(game.refuges or {}) do
        refuge.activationPulse=math.max(0,(refuge.activationPulse or 0)-dt*.72)
    end
    p.depth=game.currentRegion or 1
    local closestDanger,closestEnemy=9999,nil
    for _,enemy in ipairs(game.enemies or {}) do
        if not enemy.dead then
            local enemyDistance=dist(enemy.x,enemy.y,p.x,p.y)
            if enemyDistance<closestDanger then closestDanger,closestEnemy=enemyDistance,enemy end
        end
    end
    local dangerTarget=clamp((430-closestDanger)/310,0,1)
    p.danger=lerp(p.danger or 0,dangerTarget,1-math.pow(.025,dt))
    local focusX,focusY=0,0
    if game.selectedAnchor then
        focusX=clamp((game.selectedAnchor.x-(p.x+p.w/2))/180,-1,1)
        focusY=clamp((game.selectedAnchor.y-(p.y+p.h/2))/180,-1,1)
    elseif closestEnemy and closestDanger<430 then
        focusX=clamp((closestEnemy.x-p.x)/180,-1,1)
        focusY=clamp((closestEnemy.y-p.y)/180,-1,1)
    end
    p.lookX=lerp(p.lookX or 0,focusX,1-math.pow(.01,dt))
    p.lookY=lerp(p.lookY or 0,focusY,1-math.pow(.01,dt))
    PlayerAnimation.update(p, dt)
    -- La respiración permanece en la animación, pero no genera audio por
    -- temporizador. Todo sonido de gameplay debe tener una causa visible.
    p.breathTimer=0
    local wasGrounded = p.grounded
    p.invuln = math.max(0, p.invuln - dt)
    p.pickTimer = math.max(0, p.pickTimer - dt)
    p.flashTimer = math.max(0, p.flashTimer - dt)
    p.hookCooldown = math.max(0, p.hookCooldown - dt)
    p.chainAssistTimer = math.max(0, p.chainAssistTimer - dt)
    p.hookBuffer = math.max(0, p.hookBuffer - dt)
    p.stepTimer = math.max(0, p.stepTimer - dt)
    p.hookKick = math.max(0, p.hookKick - dt * 5.8)
    p.squash = lerp(p.squash, 0, 1 - math.pow(.00002, dt))
    p.turnTimer = math.max(0, p.turnTimer - dt)
    p.ropeSoundTimer = math.max(0, p.ropeSoundTimer - dt)
    p.lowLightTimer = math.max(0, p.lowLightTimer - dt)
    if p.chainAssistTimer <= 0 then p.chainTarget = nil end
    if p.mantle then
        local m = p.mantle
        m.t = math.min(1, m.t + dt / m.duration)
        local smooth = m.t * m.t * (3 - 2 * m.t)
        p.x = lerp(m.fromX, m.toX, smooth)
        p.y = lerp(m.fromY, m.toY, smooth) - math.sin(m.t * math.pi) * 18
        p.mantlePose = math.sin(m.t * math.pi)
        p.vx, p.vy = 0, 0
        if m.t >= 1 then
            p.x, p.y = m.toX, m.toY
            p.mantle, p.mantlePose = nil, 0
            p.grounded = true
        end
        return
    end
    p.jumpBuffer = math.max(0, p.jumpBuffer - dt)
    p.coyote = p.grounded and .11 or math.max(0, p.coyote - dt)

    local dir = game.astralCinematic and 0 or Input.moveX()
    if math.abs(dir) > .01 then
        game.hudActivated=true
        local facing = dir < 0 and -1 or 1
        if facing ~= p.facing and math.abs(p.vx) > 55 then
            p.turnTimer = .14
            playSound("cloth",.035)
            spawnFX(p.x + p.w / 2, p.y + p.h, 4, {.42, .35, .3}, 75, 35)
        end
        p.facing = facing
        local accel = p.grounded and 1500 or 800
        p.vx = p.vx + dir * accel * dt
    else
        p.vx = p.vx * math.pow(p.grounded and .0008 or .12, dt)
    end
    p.vx = clamp(p.vx, -260, 260)

    local walking = p.grounded and math.abs(p.vx) > 24
    local resting = p.grounded and not walking and not p.hook and not p.mantle
    p.idleTime = resting and p.idleTime + dt or 0
    local walkTarget = walking and 1 or 0
    p.walkBlend = lerp(p.walkBlend, walkTarget, 1 - math.pow(.0008, dt))
    if walking then p.walkCycle = p.walkCycle + math.abs(p.vx) * dt / 17 end

    p.grounded = false
    p.vy = p.vy + GRAVITY * dt

    if p.jumpBuffer > 0 and p.coyote > 0 then
        p.vy = -510
        p.bellyVY = (p.bellyVY or 0) + 105
        p.gearVY = (p.gearVY or 0) + 68
        p.beardVY = (p.beardVY or 0) + 42
        p.packVelocity=(p.packVelocity or 0)+p.facing*.8
        p.lampVelocity=(p.lampVelocity or 0)-p.facing*1.1
        playSound("jump")
        p.squash = -.12
        PlayerAnimation.trigger(p, "jump", .22, 1)
        spawnFX(p.x + p.w / 2, p.y + p.h, 6, {.42, .35, .3}, 100, 55)
        Particles.emit(game.fx, {x=p.x+p.w/2,y=p.y+p.h,count=9,color={.4,.34,.29},speed=105,angle=math.pi/2,spread=1.15,kind="dust",gravity=80,life=.42,size=3})
        p.jumpBuffer, p.coyote = 0, 0
        p.hook = nil
    end

    if p.hook and p.hook.deploying then
        local shot=p.hook
        shot.shotTime=math.min(shot.shotDuration,shot.shotTime+dt)
        if shot.shotTime>=shot.shotDuration then
            shot.deploying=false
            p.hookKick=1
            p.vx=p.vx-(p.hookAimX or 0)*48
            p.vy=p.vy-(p.hookAimY or 0)*24
            game.hitstop=.025
            playSound("rope",.035)
            playSound("gearJingle",.025)
            spawnFX(shot.x,shot.y,9,{.92,.65,.25},85,85)
            addMessage("El hierro encuentra un punto firme.",1.5)
        end
    end

    if p.hook and not p.hook.deploying then
        local cx, cy = p.x + p.w / 2, p.y + p.h / 2
        local dx, dy = cx - p.hook.x, cy - p.hook.y
        local d = math.max(1, math.sqrt(dx * dx + dy * dy))
        if d > p.hook.length then
            local nx, ny = dx / d, dy / d
            local excess = d - p.hook.length
            -- La corrección de cuerda debe atravesar el mismo resolvedor que
            -- el movimiento normal; asignar x/y directamente causaba el bug
            -- de quedar metido en la cara inferior de una plataforma.
            moveAxis(p, -nx * excess, "x")
            moveAxis(p, -ny * excess, "y")
            local radial = p.vx * nx + p.vy * ny
            if radial > 0 then p.vx, p.vy = p.vx - radial * nx, p.vy - radial * ny end
            if excess > 8 and p.ropeSoundTimer <= 0 then
                playSound("rope", .08)
                p.ropeSoundTimer = .22
            end
        end
        if Input.isDown("up") then p.hook.length = math.max(68, p.hook.length - 215 * dt) end
        if Input.isDown("down") then p.hook.length = math.min(520, p.hook.length + 150 * dt) end
    end

    local fallSpeed = p.vy
    moveAxis(p, p.vx * dt, "x")
    moveAxis(p, p.vy * dt, "y")
    resolveOverlap(p)
    tryHookMantle(p)
    local edgeTarget=edgeAwareness(p,p.facing)
    p.edgeFactor=lerp(p.edgeFactor or 0,edgeTarget,1-math.pow(.0008,dt))
    p.nearEdge=(p.edgeFactor or 0)>.08

    if p.grounded and not wasGrounded and fallSpeed > 190 then
        playSound("land")
        playSound("gearJingle",clamp(fallSpeed/900,.025,.075))
        p.squash = clamp(fallSpeed / 1800, .1, .24)
        p.landTimer = .2
        p.bellyVY = (p.bellyVY or 0) + clamp(fallSpeed*.18,45,135)
        p.gearVY = (p.gearVY or 0) + clamp(fallSpeed*.11,30,85)
        p.helmetVelocity = (p.helmetVelocity or 0) - p.facing*.8
        PlayerAnimation.trigger(p, "land", .2, clamp(fallSpeed/600,.6,1.4))
        spawnFX(p.x + p.w / 2, p.y + p.h, math.floor(clamp(fallSpeed / 70, 5, 13)), {.42, .35, .3}, 145, 65)
        Particles.emit(game.fx, {x=p.x+p.w/2,y=p.y+p.h,count=math.floor(clamp(fallSpeed/55,7,18)),color={.44,.37,.31},speed=clamp(fallSpeed*.22,90,220),angle=math.pi/2,spread=2.25,kind="dust",gravity=90,life=.5,size=3})
        if game.puzzles then Puzzles.noise(game.puzzles,p.x+p.w/2,p.y+p.h,clamp(fallSpeed/420,.5,2),game.currentRegion,playSound,addMessage) end
        for _, enemy in ipairs(game.enemies) do
            local playerRegion = regionForRow(math.floor(p.y/TILE)+1)
            local enemyHomeRegion = regionForRow(math.floor((enemy.homeY or enemy.y)/TILE)+1)
            if enemy.kind == "bat" and not enemy.dead and playerRegion >= enemyHomeRegion and dist(enemy.x,enemy.y,p.x,p.y) < 900 then
                enemy.noise = math.min(5,(enemy.noise or 0)+clamp(fallSpeed/360,.45,2.2))
                if not enemy.luredToChime then
                    enemy.soundTargetX, enemy.soundTargetY = p.x+p.w/2, p.y+p.h
                    if enemy.noise >= 2.4 then enemy.awake, enemy.soundTimer = true, 4.5 end
                end
            end
        end
    elseif p.grounded and dir ~= 0 and math.abs(p.vx) > 55 and p.stepTimer <= 0 then
        playSound("step")
        p.stepTimer = clamp(.34 - math.abs(p.vx) / 1400, .14, .3)
    end

    if p.hookBuffer > 0 and not p.hook and not p.mantle then
        game.selectedAnchor = aimedAnchor()
        if game.selectedAnchor and tryHook() then p.hookBuffer = 0 end
    end

    if p.lanternOn then p.light = math.max(0, p.light - dt * 1.15) end
    if p.light < 20 and p.lowLightTimer <= 0 then
        playSound("lowBattery", .03)
        p.lowLightTimer = p.light < 8 and 1.15 or 2.25
    end
    if p.y > (#map - 1) * TILE then loadCheckpoint() end

    local tx, ty = math.floor((p.x + p.w / 2) / TILE) + 1, math.floor((p.y + p.h / 2) / TILE) + 1
    local here = tileAt(tx, ty)
    if here == "?" and not game.foundDrawing then
        game.foundDrawing = true
        playSound("discovery")
        addMessage("Un dibujo infantil: una ciudad bajo la mina. Al dorso: «Abajo siguen cantando». ", 7)
    end

    local activeRefuge
    for _, refuge in ipairs(game.refuges) do
        if dist(p.x, p.y, refuge.x, refuge.y) < 100 then activeRefuge = refuge break end
    end
    if activeRefuge then
        p.refugeRest=(p.refugeRest or 0)+dt
        p.refugeFactor=lerp(p.refugeFactor or 0,1,1-math.pow(.01,dt))
        local beforeLight=p.light
        p.light = math.min(100, p.light + 45 * dt)
        if p.light>beforeLight then
            game.lightRechargePulse=math.min(1,(game.lightRechargePulse or 0)+dt*4.8)
        end
        p.hp = p.maxHp
        if not game.atRefuge then
            game.atRefuge = true
            activeRefuge.activated=true
            activeRefuge.activationPulse=1
            game.saveNotice=3.2
            game.saveGlyphPhase=0
            playSound("refuge")
            playSound("deepRumble",.006)
            Particles.emit(game.fx,{x=activeRefuge.x+42,y=activeRefuge.y+2,count=34,color={1,.48,.08},speed=175,angle=-math.pi/2,spread=1.05,kind="spark",gravity=-55,drag=.22,life=1.15,size=3})
            Particles.emit(game.fx,{x=activeRefuge.x+42,y=activeRefuge.y-4,count=20,color={1,.86,.38},speed=95,angle=-math.pi/2,spread=.8,kind="dust",gravity=-35,drag=.4,life=1.5,size=4})
            saveCheckpoint()
            addMessage("REFUGIO — La fogata queda encendida. Progreso guardado.", 5)
        end
    else
        game.atRefuge = false
        p.refugeRest=0
        p.refugeFactor=lerp(p.refugeFactor or 0,0,1-math.pow(.01,dt))
    end
end

local function updateBlindCreature(e, dt)
    local p = game.player
    if e.sealed then
        e.phase=e.phase+dt
        e.sealedTime=(e.sealedTime or 0)+dt
        e.x=(e.sealX or e.x)-e.w/2
        e.y=(e.sealY or e.y)-e.h/2
        e.vx,e.vy,e.awake,e.soundTimer=0,0,false,0
        return
    end
    if e.listenerLeap then
        local leap=e.listenerLeap
        leap.t=math.min(1,leap.t+dt/leap.duration)
        local smooth=leap.t*leap.t*(3-2*leap.t)
        e.x=lerp(leap.startX,leap.endX,smooth)
        e.y=lerp(leap.startY,leap.endY,smooth)-math.sin(leap.t*math.pi)*leap.height
        e.vx=(leap.endX-leap.startX)/leap.duration
        e.vy=-math.cos(leap.t*math.pi)*leap.height*math.pi/leap.duration
        e.grounded=false
        e.phase=e.phase+dt*2.2
        if leap.t<1 then return end
        e.listenerLeap=nil
        e.x,e.y=leap.endX,leap.endY
        e.vx,e.vy=0,80
        e.jumpCooldown=.55
        game.shake=math.max(game.shake or 0,.16)
        playSound("impact",.14)
        spawnFX(e.x+e.w/2,e.y+e.h,8,{.18,.58,.42},115,65)
    end
    if e.dead then e.deathTimer = e.deathTimer + dt return end
    e.phase = e.phase + dt
    e.voiceTimer = math.max(0, (e.voiceTimer or 0) - dt)
    e.stepSoundTimer = math.max(0, (e.stepSoundTimer or 0) - dt)
    e.jumpCooldown=math.max(0,(e.jumpCooldown or 0)-dt)
    local d = dist(e.x, e.y, p.x, p.y)
    if d < 360 and not e.introduced then
        e.introduced = true
        presentEncounter("blind", "EL OYENTE", "No ve. Recuerda cada sonido.")
        playSound("listenerCall", .1)
        addMessage("Lo que vive sin ojos habita un mundo hecho de ecos.", 7)
    end
    e.soundTimer = math.max(0, (e.soundTimer or 0) - dt)
    local hunting=e.soundTimer>0
    local seal,sealDistance=nearestMarker("Z",e.x+e.w/2,e.y+e.h/2,5)
    if e.soundTimer > 0 then
        e.vx = lerp(e.vx, sign(e.soundTargetX - e.x) * 125, 1 - math.pow(.002, dt))
    else
        -- Cautious patrol: it owns the platform but treats the green seal as a
        -- hole in the world. Only a fresh sound can overrule this avoidance.
        e.patrolDir=e.patrolDir or (((e.id or 1)%2==0) and -1 or 1)
        if seal and sealDistance<125 and sign((seal.x+24)-(e.x+e.w/2))==e.patrolDir then e.patrolDir=-e.patrolDir end
        e.vx=lerp(e.vx,e.patrolDir*42,1-math.pow(.025,dt))
    end
    local wasEnemyGrounded=e.grounded
    e.vy = e.vy + GRAVITY * dt
    e.grounded = false
    local floorAhead=hasFloorAhead(e,e.vx*dt)
    if wasEnemyGrounded and e.jumpCooldown<=0 and hunting then
        local dx=(e.soundTargetX or e.x)-e.x
        local dy=(e.soundTargetY or e.y)-e.y
        if dy<-40 then
            -- Cualquier ruido claramente más alto provoca una trepada directa,
            -- incluso bajo el centro de la plataforma. El Oyente se aferra a la
            -- cara frontal: no necesita encontrar primero uno de sus bordes.
            e.listenerLeap={
                t=0,duration=.72,startX=e.x,startY=e.y,
                endX=(e.soundTargetX or e.x)-e.w/2,
                endY=(e.soundTargetY or e.y),
                height=125+math.min(115,math.abs(dy)*.3)
            }
            e.jumpCooldown=.9
            playSound("listenerCall",.11)
            return
        elseif math.abs(dy)<95 and not floorAhead then
            -- A committed listening leap carries enough horizontal momentum to
            -- bridge the city's broken platforms, including one level upward.
            e.vy=-760
            e.vx=sign(dx)*195
            e.jumpCooldown=.72
            floorAhead=true
            if enemyAudible(e, 400) then playSound("listenerSkitter",.1) end
            spawnFX(e.x+e.w/2,e.y+e.h,7,{.18,.58,.42},105,70)
        elseif dy>70 and not floorAhead then
            -- If the remembered sound is below, it deliberately leaves the
            -- ledge instead of freezing at the edge as it did before.
            e.vx=sign(dx)*145
            floorAhead=true
            e.jumpCooldown=.35
        end
    end
    if not floorAhead and wasEnemyGrounded then
        if hunting then e.vx=0 else e.patrolDir=-e.patrolDir; e.vx=e.patrolDir*42 end
    end
    moveAxis(e, e.vx * dt, "x"); moveAxis(e, e.vy * dt, "y")
    if enemyAudible(e, 340) and math.abs(e.vx) > 35 and e.stepSoundTimer <= 0 then
        playSound("listenerSkitter", .16); e.stepSoundTimer = .42
    end
    if enemyAudible(e, 460) and e.voiceTimer <= 0 then
        playSound("listenerCall", .14); e.voiceTimer = 5.5 + math.random() * 4
    end
    seal,sealDistance=nearestMarker("Z",e.x+e.w/2,e.y+e.h/2,5)
    if hunting and sealDistance and sealDistance < 46 and math.abs(e.vx) > 38 then
        e.dead,e.sealed,e.sealedTime=true,true,0
        e.sealX,e.sealY=seal.x+TILE/2,seal.y+TILE/2
        e.x,e.y=e.sealX-e.w/2,e.sealY-e.h/2
        e.vx,e.vy,e.soundTimer=0,0,0
        game.shake = .5
        Save.write(game)
        playSound("guardianDown")
        addMessage("El sello bebe su eco. La ciudad vuelve a quedar en silencio.", 6)
    elseif d < 38 then
        damagePlayer(e.x)
    end
end

local function updateAstralWarden(e, dt)
    local p = game.player
    if e.dead then e.deathTimer = e.deathTimer + dt return end
    if e.astralDying then
        e.astralDeathTime=(e.astralDeathTime or 0)+dt
        e.phase=e.phase+dt*(3.5+e.astralDeathTime*2)
        e.vx,e.vy=0,0
        e.astralAuraRadius=340+math.sin(e.astralDeathTime*5)*18
        e.deathParticleTimer=math.max(0,(e.deathParticleTimer or 0)-dt)
        if e.deathParticleTimer<=0 then
            e.deathParticleTimer=.09
            spawnFX(e.x+e.w/2,e.y+e.h/2,5,{.76,.46,1},175,190)
        end
        if e.astralDeathCue==0 and e.astralDeathTime>.9 then
            e.astralDeathCue=1
            playSound("astralReturn",.018)
            game.astralDefeatFlash=.32
        elseif e.astralDeathCue==1 and e.astralDeathTime>2.35 then
            e.astralDeathCue=2
            playSound("astralBurst",.035)
            playSound("guardianDown",.025)
            game.shake=1.15
            game.hitstop=.075
            game.astralDefeatFlash=1
            spawnFX(e.x+e.w/2,e.y+e.h/2,46,{.84,.62,1},330,280)
        end
        if e.astralDeathTime>=3.05 then
            e.astralDying=false
            e.dead=true
            e.deathTimer=0
            Save.write(game)
            game.astralCinematic=nil
            addMessage("La mina exhala. El Vigía ya no pertenece a este lado.",6)
        end
        return
    end
    e.phase = e.phase + dt
    e.voiceTimer = math.max(0, (e.voiceTimer or 0) - dt)
    local d = dist(e.x, e.y, p.x, p.y)
    if d < 430 and not e.introduced then
        e.introduced = true
        presentEncounter("astral", "EL VIGÍA ASTRAL", "La luz no lo hiere. Los sellos sí lo recuerdan.")
        playSound("astralVoice", .07)
        addMessage("Hay presencias que la luz revela, pero no puede herir.", 7)
    end
    e.stun = math.max(0, e.stun - dt)
    e.repulse = math.max(0, (e.repulse or 0) - dt * 2)
    e.astralDashCooldown=math.max(0,(e.astralDashCooldown or 3.4)-dt)
    e.astralWindup=math.max(0,(e.astralWindup or 0)-dt)
    e.astralDash=math.max(0,(e.astralDash or 0)-dt)
    if e.introduced and d<700 and e.stun<=0 and e.repulse<=0 and e.astralDashCooldown<=0 and e.astralDash<=0 and e.astralWindup<=0 then
        e.astralWindup=.72
        e.astralDashDirection=sign((p.x+p.w/2)-(e.x+e.w/2))
        e.astralDashCooldown=3.8-math.min(1.25,(e.impacts or 0)*.62)
        playSound("astralVoice",.075)
        spawnFX(e.x+e.w/2,e.y+e.h/2,12,{.7,.35,1},125,105)
    end
    local targetDX=(p.x+p.w/2)-(e.x+e.w/2)
    local targetDY=(p.y+p.h/2)-(e.y+e.h/2)
    local targetLength=math.max(1,math.sqrt(targetDX*targetDX+targetDY*targetDY))
    if e.astralWindup>0 then
        e.vx=e.vx*math.pow(.0005,dt)
        e.vy=e.vy*math.pow(.0005,dt)
        if e.astralWindup<=dt then
            e.astralDash=.52
            e.astralDashDX,e.astralDashDY=targetDX/targetLength,targetDY/targetLength
            e.vx=e.astralDashDX*(310+(e.impacts or 0)*65)
            e.vy=e.astralDashDY*(310+(e.impacts or 0)*65)
            game.shake=math.max(game.shake,.2)
            playSound("charge",.1)
        end
    elseif e.astralDash>0 then
        local dashSpeed=310+(e.impacts or 0)*65
        e.vx=(e.astralDashDX or e.astralDashDirection or 1)*dashSpeed
        e.vy=(e.astralDashDY or 0)*dashSpeed
    elseif e.stun <= 0 then
        local direction = sign((p.x + p.w / 2) - (e.x + e.w / 2))
        if e.repulse > 0 then direction = -direction end
        local huntSpeed=82+(e.impacts or 0)*27
        e.vx = lerp(e.vx, direction * (e.repulse > 0 and 220 or huntSpeed), 1 - math.pow(.01, dt))
        local verticalDirection=e.repulse>0 and -sign(targetDY) or targetDY/targetLength
        e.vy=lerp(e.vy,verticalDirection*(e.repulse>0 and 150 or huntSpeed*.72),1-math.pow(.018,dt))
    else
        e.vx = e.vx * math.pow(.002, dt)
        e.vy = e.vy * math.pow(.002, dt)
    end
    -- El Vigía existe en otro plano: roca, muros y las propias plataformas que
    -- materializa jamás pueden encerrarlo ni desviar su última aproximación.
    e.grounded=false
    local nx,ny=e.x+e.vx*dt,e.y+e.vy*dt
    e.x,e.y=nx,ny
    e.astralPhasing=(math.abs(e.vx)>28 or math.abs(e.vy)>28)
    local worldLeft,worldRight=12,MAP_W*TILE-e.w-12
    if e.x<worldLeft then e.x=worldLeft; e.vx=math.abs(e.vx)*.4 end
    if e.x>worldRight then e.x=worldRight; e.vx=-math.abs(e.vx)*.4 end
    local regionTop=(6-1)*World.regionHeight*TILE+12
    local regionBottom=6*World.regionHeight*TILE-e.h-12
    if e.y<regionTop then e.y=regionTop; e.vy=math.abs(e.vy)*.4 end
    if e.y>regionBottom then e.y=regionBottom; e.vy=-math.abs(e.vy)*.4 end
    -- Tocar un sello basta. El destello sirve para guiar o repeler al Vigía,
    -- pero no se exige una pulsación perfecta cuando ambos ya se superponen.
    activateAstralSeal(e,72)
    if enemyAudible(e, 500) and e.voiceTimer <= 0 then
        playSound("astralVoice", .11); e.voiceTimer = 4.5 + math.random() * 4.5
    end
    if d < 45 then damagePlayer(e.x,e.astralDash>0 and 2 or 1,true) end
end

local function updateResonant(e, dt)
    local p = game.player
    if e.dead then e.deathTimer = e.deathTimer + dt return end
    local playerRegion = regionForRow(math.floor(p.y/TILE)+1)
    local homeRegion = regionForRow(math.floor((e.homeY or e.y)/TILE)+1)
    local upperBoundary = (homeRegion - 1) * World.regionHeight * TILE
    local playerAboveTerritory = playerRegion < homeRegion
    if playerAboveTerritory then
        e.awake, e.luredToChime = false, nil
        e.soundTimer, e.flashCharge, e.noise = 0, 0, 0
        e.soundTargetX, e.soundTargetY = e.homeX, e.homeY
    end
    e.phase = e.phase + dt
    e.voiceTimer = math.max(0, (e.voiceTimer or 0) - dt)
    e.wingTimer = math.max(0, (e.wingTimer or 0) - dt)
    e.soundTimer = math.max(0, (e.soundTimer or 0) - dt)
    e.stun = math.max(0, (e.stun or 0) - dt)
    e.flashCharge = math.max(0, (e.flashCharge or 0) - dt)
    e.lurePulse = math.max(0, (e.lurePulse or 0) - dt * .7)
    e.noise = math.max(0, (e.noise or 0) - dt * (e.awake and .16 or .3))
    local playerDistance = dist(e.x, e.y, p.x, p.y)

    if playerDistance < 520 and not e.introduced then
        e.introduced = true
        presentEncounter("resonant", "EL RESONANTE", "No busca cuerpos. Busca el lugar donde nació el ruido.")
        playSound("batScreech", .11)
        addMessage("Las campanas minerales todavía conservan una voz.", 5)
    end

    if e.soundTimer <= 0 and e.noise < 1 then
        e.awake, e.luredToChime = false, nil
    end

    local targetX, targetY
    if e.awake and e.soundTimer > 0 then
        targetX, targetY = e.soundTargetX, e.soundTargetY
    else
        targetX = e.homeX + math.sin(e.phase * .43) * 115
        targetY = e.homeY + math.sin(e.phase * .71) * 55
    end
    local dx, dy = targetX - e.x, targetY - e.y
    local length = math.max(1, math.sqrt(dx*dx + dy*dy))
    local resonanceDive=e.luredToChime~=nil
    local desiredSpeed = resonanceDive and 315 or (e.flashCharge > 0 and 335 or (e.awake and 245 or 68))
    local response = 1 - math.pow(resonanceDive and .00008 or (e.awake and .0015 or .025), dt)
    if e.stun <= 0 then
        e.vx = lerp(e.vx, dx/length*desiredSpeed, response)
        e.vy = lerp(e.vy, dy/length*desiredSpeed, response)
    else
        e.vx, e.vy = e.vx * math.pow(.03,dt), e.vy * math.pow(.03,dt)
    end

    local nx, ny = e.x + e.vx*dt, e.y + e.vy*dt
    if resonanceDive then
        -- A mineral bell couples directly to its echolocation. During this
        -- short committed dive it follows the resonance through the thin mine
        -- geometry, avoiding the old bounce/timeout soft-lock.
        e.x,e.y=nx,ny
    else
        if rectHitsSolid(nx, e.y, e.w, e.h) then e.vx = -e.vx*.55 else e.x = nx end
        if rectHitsSolid(e.x, ny, e.w, e.h) then e.vy = -e.vy*.55 else e.y = ny end
    end
    if e.y < upperBoundary then
        e.y = upperBoundary
        e.vy = math.abs(e.vy) * .35
    end

    if e.awake and enemyAudible(e, 420) and e.wingTimer <= 0 then
        playSound("batFlutter", .18); e.wingTimer = .18 + math.random()*.12
    end
    if e.awake and enemyAudible(e, 500) and e.voiceTimer <= 0 then
        playSound("batScreech", .14); e.voiceTimer = 2.2 + math.random()*2.6
    end

    local chime = e.luredToChime and game.chimes and game.chimes[e.luredToChime] or nil
    if chime and not chime.broken and dist(e.x+e.w/2,e.y+e.h/2,chime.x+TILE/2,chime.y+TILE/2) < 35 then
        chime.broken, chime.ringing = true, 0
        e.luredToChime, e.soundTimer = nil, 0
        e.impacts = (e.impacts or 0) + 1
        e.stun, e.vx, e.vy = .9, -e.vx*.4, -e.vy*.4
        game.shake, game.hitstop = .45, .055
        playSound("batCrash", .07)
        spawnFX(chime.x+TILE/2,chime.y+TILE/2,18,{.68,.36,.59},220,180)
        if e.impacts >= 2 then
            e.dead, e.deathTimer = true, 0
            playSound("guardianDown", .08)
            Save.write(game)
            addMessage("El segundo eco se cierra sobre él. El Resonante huye y la grieta sella su nido.", 6)
        else
            addMessage("Un eco muere. Otro continúa llamando.", 6)
        end
    elseif not playerAboveTerritory and playerDistance < 42 then
        damagePlayer(e.x, 2)
    end
end

local function stirNearbyCreatures(source,radius,intensity)
    local sx,sy=source.x+source.w/2,source.y+source.h/2
    for _,other in ipairs(game.enemies or {}) do
        if other~=source and not other.dead and not other.boundPlate and dist(sx,sy,other.x+other.w/2,other.y+other.h/2)<radius then
            if other.kind=="bat" then
                other.noise=math.min(5,(other.noise or 0)+intensity)
                if other.noise>2.35 then other.awake=true; other.soundTimer=math.max(other.soundTimer or 0,3.2) end
            elseif other.kind=="blind" then
                other.awake=true; other.soundTimer=math.max(other.soundTimer or 0,2.8)
            elseif other.kind=="custodian" then
                other.awake=true; other.searchTimer=math.max(other.searchTimer or 0,1.8)
            end
            other.soundTargetX,other.soundTargetY=sx,sy
            other.lastSensedX,other.lastSensedY=sx,sy
        end
    end
end

local function refreshEnemyMood(e,dt)
    local previous=e.mood
    local mood="dormant"
    if e.dead or e.boundPlate or e.sealed then mood="contained"
    elseif e.charging or (e.astralDash or 0)>0 or e.luredToChime then mood="furious"
    elseif (e.windup or 0)>0 or (e.astralWindup or 0)>0 then mood="alert"
    elseif e.awake or (e.soundTimer or 0)>0 then mood="curious"
    elseif (e.searchTimer or 0)>0 then mood="searching" end
    if previous~=mood then e.mood=mood; e.moodTime=0 else e.moodTime=(e.moodTime or 0)+dt end
    e.searchTimer=math.max(0,(e.searchTimer or 0)-dt)
    if (e.awake or (e.soundTimer or 0)>0) then
        e.lastSensedX=e.soundTargetX or game.player.x
        e.lastSensedY=e.soundTargetY or game.player.y
    elseif previous=="curious" and mood=="dormant" then
        e.searchTimer=2.2+(e.id%3)*.45
        e.mood="searching"; e.moodTime=0
    end
end

local function updateEnemy(e, dt)
    if e.boundPlate then e.vx,e.vy,e.awake=0,0,false return end
    if e.kind == "blind" then updateBlindCreature(e, dt) return end
    if e.kind == "astral" then updateAstralWarden(e, dt) return end
    if e.kind == "bat" then updateResonant(e, dt) return end
    local p = game.player
    if e.dead then
        e.deathTimer = e.deathTimer + dt
        return
    end
    -- A clamp may close while another Custodian is already committed to it.
    -- Reassign that charge immediately instead of letting stale target data
    -- force the creature forever towards its original side of the room.
    if regionForRow(math.floor(e.y/TILE)+1)==2 and e.counterTarget and e.counterTarget.locked and e.boundPlate~=e.counterTarget then
        local replacement=Puzzles.targetPlate(game.puzzles,e,game.enemies,e.counterPreferredDirection)
        e.counterTarget=replacement
        if replacement then
            local below=(replacement.y+48)>(e.y+e.h+TILE)
            e.counterDropDirection=below and sign((replacement.x+24)-(e.x+e.w/2)) or nil
            e.targetX=e.counterDropDirection and (e.x+e.counterDropDirection*900) or replacement.x+24
            if e.charging then
                local direction=e.counterDropDirection or sign((replacement.x+24)-(e.x+e.w/2))
                e.vx=direction*math.max(300,math.abs(e.vx))
                e.chargeTimer=math.max(e.chargeTimer,5.2)
            end
        else
            e.counterDropDirection=nil
            e.charging=false
            e.vx=0
        end
    end
    e.phase = e.phase + dt
    e.voiceTimer = math.max(0, (e.voiceTimer or 0) - dt)
    e.stepSoundTimer = math.max(0, (e.stepSoundTimer or 0) - dt)
    e.noticeTimer=math.max(0,(e.noticeTimer or 0)-dt)
    local d = dist(e.x, e.y, p.x, p.y)
    local lightDistance=dist(e.x+e.w/2,e.y+e.h/2,p.x+p.w/2,p.y+p.h/2)

    if d < 330 and not e.introduced then
        e.introduced = true
        presentEncounter("custodian" .. e.id, "CUSTODIO", "La fuerza que no sabe detenerse siempre encuentra su límite.")
        playSound("custodianBreath", .07)
    end

    e.stun = math.max(0, e.stun - dt)
    if e.windup > 0 then
        e.windup = e.windup - dt
        e.tellFXTimer = math.max(0, (e.tellFXTimer or 0) - dt)
        if e.tellFXTimer <= 0 then
            e.tellFXTimer = .11
            spawnFX(e.x + e.w / 2, e.y + e.h, 3, {.62, .25, .14}, 120, 45)
        end
        e.vx = e.vx * math.pow(.002, dt)
        if e.windup <= 0 then
            e.charging = true
            e.chargeTimer = e.counterTarget and 5.2 or 1.45
            e.vx = (e.counterDropDirection or sign(e.targetX - (e.x + e.w / 2))) * 510
            playSound("charge")
            playSound("custodianRoar", .055)
            stirNearbyCreatures(e,440,1.35)
            addMessage("El aire se tensa.", 1.4)
        end
    elseif e.charging then
        e.chargeTimer = e.chargeTimer - dt
        if e.counterTarget and (not e.counterDropDirection or not e.grounded) then
            local targetDirection=sign((e.counterTarget.x+24)-(e.x+e.w/2))
            local currentDirection=sign(e.vx)
            local mayCorrect=e.grounded or math.abs(e.vx)<40 or targetDirection==currentDirection
            if mayCorrect and math.abs((e.counterTarget.x+24)-(e.x+e.w/2))>32 then
                e.vx=targetDirection*math.max(135,math.abs(e.vx))
            end
        end
        local nx = e.x + e.vx * dt
        local hit, tx, ty = rectHitsSolid(nx, e.y, e.w, e.h)
        if hit then
            local hitReinforcedRock = tileAt(tx, ty) == "X"
            e.charging = false
            e.vx = -e.vx * .12
            e.stun = hitReinforcedRock and 1.35 or .75
            game.shake = .55
            game.hitstop = .055
            playSound("impact")
            stirNearbyCreatures(e,560,2.1)
            game.enemyMarks[#game.enemyMarks+1]={x=e.x+e.w/2,y=e.y+e.h,kind="impact",seed=e.id*17+#game.enemyMarks}
            if #game.enemyMarks>28 then table.remove(game.enemyMarks,1) end
            if hitReinforcedRock then
                -- Los bloques X forman una misma columna reforzada; el daño se
                -- comparte para que toda la estructura envejezca con el golpe.
                local damageKey=tostring(tx)
                game.reinforcedDamage[damageKey]=math.min(3,(game.reinforcedDamage[damageKey] or 0)+1)
                e.impacts = e.impacts + 1
                for i = 1, 14 do
                    game.debris[#game.debris + 1] = {
                        x = (tx - .5) * TILE, y = (ty - .5) * TILE,
                        vx = (math.random() - .5) * 300, vy = -math.random() * 240,
                        life = .8 + math.random() * .5
                    }
                end
                if game.reinforcedDamage[damageKey] >= 3 then
                    for rockY, row in ipairs(map) do
                        for rockX = 1, #row do
                            if rockX == tx and tileAt(rockX, rockY) == "X" then setTile(rockX, rockY, ".") end
                        end
                    end
                    e.dead = true
                    e.defeatFacing=sign(e.vx~=0 and e.vx or (e.targetX-e.x))
                    e.deathTimer = 0
                    Save.write(game)
                    playSound("guardianDown")
                    if allThreatsDefeated() then
                        addMessage("El último Custodio cae. Algo se abre en las profundidades.", 6)
                    else
                        addMessage("Toda violencia termina por regresar a su origen.", 6)
                    end
                else
                    addMessage("La piedra conserva una grieta nueva.", 3)
                end
            else
                addMessage("El impacto pasa. La coraza permanece.", 2.5)
            end
        elseif e.chargeTimer <= 0 then
            e.charging = false
            e.stun = .55
            e.vx = 0
        else
            e.x = nx
        end
    elseif e.stun > 0 then
        e.vx = e.vx * math.pow(.004, dt)
    elseif lightDistance < 245 and p.light > 3 and p.lanternOn then
        -- La luz presente siempre gana sobre un rastro viejo. Un Custodio no
        -- puede seguir investigando el pasado mientras el jugador lo ilumina.
        if not e.awake then
            e.noticeTimer=.72
            playSound("alert",.018)
            Particles.emit(game.fx,{x=e.x+e.w/2,y=e.y+10,count=7,color={1,.22,.1},speed=54,spread=math.pi*2,kind="spark",gravity=15,life=.35,size=2})
        end
        e.awake = true
        e.searchTimer=0
        e.lastSensedX,e.lastSensedY=p.x+p.w/2,p.y+p.h/2
        local recognitionSpeed=lerp(.32,1,clamp((.72-e.noticeTimer)/.5,0,1))
        e.vx = e.vx + sign((p.x+p.w/2)-(e.x+e.w/2)) * 205 * recognitionSpeed * dt
        e.vx = clamp(e.vx, -78*recognitionSpeed, 78*recognitionSpeed)
    elseif (e.searchTimer or 0)>0 then
        local remaining=(e.lastSensedX or e.homeX)-(e.x+e.w/2)
        if math.abs(remaining)>22 then
            e.vx=clamp(e.vx+sign(remaining)*95*dt,-46,46)
        else
            -- No encuentra nada: se detiene, escucha y recién después cede.
            e.vx=e.vx*math.pow(.01,dt)
            e.hesitation=math.max(0,(e.hesitation or .5)-dt)
        end
    else
        e.awake = false
        e.vx = clamp(e.vx + math.sin(e.phase * .7) * 25 * dt, -35, 35)
    end

    e.vy = e.vy + GRAVITY * dt
    e.grounded = false
    if not e.charging then
        if not hasFloorAhead(e, e.vx * dt) then e.vx = -e.vx * .4 end
        moveAxis(e, e.vx * dt, "x")
    end
    moveAxis(e, e.vy * dt, "y")
    if e.grounded and not wasEnemyGrounded and e.charging and regionForRow(math.floor(e.y/TILE)+1)==2 then
        -- Las rampas de recepción absorben la caída sin quitarle al Custodio
        -- el impulso suficiente para deslizarse hasta el contrapeso.
        e.vx=clamp(e.vx*.24,-135,135)
        e.counterDropDirection=nil
        game.shake=math.max(game.shake,.18)
        playSound("impact",.08)
    end
    -- Custodios fuera de cámara no deben convertirse en un metrónomo global.
    if enemyAudible(e, 420) and math.abs(e.vx) > 28 and e.grounded and e.stepSoundTimer <= 0 then
        playSound("custodianStep", .13)
        e.stepSoundTimer = e.charging and .22 or .62
    end
    if enemyAudible(e, 350) and e.awake and not e.charging and e.windup <= 0 and e.voiceTimer <= 0 then
        playSound("custodianBreath", .09); e.voiceTimer = 3.8 + math.random() * 3.5
    end
    if math.abs((e.x + e.w / 2) - (p.x + p.w / 2)) < (e.w + p.w) / 2 and
       math.abs((e.y + e.h / 2) - (p.y + p.h / 2)) < (e.h + p.h) / 2 then
        damagePlayer(e.x)
    end
end

local function updateCamera(dt)
    Camera.update(game.camera, game.player, dt, MAP_W, MAP_H, TILE, DESIGN_W, DESIGN_H)
    local focus=game.astralCinematic
    if focus and not focus.dead then
        local midpointX=((game.player.x+game.player.w/2)+(focus.x+focus.w/2))*.5
        local midpointY=((game.player.y+game.player.h/2)+(focus.y+focus.h/2))*.5
        local targetX=clamp(midpointX-DESIGN_W*.5,0,MAP_W*TILE-DESIGN_W)
        local targetY=clamp(midpointY-DESIGN_H*.44,0,MAP_H*TILE-DESIGN_H)
        game.camera.x=lerp(game.camera.x,targetX,1-math.pow(.00003,dt))
        game.camera.y=lerp(game.camera.y,targetY,1-math.pow(.00003,dt))
    end
end

local function updateProgress()
    local region = regionForRow(math.floor(game.player.y / TILE) + 1)
    if game.currentRegion and game.currentRegion ~= region then
        game.depthTransition={t=0,from=game.currentRegion,to=region}
        game.player.zoneGestureTimer=.9
        game.zoneReveal = 3.2
        playSound("discovery", .035)
        playSound("deepRumble", .009)
    end
    game.currentRegion = region
    game.zoneName = REGION_NAMES[region]
    if region == 1 then
        game.objective = regionThreatsDefeated(1) and "El camino recuerda hacia dónde cae la tierra" or "La fuerza bruta sólo tiene malos resultados"
        if not game.tutorial.hook then
            game.tutorial.hook = true
            addMessage("Los anclajes brillan cuando los apuntás. E o clic izquierdo lanza el gancho.", 5)
        end
    elseif region == 2 then
        game.objective = game.puzzles.counterweight and "Cuando el peso calla, la mina se mueve" or "Todo peso proyecta una ausencia"
        if not game.tutorial.chain then
            game.tutorial.chain = true
            addMessage("W te sube a la plataforma. Para encadenar: ESPACIO, apuntá y usá E en el aire.", 6)
        end
    elseif region == 3 then
        if enemyKindAlive("bat",3) then game.objective = game.puzzles.resonance>.16 and "La cámara todavía recuerda" or "El silencio también puede hacer ruido"
        else game.objective = "El eco se apagó" end
    elseif region == 4 then
        game.objective = game.player.lanternOn and "No toda raíz desea la luz" or "La oscuridad también alimenta"
    elseif region == 5 then
        game.objective = regionThreatsDefeated(5) and "Las sombras conservan la forma de la luz" or "Aquello que no ve jamás deja de escuchar"
    else
        game.objective = allThreatsDefeated() and "El umbral conoce tu nombre" or "Tres memorias rodean lo que nunca debió despertar"
    end
end

local function updateMapFragments()
    local p = game.player
    for _, fragment in ipairs(game.mapFragments) do
        if not fragment.collected and dist(p.x + p.w / 2, p.y + p.h / 2, fragment.x + TILE / 2, fragment.y + TILE / 2) < 58 then
            fragment.collected = true
            game.mapUnlocked[fragment.region] = true
            playSound("discovery")
            addMessage("MAPA ACTUALIZADO — " .. REGION_NAMES[fragment.region] .. ". TAB para abrirlo.", 5)
        end
    end
end

local CLUE_TEXTS, RESCUE_NAMES, HOOK_NAMES = Content.clueTexts, Content.rescueNames, Content.hookNames

local function updateDiscoveries()
    local p = game.player
    local px, py = p.x + p.w / 2, p.y + p.h / 2
    game.nearClueIndex = nil
    for index, clue in ipairs(game.clues) do
        local clueDistance = dist(px, py, clue.x + 24, clue.y + 24)
        if clueDistance < 72 then
            game.nearClueIndex = index
            if not clue.collected then
                clue.collected = true; game.cluesFound = game.cluesFound + 1
                playSound("discovery"); game.hitstop = .06
                addMessage("DIBUJO RECUPERADO — Presioná E para observarlo.", 5)
                Save.write(game)
            end
        end
    end
    for index, rescue in ipairs(game.rescues) do
        if not rescue.collected and dist(px, py, rescue.x + 24, rescue.y + 24) < 66 then
            rescue.collected = true; game.rescued[index] = true
            playSound("refuge"); addMessage("RESCATADO — " .. RESCUE_NAMES[index] .. " te esperará en los próximos refugios.", 6)
            Save.write(game)
        end
    end
    for _, upgrade in ipairs(game.upgrades) do
        if not upgrade.collected and dist(px, py, upgrade.x + 24, upgrade.y + 24) < 60 then
            upgrade.collected = true
            game.hookLevel = math.max(game.hookLevel, upgrade.level)
            playSound("discovery"); game.shake = .25
            addMessage(HOOK_NAMES[game.hookLevel] .. " — " .. (game.hookLevel == 2 and "el hierro recuerda distancias mayores." or (game.hookLevel == 3 and "algunas runas deciden mostrarse." or "lo invisible deja de fingir que no existe.")), 7)
            Save.write(game)
        end
    end
    for _, secret in ipairs(game.secrets) do
        if not secret.collected and dist(px, py, secret.x + 24, secret.y + 24) < 54 then
            secret.collected = true; game.secretsFound = game.secretsFound + 1
            playSound("discovery"); addMessage("SECRETO " .. game.secretsFound .. "/" .. #game.secrets .. " — Restos de alguien que también respondió al canto.", 5)
            Save.write(game)
        end
    end
end

local function updateDebris(dt)
    for i = #game.debris, 1, -1 do
        local d = game.debris[i]
        d.life = d.life - dt
        d.vy = d.vy + GRAVITY * .5 * dt
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        if d.life <= 0 then table.remove(game.debris, i) end
    end
    Particles.update(game.fx, dt)
end

local function updateIntro(dt)
    local intro = game.intro
    intro.t = intro.t + dt
    if intro.t > .82 and not intro.broken then
        intro.broken = true
        intro.flash = .18
        game.shake = 1.05
        playSound("collapse")
        playSound("deepRumble", .006)
        playSound("explosionAir")
        playSound("stoneRain")
        for ty, row in ipairs(map) do
            for tx = 1, #row do
                if tileAt(tx, ty) == "W" then
                    setTile(tx, ty, ".")
                    for _ = 1, 15 do
                        game.debris[#game.debris + 1] = {
                            x = (tx - .5) * TILE, y = (ty - .5) * TILE,
                            vx = 55 + math.random() * 390,
                            vy = -70 - math.random() * 310,
                            life = 1.35 + math.random() * 1.0
                        }
                    end
                end
            end
        end
    end
    intro.flash = math.max(0, (intro.flash or 0) - dt)
    if intro.t > 1.48 and intro.t < 3.28 then
        local walk = clamp((intro.t - 1.48) / 1.8, 0, 1)
        local smooth = walk * walk * (3 - 2 * walk)
        game.player.x = lerp(intro.startX, intro.endX, smooth)
        game.player.facing = 1
        game.player.introShy = true
        game.player.walkBlend = 1
        game.player.walkCycle = game.player.walkCycle + dt * 8
        intro.stepTimer = (intro.stepTimer or 0) - dt
        if intro.stepTimer <= 0 then
            intro.stepTimer = .28
            playSound("step")
        end
    end
    updateDebris(dt)
    if intro.t > 3.68 then
        game.player.introShy = false
        game.intro = nil
        game.player.grounded=true
        game.player.vx,game.player.vy=0,0
        game.dialogue={speaker="EXPLORADOR",text="La voy a encontrar, cueste lo que cueste.",revealed=0,clock=0,voiceIndex=0,complete=false}
    end
end

local function advanceDialogue()
    local dialogue=game.dialogue
    if not dialogue then return false end
    if dialogue.complete then
        game.dialogue=nil
        Audio.clearEchoes()
        addMessage("Detrás de la pared, el aire pronuncia el nombre de tu hija.",5)
    else
        dialogue.revealed=#dialogue.text
        dialogue.complete=true
    end
    return true
end

local function restoreSavedGame(data)
    if not data then return false end
    game.checkpoint = {x = data.x, y = data.y}
    game.hookLevel = data.hookLevel or 1
    game.runTime, game.deaths = data.runTime or 0, data.deaths or 0
    local journalKinds={"custodian","bat","blind","astral"}
    for i,kind in ipairs(journalKinds) do
        if game.bestiary and game.bestiary.entries[kind] then
            game.bestiary.entries[kind].stage=data.bestiary and data.bestiary[i] or 0
        end
    end
    if game.puzzles then game.puzzles.counterweightSolved=data.counterweight and true or false; game.puzzles.counterweight=game.puzzles.counterweightSolved end
    for i = 1, REGION_COUNT do
        game.mapUnlocked[i] = data.maps and data.maps[i] or false
        if game.clues[i] then game.clues[i].collected = data.clues and data.clues[i] or false end
        if game.secrets[i] then game.secrets[i].collected = data.secrets and data.secrets[i] or false end
    end
    game.cluesFound, game.secretsFound = 0, 0
    for _, item in ipairs(game.clues) do if item.collected then game.cluesFound = game.cluesFound + 1 end end
    for _, item in ipairs(game.secrets) do if item.collected then game.secretsFound = game.secretsFound + 1 end end
    for i = 1, 2 do game.rescued[i] = data.rescued and data.rescued[i] or false end
    for i, enemy in ipairs(game.enemies) do
        enemy.dead = data.enemies and data.enemies[i] or false
        enemy.sealed = data.seals and data.seals[i] or false
        if enemy.sealed and enemy.kind=="blind" then
            local seal=nearestMarker("Z",enemy.x+enemy.w/2,enemy.y+enemy.h/2,5)
            if seal then
                enemy.sealX,enemy.sealY=seal.x+TILE/2,seal.y+TILE/2
                enemy.x,enemy.y=enemy.sealX-enemy.w/2,enemy.sealY-enemy.h/2
            end
        end
        if enemy.dead then enemy.deathTimer = 20 end
    end
    for i, brittle in ipairs(game.breakables or {}) do
        brittle.broken = data.broken and data.broken[i] or false
        if brittle.broken then setTile(math.floor(brittle.x / TILE) + 1, math.floor(brittle.y / TILE) + 1, ".") end
    end
    for i, chime in ipairs(game.chimes or {}) do
        chime.broken = data.chimes and data.chimes[i] or false
        chime.ringing = 0
    end
    for i,plate in ipairs(game.puzzles and game.puzzles.plates or {}) do plate.locked=data.traps and data.traps[i] or false; plate.active=plate.locked end
    for i,enemy in ipairs(game.enemies or {}) do
        local plateIndex=data.bindings and data.bindings[i] or 0
        if plateIndex>0 and game.puzzles.plates[plateIndex] then
            enemy.boundPlate=game.puzzles.plates[plateIndex]; enemy.trapTimer=0; enemy.trappedTime=1
        end
    end
    -- Compatibilidad con guardados anteriores a la persistencia de trampas.
    if data.counterweight and not data.bindings then
        local plateIndex=1
        for _,enemy in ipairs(game.enemies or {}) do
            if enemy.kind=="custodian" and regionForRow(math.floor(enemy.y/TILE)+1)==2 and game.puzzles.plates[plateIndex] then
                local plate=game.puzzles.plates[plateIndex]
                plate.locked,plate.active=true,true
                enemy.boundPlate=plate; enemy.trapTimer=0; enemy.trappedTime=1
                plateIndex=plateIndex+1
                if plateIndex>2 then break end
            end
        end
    end
    loadCheckpoint()
    return true
end

function love.load(reuseSounds)
    local retainedSounds=reuseSounds==true and game.sounds or nil
    if reuseSounds==true then map=World.build(); game={} end
    love.graphics.setDefaultFilter("nearest", "nearest")
    math.randomseed(os.time())
    game.font = love.graphics.newFont(18)
    game.smallFont = love.graphics.newFont(14)
    game.titleFont = love.graphics.newFont(36)
    game.logoFont = love.graphics.newFont(58)
    game.uiCanvas = love.graphics.newCanvas(DESIGN_W,DESIGN_H)
    game.settings = Settings.load()
    Input.bindings.load()
    Configuration.open()
    if retainedSounds then game.sounds=retainedSounds
    else game.sounds, game.audioLoader = Audio.beginLoad(game.settings) end
    game.loading = not retainedSounds
    game.loadingProgress = 0
    game.loadingReveal = 0
    game.anchors = anchors()
    game.dust = makeDust(150)
    game.debris = {}
    game.enemyMarks = {}
    game.reinforcedDamage = {}
    game.fx = {}
    game.camera = {x = 0, y = 0}
    game.shake = 0
    game.hitstop = 0
    game.message = "Descendé siguiendo las marcas. Mové el mouse para apuntar el gancho."
    game.messageTimer = 6
    game.foundDrawing = false
    game.taughtHookJump = false
    game.taughtMantle = false
    game.tutorial = {walk = false, hook = false, chain = false, refuge = false, arena = false}
    game.zoneName = "BOCA DE LA MINA"
    game.won = false
    game.winTimer = 0
    game.runTime = 0
    game.deaths = 0
    game.zoneReveal = 0
    game.depthTransition = nil
    game.currentRegion = 1
    game.encounterSeen, game.encounterTitle = {}, nil
    game.started = false
    game.titleIndex = 1
    game.titleTransition = nil
    game.newGameConfirm = false
    game.controllerNotice = nil
    game.preparation = nil
    game.paused = false
    game.dialogue = nil
    game.hudActivated = false
    game.hudReveal = 0
    game.lightFlashPulse = 0
    game.lightRechargePulse = 0
    game.saveNotice = 0
    game.pauseIndex = 1
    game.mouseUsed = false
    game.selectedAnchor = nil
    game.caveAmbience={timer=14+math.random()*12,last=nil}
    game.astralDefeatFlash=0
    game.mapOpen = false
    game.mapPage = "map"
    game.mapUnlocked = {}; for i=1,REGION_COUNT do game.mapUnlocked[i]=false end
    game.mapFragments = findChars("M")
    for _, fragment in ipairs(game.mapFragments) do
        fragment.region = regionForRow(math.floor(fragment.y / TILE) + 1)
        fragment.collected = false
    end
    game.clues, game.rescues, game.upgrades, game.secrets = findChars("D"), findChars("N"), findChars("U"), findChars("K")
    game.breakables = findChars("B")
    for _, brittle in ipairs(game.breakables) do brittle.broken = false end
    game.chimes = findChars("T")
    for _, chime in ipairs(game.chimes) do chime.broken, chime.ringing = false, 0 end
    game.cluesFound, game.secretsFound, game.rescued, game.hookLevel = 0, 0, {}, 1
    game.puzzles = Puzzles.create(findChars)
    game.clueView, game.nearClueIndex = nil, nil
    for _, item in ipairs(game.clues) do item.collected = false end
    for _, item in ipairs(game.rescues) do item.collected = false end
    for index, item in ipairs(game.upgrades) do item.collected = false; item.level = index + 1 end
    for _, item in ipairs(game.secrets) do item.collected = false end
    local sx, sy = findChar("S")
    -- S sits one tile above the entrance floor. Start already planted on it so
    -- the playable character does not drop a few pixels after the cinematic.
    game.checkpoint = {x = sx, y = sy + TILE - 42}
    loadCheckpoint()
    game.refuges = findChars("C")
    game.enemies = Enemies.fromWorld(findChars,TILE)
    game.bestiary = Bestiary.create()
    game.savedData = Save.load()
end

local function returnToTitle()
    love.audio.stop()
    if Input.joystick then pcall(function() Input.joystick:setVibration(0,0) end) end
    love.load(true)
end

local function updateCaveAmbience(dt)
    local ambience=game.caveAmbience
    if not ambience then return end
    ambience.timer=ambience.timer-dt
    if ambience.timer>0 then return end
    local choices={"caveDrop","caveDrop","cavePebble","caveGroan","caveAir"}
    local sound=choices[math.random(#choices)]
    if sound==ambience.last then sound=choices[(math.random(#choices-1)%#choices)+1] end
    ambience.last=sound
    playSound(sound,sound=="caveDrop" and .16 or .06)
    -- El silencio es la capa principal. Incluso el próximo evento desconoce
    -- cuándo llegará; algunos huecos superan ampliamente el medio minuto.
    ambience.timer=12+math.random()*18+(math.random()<.22 and math.random()*18 or 0)
end

local function startMineIntro()
    game.player.x = -70
    game.player.grounded = true
    game.intro = {
        t = 0, rumbled = false, broken = false,
        startX = -70, endX = 3.2 * TILE,
        stepTimer = 0
    }
    game.messageTimer = 0
end

local function startNewGame()
    Save.clear(); game.savedData = nil
    game.started = true
    game.titleTransition = nil
    game.intro = nil
    game.travel = nil
    game.preparation = nil
    game.controllerNotice = {t=0,leaving=false,fade=0}
    game.messageTimer = 0
    game.hudActivated,game.hudReveal=false,0
end

local function dismissControllerNotice()
    local notice=game.controllerNotice
    if notice and notice.t>.28 then notice.leaving=true end
end

local function beginTitleDissolve()
    if game.titleTransition then return end
    local shards = {}
    for i = 1, 30 do
        local angle = (i / 30) * math.pi * 2 + math.random() * .18
        local radius = 42 + (i % 3) * 66 + math.random() * 18
        shards[i] = {
            angle = angle, radius = radius,
            speed = 42 + math.random() * 105,
            spin = (math.random() * 2 - 1) * 3.2,
            size = 3 + math.random() * 6,
            phase = math.random() * math.pi * 2
        }
    end
    game.titleTransition = {t = 0, shards = shards}
    playSound("discovery", .025)
end

local function updateTitleTransition(dt)
    local transition = game.titleTransition
    if not transition then return end
    transition.t = transition.t + dt
    if transition.t >= 1.45 then startNewGame() end
end

local function updateTravel(dt)
    local travel = game.travel
    if not travel then return end
    travel.t = travel.t + dt
    local progress = travel.t / travel.duration
    if travel.cue == 0 and progress > .3 then
        travel.cue = 1
        playSound("travelWhoosh", .018)
        playSound("forestRush", .018)
        playSound("branchPass", .035)
    elseif travel.cue == 1 and progress > .64 then
        travel.cue = 2
        playSound("travelWhoosh", .014)
        playSound("timberGroan", .025)
        playSound("mineApproach", .018)
    elseif travel.cue == 2 and progress > .86 then
        travel.cue = 3
        playSound("tunnelRush", .012)
        playSound("tunnelPulse", .016)
        playSound("deepWhisper", .022)
    end
    if travel.t >= travel.duration then
        game.travel = nil
        startMineIntro()
    end
end

local function updatePreparation(dt)
    local prep=game.preparation
    if not prep then return end
    prep.t=prep.t+dt
    if prep.cue==0 and prep.t>.72 then
        prep.cue=1; playSound("cloth",.025); playSound("discovery",.012)
    elseif prep.cue==1 and prep.t>1.72 then
        prep.cue=2; playSound("cloth",.018)
    elseif prep.cue==2 and prep.t>2.48 then
        prep.cue=3; playSound("hook",.025); playSound("gearJingle",.02)
    elseif prep.cue==3 and prep.t>3.62 then
        prep.cue=4; playSound("pick",.035)
    elseif prep.cue==4 and prep.t>4.08 then
        prep.cue=5; playSound("deepRumble",.005)
    end
    if prep.t>=prep.duration then
        game.preparation=nil
        game.travel={t=0,duration=5.2,cue=0}
        playSound("cityRush",.012)
        playSound("cityDrone",.008)
    end
end

function love.keypressed(key)
    if not Input.gamepadDispatch then Input.noteKeyboard() end
    if game.paused then Configuration.key(game,key); return end
    local p = game.player
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        return
    end
    if game.loading then return end
    if game.controllerNotice then dismissControllerNotice(); return end
    if game.preparation then return end
    if game.travel then return end
    if game.dialogue then
        if key=="return" or key==Input.bindings.values.keyboard.hook or key=="space" or key=="escape" then advanceDialogue() end
        return
    end
    if game.won then
        if key=="escape" or key=="return" then
            if game.winTimer>=Credits.start+1 then returnToTitle()
            elseif game.winTimer>=8.2 then game.winTimer=Credits.start end
        end
        return
    end
    if game.clueView then
        if key == "e" or key == "escape" or key == "tab" or key == "return" then game.clueView = nil end
        return
    end
    if not game.started and game.titleTransition then return end
    if not game.started and (key=="up" or key=="w" or key=="down" or key=="s") then
        game.newGameConfirm=false
        local count=game.savedData and 2 or 1
        local direction=(key=="up" or key=="w") and -1 or 1
        game.titleIndex=((game.titleIndex-1+direction)%count)+1
        playSound("hook",.02)
        return
    end
    if (key == "c" or (key == "return" and game.titleIndex==1)) and not game.started and game.savedData then
        game.started = true
        restoreSavedGame(game.savedData)
        game.hudActivated,game.hudReveal=true,1
        game.camera.x = clamp(game.player.x - DESIGN_W / 2, 0, MAP_W * TILE - DESIGN_W)
        game.camera.y = clamp(game.player.y - DESIGN_H * .42, 0, MAP_H * TILE - DESIGN_H)
        addMessage("CONTINUAR — El refugio todavía conserva tu calor.", 4)
        return
    end
    if (key == "n" or (key == "return" and (not game.savedData or game.titleIndex==2))) and not game.started then
        if game.savedData and not game.newGameConfirm then
            game.newGameConfirm=true
            playSound("alert",.018)
            return
        end
        beginTitleDissolve()
        return
    end
    if game.started and not Input.gamepadDispatch then
        if game.mapOpen then
            if key==Input.bindings.values.keyboard.map then game.mapOpen=false; return end
        else
            key=Input.keyboardKey(key)
            if not key then return end
        end
    end
    if game.mapOpen then
        if key=="q" or key=="e" then
            game.mapPage=game.mapPage=="bestiary" and "map" or "bestiary"
            playSound("cloth",.025)
            return
        end
        if game.mapPage=="bestiary" and (key=="left" or key=="a" or key=="right" or key=="d") then
            Bestiary.move(game.bestiary,(key=="left" or key=="a") and -1 or 1)
            playSound("cloth",.018)
            return
        end
        local galleryIndex = tonumber(key)
        if galleryIndex and galleryIndex >= 1 and galleryIndex <= #game.clues and game.clues[galleryIndex] and game.clues[galleryIndex].collected then
            game.clueView = galleryIndex
            return
        end
    end
    if key == "tab" and game.started and not game.intro then
        game.mapOpen = not game.mapOpen
        if game.mapOpen then game.mapPage=game.mapPage or "map" end
        return
    end
    local debugLevel = ({f1=1,f2=2,f3=3,f4=4,f5=5,f6=6})[key]
    if debugLevel and game.started and not game.intro then
        local spawn = DEBUG_SPAWNS[debugLevel]
        resetPlayer((spawn.x - 1) * TILE, (spawn.y - 1) * TILE - 44)
        game.checkpoint = {x = game.player.x, y = game.player.y}
        game.camera.x = clamp(game.player.x - DESIGN_W / 2, 0, MAP_W * TILE - DESIGN_W)
        game.camera.y = clamp(game.player.y - DESIGN_H * .42, 0, MAP_H * TILE - DESIGN_H)
        game.debugLevel = debugLevel
        game.hookLevel = math.max(game.hookLevel, math.min(debugLevel, #HOOK_NAMES))
        for i = 1, debugLevel do game.mapUnlocked[i] = true end
        addMessage("DEBUG — SALTO A " .. REGION_NAMES[debugLevel], 2.5)
        return
    end
    if key=="f9" and game.started and not game.intro then
        -- Epílogo aislado: prepara la puerta sin contaminar el guardado.
        for _,enemy in ipairs(game.enemies or {}) do enemy.dead=true; enemy.deathTimer=20 end
        game.puzzles.counterweightSolved,game.puzzles.counterweight=true,true
        for i=1,math.min(2,#game.puzzles.plates) do game.puzzles.plates[i].locked=true; game.puzzles.plates[i].active=true end
        game.hookLevel=#HOOK_NAMES
        for i=1,REGION_COUNT do game.mapUnlocked[i]=true end
        local lx,ly=findChar("L")
        resetPlayer(lx+58,ly-42)
        game.checkpoint={x=game.player.x,y=game.player.y}
        game.currentRegion=REGION_COUNT
        game.camera.x=clamp(lx-DESIGN_W*.5,0,MAP_W*TILE-DESIGN_W)
        game.camera.y=clamp(ly-DESIGN_H*.62,0,MAP_H*TILE-DESIGN_H)
        game.debugLevel=REGION_COUNT
        addMessage("DEBUG — EPÍLOGO PREPARADO. Acercate a la puerta y presioná E.",5)
        return
    end
    if key=="f7" and game.started and not game.intro then
        -- Corte aislado: posiciona a ambos protagonistas del plano y dispara
        -- directamente la expulsión final, sin exigir repetir los tres sellos.
        local boss
        for _,enemy in ipairs(game.enemies or {}) do
            if enemy.kind=="astral" then boss=enemy break end
        end
        if boss then
            boss.dead=false; boss.deathTimer=0; boss.impacts=3
            boss.usedSeals={}; boss.x,boss.y=boss.homeX,boss.homeY
            boss.astralDying=false; boss.astralDeathTime=0; boss.astralDeathCue=0
            local floorX,floorY=(36-1)*TILE,(133-1)*TILE-42
            resetPlayer(floorX,floorY)
            game.player.light=100; game.player.hp=game.player.maxHp; game.player.invuln=4
            game.hookLevel=#HOOK_NAMES; game.currentRegion=6; game.mapUnlocked[6]=true
            game.camera.x=clamp(((game.player.x+boss.x)*.5)-DESIGN_W*.5,0,MAP_W*TILE-DESIGN_W)
            game.camera.y=clamp(((game.player.y+boss.y)*.5)-DESIGN_H*.42,0,MAP_H*TILE-DESIGN_H)
            beginAstralDeparture(boss)
        end
        return
    end
    if key=="f8" and game.started and not game.intro then
        -- Boss laboratory: reset only the final encounter and place the player
        -- on the safe lower platform. It deliberately never writes the save.
        local boss
        for _,enemy in ipairs(game.enemies or {}) do
            if enemy.kind=="astral" then
                boss=enemy
                enemy.dead=false; enemy.deathTimer=0; enemy.impacts=0
                enemy.astralDying=false; enemy.astralDeathTime=0; enemy.astralDeathCue=0
                enemy.usedSeals={}; enemy.stun=0; enemy.repulse=0
                enemy.astralDash=0; enemy.astralWindup=0; enemy.astralDashCooldown=2.4
                enemy.x,enemy.y=enemy.homeX,enemy.homeY
                enemy.vx,enemy.vy=0,0
            end
        end
        local floorX,floorY=(36-1)*TILE,(133-1)*TILE-42
        resetPlayer(floorX,floorY)
        game.player.light=100; game.player.hp=game.player.maxHp
        game.player.invuln=1.8
        game.hookLevel=#HOOK_NAMES
        game.currentRegion=6
        game.mapUnlocked[6]=true
        game.camera.x=clamp(game.player.x-DESIGN_W*.5,0,MAP_W*TILE-DESIGN_W)
        game.camera.y=clamp(game.player.y-DESIGN_H*.42,0,MAP_H*TILE-DESIGN_H)
        game.debugLevel=6
        game.astralCinematic=nil
        game.astralVision=0
        addMessage("DEBUG — VIGÍA REINICIADO. Los tres sellos vuelven a esperar.",4)
        playSound("astralVoice",.08)
        return
    end
    if key == "f10" and game.started then game.debugOverlay = not game.debugOverlay return end
    if key == "escape" then
        if game.mapOpen then
            game.mapOpen = false
        else game.paused = true; Configuration.open() end
        return
    end
    if game.intro then return end
    if key == "r" then loadCheckpoint(); addMessage("Regresaste a la última fogata.", 2) return end
    if not game.started or game.paused or game.mapOpen then return end
    if game.astralCinematic then return end
    if key == "space" then
        if not jumpFromHook() then p.jumpBuffer = .12 end
    end
    if key == "e" then
        if game.nearClueIndex then
            game.clueView = game.nearClueIndex
            playSound("discovery", .015)
        elseif not tryFinalDoor() then
            if not tryHook() then
                p.hookBuffer = .32
                p.hookFailTimer=.48
                PlayerAnimation.trigger(p,"hookFail",.48,1)
                addMessage("Gancho preparado...", .7)
            end
        end
    end
    if key == "f" then breakWall() end
    if key == "q" then flashLantern() end
    if key == "l" then
        p.lanternOn=not p.lanternOn
        playSound("roots",.03)
        if game.currentRegion==4 then
            Particles.emit(game.fx,{x=p.x+p.w/2,y=p.y+p.h/2,count=18,color=p.lanternOn and {.62,.78,.34} or {.2,.46,.25},speed=95,spread=math.pi*2,kind="dust",gravity=-22,drag=.3,life=.9,size=2.5})
        end
        addMessage(p.lanternOn and "La linterna despierta las raíces claras." or "En la oscuridad, otras raíces se distienden.",2.5)
    end
end

function love.keyreleased(key)
    if not Input.gamepadDispatch then key=Input.keyboardKey(key) end
    if key == "e" and game.settings and game.settings.holdToGrapple and game.player and game.player.hook then
        game.player.hook = nil
        game.player.releaseTimer = .24
        PlayerAnimation.trigger(game.player, "release", .24, 1)
        Particles.emit(game.fx, {x=game.player.x+game.player.w/2,y=game.player.y+game.player.h/2,count=7,color={.74,.6,.34},speed=105,kind="spark",gravity=100,life=.3})
        playSound("release")
    end
end


function love.mousemoved(_, _, dx, dy)
    -- Windows puede emitir pequeños movimientos fantasma del cursor. No deben
    -- cambiar el esquema de control ni el objetivo mientras usamos joystick.
    if math.abs(dx or 0) + math.abs(dy or 0) > 2 then
        Input.noteKeyboard()
        game.mouseUsed = true
    end
end

function love.mousepressed(_, _, button)
    Input.noteKeyboard()
    if game.controllerNotice then dismissControllerNotice(); return end
    if game.dialogue and button==1 then advanceDialogue(); return end
    if button == 1 and game.started and not game.paused and not game.mapOpen and not game.clueView and not game.won and not game.intro and not game.travel then
        if not tryHook() then game.player.hookBuffer = .32 end
    elseif button == 2 and game.started and not game.paused and not game.mapOpen and not game.clueView and not game.won and not game.intro and not game.travel then
        game.mouseUsed = true
        breakWall()
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 30)
    Audio.update(dt)
    game.astralVision=math.max(0,(game.astralVision or 0)-dt)
    game.astralDefeatFlash=math.max(0,(game.astralDefeatFlash or 0)-dt*1.3)
    if game.depthTransition then
        game.depthTransition.t=game.depthTransition.t+dt
        if game.depthTransition.t>3.2 then game.depthTransition=nil end
    end
    if game.loading then
        -- Two buffers per frame keeps Windows responsive while the procedural
        -- soundscape is forged. The screen has already had time to draw first.
        local done,progress=Audio.loadStep(game.sounds,game.audioLoader,2)
        game.loadingProgress=progress
        if done then game.loading=false; game.loadingReveal=1 end
        return
    end
    game.loadingReveal=math.max(0,(game.loadingReveal or 0)-dt*1.8)
    Input.update()
    if not game.started and game.titleTransition then
        updateTitleTransition(dt)
        return
    end
    if not game.started or game.paused or game.mapOpen or game.clueView then return end
    if game.controllerNotice then
        local notice=game.controllerNotice
        notice.t=notice.t+dt
        if notice.leaving then
            notice.fade=math.min(1,notice.fade+dt*2.6)
            if notice.fade>=1 then
                game.controllerNotice=nil
                game.preparation={t=0,duration=4.65,cue=0}
            end
        end
        return
    end
    if game.preparation then
        updatePreparation(dt)
        return
    end
    if game.travel then
        updateTravel(dt)
        return
    end
    if game.hitstop > 0 then game.hitstop = math.max(0, game.hitstop - dt) return end
    if game.won then
        game.winTimer = game.winTimer + dt
        if Credits.finished(game.winTimer) then returnToTitle(); return end
        local lx=findChar("L")
        if game.winTimer<3 and lx then
            local walk=clamp(game.winTimer/2.6,0,1); walk=walk*walk*(3-2*walk)
            game.player.x=lerp(game.winStartX or game.player.x,lx+10,walk)
            game.player.walkBlend=1; game.player.walkCycle=game.player.walkCycle+dt*7; game.player.facing=1
        end
        if game.winCue == 0 and game.winTimer > 2 then game.winCue = 1; playSound("doorOpen", .02)
        elseif game.winCue == 1 and game.winTimer > 3.4 then game.winCue = 2; playSound("discovery", .02)
        elseif game.winCue == 2 and game.winTimer > 8 then
            game.winCue = 3; playSound("deepWhisper", .026); playSound("cloth",.016)
        end
        return
    end
    if game.intro then
        game.shake = math.max(0, game.shake - dt)
        updateIntro(dt)
        updateCamera(dt)
        return
    end
    if game.dialogue then
        local dialogue=game.dialogue
        dialogue.clock=dialogue.clock+dt
        local wanted=math.min(#dialogue.text,math.floor(dialogue.clock*31))
        while dialogue.revealed<wanted do
            dialogue.revealed=dialogue.revealed+1
            local char=dialogue.text:sub(dialogue.revealed,dialogue.revealed)
            if char:match("[%a]") and dialogue.revealed%2==0 then
                dialogue.voiceIndex=(dialogue.voiceIndex%3)+1
                playSound("humanVoice"..dialogue.voiceIndex,.055)
            end
        end
        dialogue.complete=dialogue.revealed>=#dialogue.text
        return
    end
    game.messageTimer = math.max(0, game.messageTimer - dt)
    game.zoneReveal = math.max(0, game.zoneReveal - dt)
    if game.encounterTitle then
        game.encounterTitle.timer = game.encounterTitle.timer - dt
        if game.encounterTitle.timer <= 0 then game.encounterTitle = nil end
    end
    game.runTime = game.runTime + dt
    updateCaveAmbience(dt)
    game.shake = math.max(0, game.shake - dt)
    updatePlayer(dt)
    game.hudReveal=lerp(game.hudReveal or 0,game.hudActivated and 1 or 0,1-math.pow(.012,dt))
    for _, chime in ipairs(game.chimes or {}) do chime.ringing = math.max(0,(chime.ringing or 0)-dt) end
    updateMapFragments()
    updateDiscoveries()
    game.selectedAnchor = aimedAnchor()
    for _, enemy in ipairs(game.enemies) do
        enemy.previousX,enemy.previousY=enemy.x,enemy.y
        updateEnemy(enemy, dt)
        refreshEnemyMood(enemy,dt)
    end
    local journalChange=Bestiary.update(game.bestiary,game.enemies,game.player,regionForRow,TILE,dt)
    if journalChange then
        playSound("cloth",.022); playSound("discovery",.008)
        addMessage("EL CUADERNO RECUERDA UN TRAZO NUEVO.",3.2)
        Save.write(game)
    end
    Puzzles.update(game.puzzles,dt,game,game.currentRegion,playSound,addMessage)
    if game.puzzleDirty then game.puzzleDirty=false; Save.write(game) end
    updateProgress()
    -- El ambiente no es un loop: son sucesos aislados separados por largos
    -- intervalos de silencio.
    updateCamera(dt)
    for _, d in ipairs(game.dust) do
        d.y = d.y + d.speed * dt
        d.x = d.x + math.sin(love.timer.getTime() * .4 + d.phase) * 4 * dt
        if d.y > #map * TILE then d.y = 0 end
    end
    updateDebris(dt)
end

local function dispatchGamepadKey(key)
    Input.gamepadDispatch = true
    love.keypressed(key)
    Input.gamepadDispatch = false
    Input.noteGamepad()
end

function love.gamepadpressed(_, button)
    Input.noteGamepad()
    if game.won then
        if button=="a" or button=="start" then dispatchGamepadKey("return") end
        return
    end
    if game.paused then Configuration.gamepad(game,button); return end
    if game.controllerNotice then dismissControllerNotice(); return end
    if game.dialogue then if button=="a" then advanceDialogue() end; return end
    if game.mapOpen and (button=="leftshoulder" or button=="rightshoulder") then
        dispatchGamepadKey("q"); return
    end
    if game.mapOpen and game.mapPage=="bestiary" and (button=="dpleft" or button=="dpright") then
        Bestiary.move(game.bestiary,button=="dpleft" and -1 or 1); playSound("cloth",.018); return
    end
    if (game.mapOpen or game.clueView) and button=="b" then dispatchGamepadKey("tab"); return end
    if game.clueView and button=="a" then dispatchGamepadKey("e"); return end
    if not game.started then
        if button=="a" then dispatchGamepadKey("return"); return end
        if button=="dpup" then dispatchGamepadKey("up"); return end
        if button=="dpdown" then dispatchGamepadKey("down"); return end
    end
    if game.mapOpen then
        if button=="start" or Input.gamepadKey(button)=="tab" then dispatchGamepadKey("tab") end
        return
    end
    if Input.gamepadKey(button)=="space" and game.started and not game.mapOpen and (game.nearClueIndex or nearFinalDoor()) then
        dispatchGamepadKey("e")
    else
        local key = Input.gamepadKey(button)
        if key then dispatchGamepadKey(key) end
    end
    Input.noteGamepad()
end

function love.gamepadreleased(_,button)
    local key=Input.gamepadKey(button)
    if key then Input.gamepadDispatch=true; love.keyreleased(key); Input.gamepadDispatch=false end
    Input.noteGamepad()
end

function love.quit()
    Audio.shutdown()
    if Input.joystick then
        pcall(function() Input.joystick:setVibration(0,0) end)
    end
    -- Devolver false confirma a LÖVE que el cierre no fue cancelado.
    return false
end

local function drawRock(x, y, kind, tx, ty)
    local seed = tx * 91 + ty * 47
    local palettes = {
        {{.12, .105, .12}, {.22, .19, .20}, {.29, .24, .22}},
        {{.075, .13, .135}, {.12, .27, .25}, {.25, .43, .36}},
        {{.12, .085, .17}, {.27, .17, .34}, {.48, .31, .54}},
        {{.055,.12,.075},{.12,.29,.17},{.3,.52,.31}},
        {{.09,.07,.15},{.23,.16,.32},{.48,.3,.56}},
        {{.09, .075, .19}, {.25, .19, .43}, {.57, .38, .72}}
    }
    local palette = palettes[regionForRow(ty)]
    if kind == "W" then
        love.graphics.setColor(.17, .13, .12); love.graphics.rectangle("fill", x, y, TILE, TILE)
        love.graphics.setColor(.48, .33, .22); love.graphics.rectangle("line", x + 2, y + 2, TILE - 4, TILE - 4)
        love.graphics.setColor(.66, .43, .22)
        love.graphics.line(x + 9, y + 3, x + 27, y + 19, x + 18, y + 29, x + 38, y + 45)
        love.graphics.setColor(.32, .3, .29)
        love.graphics.rectangle("fill", x + 5, y + 7, TILE - 10, 5)
        love.graphics.rectangle("fill", x + 5, y + TILE - 12, TILE - 10, 5)
        return
    end
    if kind == "R" then
        love.graphics.setColor(.17, .12, .1); love.graphics.rectangle("fill", x, y, TILE, TILE)
        love.graphics.setColor(.32, .18, .09); love.graphics.rectangle("fill", x + 3, y + 3, TILE - 6, TILE - 6)
        return
    end
    if kind == "B" then
        love.graphics.setColor(.19, .145, .12); love.graphics.rectangle("fill", x, y, TILE, TILE)
        love.graphics.setColor(.48, .34, .22); love.graphics.rectangle("line", x + 1, y + 1, TILE - 2, TILE - 2)
        love.graphics.setColor(.73, .5, .27, .78)
        love.graphics.line(x + 7, y + 3, x + 20, y + 15, x + 14, y + 25, x + 29, y + 34, x + 25, y + 46)
        love.graphics.line(x + 20, y + 15, x + 36, y + 10)
        love.graphics.line(x + 29, y + 34, x + 42, y + 27)
        love.graphics.setColor(.9, .65, .3, .12 + math.sin(love.timer.getTime() * 3 + tx) * .04)
        love.graphics.circle("fill", x + 24, y + 24, 20)
        return
    end
    love.graphics.setColor(kind == "X" and {.23, .16, .14} or palette[1])
    love.graphics.rectangle("fill", x, y, TILE, TILE)
    love.graphics.setColor(kind == "X" and {.43, .27, .20} or palette[2])
    love.graphics.rectangle("line", x + .5, y + .5, TILE - 1, TILE - 1)
    love.graphics.setColor(palette[3])
    love.graphics.rectangle("fill", x + (seed % 29), y + (seed % 17), 5, 3)
    if kind == "X" then
        local damage=game.reinforcedDamage[tostring(tx)] or 0
        love.graphics.setColor(.7, .48, .3)
        love.graphics.line(x + 10, y + 4, x + 27, y + 21, x + 19, y + 31, x + 38, y + 45)
        if damage>=1 then
            love.graphics.setColor(.095,.052,.04,.95)
            love.graphics.setLineWidth(2.2)
            love.graphics.line(x+27,y+21,x+37,y+14,x+45,y+17)
            love.graphics.line(x+19,y+31,x+8,y+37,x+3,y+34)
            love.graphics.setColor(.78,.43,.24,.42)
            for chip=1,4 do love.graphics.rectangle("fill",x+5+((seed+chip*13)%37),y+7+((seed+chip*19)%34),3+chip%3,2+chip%2) end
        end
        if damage>=2 then
            love.graphics.setColor(.055,.03,.025,1)
            love.graphics.setLineWidth(4)
            love.graphics.line(x+27,y+21,x+32,y+31,x+27,y+42,x+30,y+48)
            love.graphics.line(x+19,y+31,x+13,y+22,x+2,y+18)
            love.graphics.setColor(.025,.018,.017,.72)
            love.graphics.polygon("fill",x+22,y+25,x+30,y+19,x+34,y+30,x+27,y+37,x+18,y+33)
            love.graphics.setColor(.86,.47,.22,.25)
            love.graphics.circle("fill",x+25,y+29,13+math.sin(love.timer.getTime()*2+seed)*1.5)
        end
        love.graphics.setLineWidth(1)
    end
end

local function drawWorldDecoration(cam, region)
    local left, right = cam.x - 120, cam.x + DESIGN_W + 120
    if region == 1 then
        -- Restos de una mina real: vigas, cables, rieles y herramientas.
        love.graphics.setColor(.24, .14, .09, .65)
        for x = math.floor(left / 240) * 240, right, 240 do
            love.graphics.rectangle("fill", x + 28, cam.y - 30, 9, DESIGN_H + 70)
            love.graphics.line(x + 32, cam.y, x + 112, cam.y + 72, x + 190, cam.y)
        end
        love.graphics.setColor(.32, .25, .2, .5)
        for y = 5 * TILE, 22 * TILE, 7 * TILE do
            love.graphics.line(left, y + 33, right, y + 33)
            love.graphics.line(left, y + 41, right, y + 41)
            for x = math.floor(left / 70) * 70, right, 70 do love.graphics.line(x, y + 29, x + 12, y + 46) end
        end
        love.graphics.setColor(.36, .19, .08, .7)
        love.graphics.rectangle("fill", 33 * TILE, 17 * TILE, 72, 31, 3)
        love.graphics.setColor(.12, .09, .08); love.graphics.circle("fill", 33 * TILE + 15, 17 * TILE + 34, 8); love.graphics.circle("fill", 33 * TILE + 58, 17 * TILE + 34, 8)
    elseif region == 2 then
        -- La mampostería humana se mezcla con arcos y escritura anterior a la mina.
        love.graphics.setColor(.13, .36, .31, .17)
        for x = math.floor(left / 310) * 310, right, 310 do
            love.graphics.arc("line", x + 150, 35 * TILE, 105, math.pi, math.pi * 2)
            love.graphics.rectangle("line", x + 45, 35 * TILE, 210, 7 * TILE)
        end
        love.graphics.setColor(.28, .68, .52, .22)
        for x = math.floor(left / 150) * 150, right, 150 do
            local y = (25 + ((x / 150) % 17)) * TILE
            love.graphics.polygon("line", x + 18, y, x + 31, y + 18, x + 18, y + 36, x + 5, y + 18)
            love.graphics.circle("line", x + 18, y + 18, 6)
        end
        love.graphics.setColor(.08, .24, .2, .45)
        for x = math.floor(left / 190) * 190, right, 190 do
            love.graphics.line(x, 23 * TILE, x + 25, 29 * TILE, x - 12, 35 * TILE, x + 18, 44 * TILE)
        end
    elseif region == 3 then
        -- Columnas monumentales, puentes muertos y murales de una niña imposible.
        love.graphics.setColor(.25, .14, .34, .25)
        for x = math.floor(left / 330) * 330, right, 330 do
            love.graphics.rectangle("fill", x + 40, 45 * TILE, 76, 21 * TILE)
            love.graphics.rectangle("fill", x + 22, 45 * TILE, 112, 22)
            love.graphics.rectangle("fill", x + 22, 65 * TILE, 112, 22)
            love.graphics.setColor(.43, .24, .52, .23)
            for y = 47 * TILE, 64 * TILE, 90 do love.graphics.circle("line", x + 78, y, 19) end
            love.graphics.setColor(.25, .14, .34, .25)
        end
        love.graphics.setColor(.48, .3, .58, .27)
        love.graphics.rectangle("fill", 24 * TILE, 53 * TILE, 6 * TILE, 3 * TILE, 5)
        love.graphics.setColor(.74, .54, .68, .34)
        local muralX, muralY = 27 * TILE, 54 * TILE
        love.graphics.circle("line", muralX, muralY, 19)
        love.graphics.line(muralX, muralY + 19, muralX, muralY + 73, muralX - 25, muralY + 102)
        love.graphics.line(muralX, muralY + 73, muralX + 28, muralY + 102)
        love.graphics.line(muralX, muralY + 38, muralX - 33, muralY + 58)
        love.graphics.line(muralX, muralY + 38, muralX + 34, muralY + 58)
        love.graphics.setColor(.65, .4, .73, .18); love.graphics.line(left, 57 * TILE, right, 57 * TILE)
    else
        -- El Reino de los Dioses: piezas que flotan, reflejos y geometría contradictoria.
        local t = love.timer.getTime()
        for i = 1, 22 do
            local x = (i * 179) % (MAP_W * TILE)
            local y = (68 + (i * 7) % 22) * TILE + math.sin(t * .45 + i) * 20
            love.graphics.setColor(.52, .32, .82, .1 + (i % 4) * .025)
            love.graphics.push(); love.graphics.translate(x, y); love.graphics.rotate(t * .035 * (i % 2 == 0 and 1 or -1))
            love.graphics.rectangle("line", -18 - i % 3 * 6, -18, 36 + i % 3 * 12, 36)
            love.graphics.pop()
        end
        love.graphics.setColor(.72, .5, 1, .12)
        for x = math.floor(left / 260) * 260, right, 260 do
            love.graphics.arc("line", x + 110, 78 * TILE, 84, 0, math.pi)
            love.graphics.arc("line", x + 110, 84 * TILE, 84, math.pi, math.pi * 2)
            love.graphics.line(x + 26, 78 * TILE, x + 194, 84 * TILE)
        end
    end
end

local function markerCollected(list, x, y)
    for _, item in ipairs(list or {}) do if item.x == x and item.y == y then return item.collected end end
    return false
end

local function drawWorld()
    local cam = game.camera
    local region = regionForRow(math.floor((cam.y + DESIGN_H / 2) / TILE) + 1)
    local backgrounds = {{.045,.035,.055},{.052,.043,.035},{.018,.065,.07},{.018,.055,.03},{.055,.027,.08},{.025,.018,.095}}
    love.graphics.clear(backgrounds[region])
    local shakeX, shakeY = 0, 0
    if game.shake > 0 then
        local amount = game.settings.cameraShake
        shakeX, shakeY = math.random(-5, 5) * amount, math.random(-4, 4) * amount
    end
    love.graphics.push()
    love.graphics.translate(-math.floor(cam.x) + shakeX, -math.floor(cam.y) + shakeY)

    love.graphics.setColor(backgrounds[region])
    love.graphics.rectangle("fill", cam.x - 20, cam.y - 20, DESIGN_W + 40, DESIGN_H + 40)
    Atmosphere.background(cam,region,DESIGN_W,DESIGN_H,love.timer.getTime())
    MineDetail.background(cam,region,DESIGN_W,DESIGN_H,love.timer.getTime())
    if region >= 2 then
        local t = love.timer.getTime()
        for i = 1, 18 do
            local px = cam.x + ((i * 173 + region * 91) % DESIGN_W)
            local py = cam.y + ((i * 97) % DESIGN_H)
            if region == 2 or region == 3 then
                love.graphics.setColor(.18, .65, .52, .12)
                love.graphics.line(px - 8, py, px, py - 12, px + 8, py)
            elseif region == 4 or region == 5 then
                love.graphics.setColor(.62, .36, .75, .1)
                love.graphics.circle("line", px, py, 10 + i % 4 * 4)
            else
                love.graphics.setColor(.65, .42, 1, .12 + math.sin(t + i) * .04)
                love.graphics.circle("fill", px + math.sin(t * .7 + i) * 8, py, 2 + i % 3)
            end
        end
    end
    drawWorldDecoration(cam, region)
    Atmosphere.worldMotion(cam,region,DESIGN_W,DESIGN_H,love.timer.getTime())
    if cam.y < 300 then
        love.graphics.setColor(.075, .055, .065)
        love.graphics.rectangle("fill", 0, 0, #map[1] * TILE, 4 * TILE)
        love.graphics.setColor(.16, .105, .085)
        for x = 0, #map[1] * TILE, 192 do
            love.graphics.rectangle("fill", x + 22, 12, 8, 4 * TILE - 12)
            love.graphics.rectangle("fill", x + 22, 20, 145, 7)
        end
        love.graphics.setColor(.018, .014, .022)
        love.graphics.rectangle("fill", 0, TILE, TILE * 2.4, TILE * 2)
    end

    for _, d in ipairs(game.dust) do
        love.graphics.setColor(.63, .48, .36, .22)
        love.graphics.rectangle("fill", math.floor(d.x), math.floor(d.y), d.size, d.size)
    end

    local x1 = math.max(1, math.floor(cam.x / TILE))
    local x2 = math.min(#map[1], math.ceil((cam.x + DESIGN_W) / TILE) + 1)
    local y1 = math.max(1, math.floor(cam.y / TILE))
    local y2 = math.min(#map, math.ceil((cam.y + DESIGN_H) / TILE) + 1)
    local detailTime=love.timer.getTime()
    local surfaceLights=MineDetail.lights(game.refuges,tileAt,x1,x2,y1,y2,detailTime)
    for ty = y1, y2 do
        for tx = x1, x2 do
            local c, x, y = tileAt(tx, ty), (tx - 1) * TILE, (ty - 1) * TILE
            local puzzleTile=c=="r" or c=="o" or c=="p" or c=="i" or c=="m" or c=="g" or c=="b" or c=="s" or c=="n"
            if solidTile(c,tx,ty) and not puzzleTile then drawRock(x, y, c, tx, ty) end
            if c=="#" then MineDetail.rock(x,y,tx,ty,regionForRow(ty),tileAt,game.player,surfaceLights,detailTime,game.settings.flashIntensity) end
            if c=="A" or (c=="V" and game.hookLevel>=3) or c=="Z" or c=="T" then MineDetail.fixture(x,y,regionForRow(ty),c) end
            if c=="f" or c=="j" or c=="Y" or c=="r" or c=="o" or c=="p" or c=="i" or c=="m" or c=="g" or c=="b" or c=="s" or c=="n" then
                Puzzles.draw(game.puzzles,c,x,y,love.timer.getTime(),game.player)
            end
            if c == "A" or (c == "V" and game.hookLevel >= 3) then
                local selected = game.selectedAnchor and dist(game.selectedAnchor.x, game.selectedAnchor.y, x + TILE / 2, y + TILE / 2) < 4
                if selected then
                    local pulse = 18 + math.sin(love.timer.getTime() * 7) * 3
                    love.graphics.setColor(1, .68, .2, .18); love.graphics.circle("fill", x + TILE / 2, y + TILE / 2, pulse)
                end
                love.graphics.setColor(.15, .12, .13); love.graphics.circle("fill", x + TILE / 2, y + TILE / 2, 14)
                local normalColor = game.settings.highContrastAnchors and {1, .92, .18} or (c == "V" and {.55, .9, .82} or {.76, .53, .29})
                love.graphics.setColor(selected and {1, 1, .72} or normalColor); love.graphics.circle("line", x + TILE / 2, y + TILE / 2, selected and 12 or 10)
                love.graphics.line(x + 17, y + 24, x + 31, y + 24)
            elseif c == "?" then
                love.graphics.setColor(.72, .62, .42); love.graphics.rectangle("fill", x + 13, y + 8, 23, 30)
                love.graphics.setColor(.18, .1, .12); love.graphics.line(x + 17, y + 29, x + 25, y + 17, x + 32, y + 30)
            elseif c == "M" then
                local collected = false
                for _, fragment in ipairs(game.mapFragments) do
                    if fragment.x == x and fragment.y == y then collected = fragment.collected break end
                end
                if not collected then
                    love.graphics.setColor(.2, .8, .72, .14); love.graphics.circle("fill", x + 24, y + 24, 23 + math.sin(love.timer.getTime() * 4) * 3)
                    love.graphics.setColor(.74, .78, .62); love.graphics.rectangle("fill", x + 12, y + 10, 25, 29, 3)
                    love.graphics.setColor(.16, .35, .33); love.graphics.line(x + 17, y + 17, x + 31, y + 17, x + 20, y + 25, x + 32, y + 32)
                end
            elseif c == "Z" then
                local astral = regionForRow(ty) == 6
                local activated = false
                if astral then
                    for _, enemy in ipairs(game.enemies) do
                        if enemy.kind == "astral" and enemy.usedSeals and enemy.usedSeals[x] then activated = true break end
                    end
                end
                local pulse = .45 + math.sin(love.timer.getTime() * 3 + tx) * .15
                love.graphics.setColor(activated and {.9, .68, 1, .42} or (astral and {.8, .42, 1, .18} or {.2, .95, .62, .16}))
                love.graphics.circle("fill", x + 24, y + 38, 25)
                love.graphics.setColor(activated and {1, .88, 1, .95} or (astral and {.72, .45, 1, pulse} or {.32, .9, .58, pulse}))
                love.graphics.circle("line", x + 24, y + 38, 18)
                love.graphics.line(x + 10, y + 38, x + 24, y + 23, x + 38, y + 38, x + 24, y + 47, x + 10, y + 38)
            elseif c == "T" then
                local chime = chimeAtTile(tx,ty)
                if chime and chime.broken then
                    love.graphics.setColor(.31,.17,.27,.75)
                    love.graphics.polygon("fill",x+10,y+38,x+20,y+29,x+25,y+43)
                    love.graphics.polygon("fill",x+28,y+42,x+34,y+31,x+40,y+40)
                else
                    local ringing = chime and (chime.ringing or 0) > 0
                    local age=ringing and (2.4-(chime.ringing or 0)) or 99
                    local strike=ringing and math.exp(-age*2.15) or 0
                    local swing=math.sin(age*21)*.24*strike
                    local squash=math.sin(math.min(1,age/.18)*math.pi)*.15*strike
                    love.graphics.setColor(.35,.18,.32)
                    love.graphics.line(x+24,y,x+24+math.sin(swing)*10,y+11)
                    love.graphics.push()
                    love.graphics.translate(x+24,y+10)
                    love.graphics.rotate(swing)
                    love.graphics.scale(1+squash,1-squash*.55)
                    love.graphics.setColor(ringing and {.92,.43,.76} or {.52,.28,.47})
                    love.graphics.polygon("fill",-11,21,-6,2,6,-1,12,21)
                    -- Mineral ribs and chipped rim make the bell readable as an
                    -- object rather than a purple level marker.
                    love.graphics.setColor(.68,.36,.61,ringing and .95 or .7)
                    love.graphics.line(-6,3,-3,20,0,1,3,20,6,0)
                    love.graphics.setColor(.25,.09,.21)
                    love.graphics.line(-12,21,12,21)
                    love.graphics.line(-8,24,-2,22,4,24,10,21)
                    love.graphics.setColor(.12,.045,.11)
                    love.graphics.line(0,7,math.sin(age*25)*5*strike,21)
                    love.graphics.circle("fill",math.sin(age*25)*5*strike,22,3.8)
                    love.graphics.pop()
                    if ringing then
                        for ring=1,3 do
                            local wave=(age*155+ring*31)%105
                            love.graphics.setColor(.82,.38,.68,.22/ring)
                            love.graphics.circle("line",x+24,y+24,18+wave)
                        end
                        -- Deterministic crystal motes burst on contact and fall
                        -- away while the bell continues its damped oscillation.
                        if age<.62 then
                            for mote=1,10 do
                                local a=mote*2.17
                                local travel=age*(55+(mote%4)*18)
                                love.graphics.setColor(.95,.5,.83,(1-age/.62)*.75)
                                love.graphics.rectangle("fill",x+24+math.cos(a)*travel,y+23+math.sin(a)*travel+age*age*70,2+(mote%2),2+(mote%3))
                            end
                        end
                    end
                end
            elseif c == "D" and not markerCollected(game.clues, x, y) then
                love.graphics.setColor(.9, .82, .58, .14); love.graphics.circle("fill", x + 24, y + 24, 22)
                love.graphics.setColor(.78, .68, .48); love.graphics.rectangle("fill", x + 11, y + 8, 27, 32, 2)
                love.graphics.setColor(.28, .16, .18); love.graphics.circle("line", x + 24, y + 18, 5); love.graphics.line(x + 24, y + 23, x + 24, y + 34, x + 17, y + 38, x + 24, y + 34, x + 31, y + 38)
            elseif c == "N" and not markerCollected(game.rescues, x, y) then
                love.graphics.setColor(.45, .42, .38); love.graphics.rectangle("fill", x + 14, y + 18, 20, 24, 3)
                love.graphics.setColor(.68, .55, .44); love.graphics.circle("fill", x + 24, y + 13, 8)
                love.graphics.setColor(.82, .48, .18, .5); love.graphics.circle("line", x + 24, y + 24, 20 + math.sin(love.timer.getTime() * 4) * 2)
            elseif c == "U" and not markerCollected(game.upgrades, x, y) then
                love.graphics.setColor(.22, .76, .73, .16); love.graphics.circle("fill", x + 24, y + 24, 24)
                love.graphics.setColor(.52, .86, .8); love.graphics.circle("line", x + 24, y + 24, 13); love.graphics.line(x + 11, y + 24, x + 37, y + 24, x + 24, y + 11, x + 24, y + 37)
            elseif c == "K" and not markerCollected(game.secrets, x, y) then
                love.graphics.setColor(.72, .42, .85, .12); love.graphics.circle("fill", x + 24, y + 25, 18)
                love.graphics.setColor(.68, .5, .78, .55); love.graphics.polygon("line", x + 24, y + 9, x + 38, y + 35, x + 10, y + 35)
            end
        end
    end

    for _, refuge in ipairs(game.refuges) do
        local rx, ry = refuge.x, refuge.y
        local activation=refuge.activationPulse or 0
        local fireTime=love.timer.getTime()*7+rx*.01
        local flicker=math.sin(fireTime)*3+math.sin(fireTime*1.73)*1.8
        love.graphics.setColor(1, .38, .08, .18+activation*.2); love.graphics.circle("fill", rx + 40, ry - 6, 82+activation*55)
        if activation>0 then
            for ring=1,3 do
                love.graphics.setColor(1,.55,.12,activation*.28/ring)
                love.graphics.circle("line",rx+42,ry-8,30+ring*19+(1-activation)*55)
            end
        end
        love.graphics.setColor(1, .42+activation*.16, .08)
        love.graphics.polygon("fill", rx + 32-activation*4, ry + 4, rx + 42, ry - 27-flicker-activation*28, rx + 52+activation*4, ry + 4)
        love.graphics.setColor(1, .9, .42)
        love.graphics.polygon("fill", rx + 37, ry + 4, rx + 43, ry - 16-flicker*.45-activation*12, rx + 48, ry + 4)
        love.graphics.setColor(1,.3,.04,.55)
        love.graphics.polygon("fill",rx+33,ry+3,rx+37,ry-12+flicker*.35,rx+41,ry+4)
        love.graphics.setColor(.18, .13, .11); love.graphics.rectangle("fill", rx - 20, ry + 17, 47, 8, 2)
        love.graphics.setColor(.38, .25, .16); love.graphics.rectangle("fill", rx - 15, ry + 8, 16, 10, 2)
        love.graphics.setColor(.48, .42, .32); love.graphics.circle("line", rx + 58, ry + 4, 8); love.graphics.line(rx + 58, ry - 4, rx + 65, ry - 12)
        local refugeRegion = regionForRow(math.floor(ry / TILE) + 1)
        if refugeRegion >= 2 then
            love.graphics.setColor(.21, .17, .15); love.graphics.polygon("fill", rx - 48, ry + 23, rx - 27, ry - 18, rx - 6, ry + 23)
            love.graphics.setColor(.45, .32, .2); love.graphics.line(rx - 27, ry - 18, rx - 27, ry + 23)
        end
        if refugeRegion >= 3 then
            love.graphics.setColor(.35, .22, .42); love.graphics.rectangle("fill", rx + 70, ry - 26, 8, 49)
            love.graphics.setColor(.68, .45, .7); love.graphics.circle("line", rx + 74, ry - 33, 9)
        end
        for index = 1, 2 do
            if game.rescued[index] then
                local npcX = rx - 72 - (index - 1) * 27
                love.graphics.setColor(index == 1 and {.25, .42, .4} or {.42, .28, .46})
                love.graphics.rectangle("fill", npcX, ry - 18, 17, 31, 3)
                love.graphics.setColor(.66, .54, .44); love.graphics.circle("fill", npcX + 8, ry - 24, 7)
                if index == 1 then
                    love.graphics.setColor(.64, .7, .61); love.graphics.rectangle("line", npcX - 7, ry - 14, 10, 18)
                else
                    love.graphics.setColor(.58, .38, .68); love.graphics.circle("line", npcX + 22, ry - 8, 8)
                end
            end
        end
    end

    local lx, ly = findChar("L")
    local doorX,doorY,doorW,doorH=lx-86,ly-132,220,180
    local open=game.won and clamp(game.winTimer/2.8,0,1) or 0
    local ready=allThreatsDefeated()
    love.graphics.setColor(.025,.018,.045); love.graphics.rectangle("fill",doorX-12,doorY-15,doorW+24,doorH+15,8)
    love.graphics.setColor(.36,.23,.54); love.graphics.rectangle("line",doorX-12,doorY-15,doorW+24,doorH+15,8)
    love.graphics.setFont(game.smallFont); love.graphics.setColor(ready and {.78,.58,.95} or {.42,.32,.48})
    love.graphics.printf("QUIEN CRUCE ESTE UMBRAL\nYA NO SERÁ QUIEN DESCENDIÓ",doorX-65,doorY-62,doorW+130,"center")
    love.graphics.setColor(.008,.004,.018); love.graphics.rectangle("fill",doorX,doorY,doorW,doorH)
    for side=-1,1,2 do
        local leafX=side<0 and doorX-open*doorW*.48 or doorX+doorW/2+open*doorW*.48
        love.graphics.setColor(.105,.08,.15); love.graphics.rectangle("fill",leafX,doorY,doorW/2,doorH)
        love.graphics.setColor(ready and {.54,.31,.78} or {.25,.19,.3}); love.graphics.rectangle("line",leafX+3,doorY+3,doorW/2-6,doorH-6)
        for rune=1,3 do
            local rx=leafX+doorW/4+math.sin(rune*2.1)*24
            local ry=doorY+34+rune*36
            love.graphics.circle("line",rx,ry,7+rune*2); love.graphics.line(rx-15,ry,rx+15,ry)
        end
    end
    if open>0 then
        love.graphics.setColor(.64,.36,.95,.08+.18*open); love.graphics.rectangle("fill",doorX+doorW*(.5-open*.48),doorY,doorW*open*.96,doorH)
    end

    -- Los impactos permanecen durante la sesión: la sala conserva una memoria
    -- física de las persecuciones en vez de recomponerse detrás del jugador.
    for _,mark in ipairs(game.enemyMarks or {}) do
        love.graphics.setColor(.08,.045,.04,.48)
        love.graphics.ellipse("fill",mark.x,mark.y+1,23,4)
        love.graphics.setColor(.31,.17,.12,.48)
        for crack=1,5 do
            local a=mark.seed*.31+crack*1.19
            local length=9+(crack%3)*6
            love.graphics.line(mark.x,mark.y,mark.x+math.cos(a)*length,mark.y+math.sin(a)*length*.35)
        end
    end

    for _, e in ipairs(game.enemies) do
      if e.counterTarget and not e.boundPlate and not e.dead then
          local tx,ty=e.counterTarget.x+24,e.counterTarget.y+42
          love.graphics.setColor(.9,.62,.2,.22+.08*math.sin(love.timer.getTime()*8))
          love.graphics.setLineStyle("rough"); love.graphics.line(e.x+e.w/2,e.y+e.h/2,tx,ty); love.graphics.setLineStyle("smooth")
          love.graphics.circle("line",tx,ty,17+math.sin(love.timer.getTime()*6)*3)
      end
      EnemyRender.draw(e)
    end

    local p = game.player
    if game.selectedAnchor and not p.hook then
        love.graphics.setColor(.95, .69, .25, .26)
        love.graphics.setLineWidth(1)
        love.graphics.line(p.x + p.w / 2, p.y + p.h / 2, game.selectedAnchor.x, game.selectedAnchor.y)
    end
    if p.flashTimer > 0 then
        local radius = 55 + (1 - p.flashTimer / .42) * 250
        love.graphics.setColor(1, .88, .5, p.flashTimer / .42 * .65*(game.settings.flashIntensity or 1))
        love.graphics.setLineWidth(5)
        love.graphics.circle("line", p.x + p.w / 2, p.y + p.h / 2, radius)
        love.graphics.setLineWidth(1)
    end
    if p.hook then
        local currentLength = dist(p.x + p.w / 2, p.y + p.h / 2, p.hook.x, p.hook.y)
        Rope.draw(p, game.hookLevel, clamp(currentLength / math.max(1, p.hook.length), 0, 1))
    end
    local shadowDistance = 0
    for probe = 1, 180, 6 do
        if rectHitsSolid(p.x + 4, p.y + p.h + probe, p.w - 8, 2) then shadowDistance = probe break end
    end
    if shadowDistance > 0 then
        local shadowAlpha = clamp(.3 - shadowDistance / 850, .07, .3)
        love.graphics.setColor(.005, .004, .008, shadowAlpha)
        love.graphics.ellipse("fill", p.x + p.w / 2, p.y + p.h + shadowDistance - 2, clamp(13 - shadowDistance / 30, 6, 13), 3)
    end
    if not game.won or game.winTimer<2.65 then PlayerRender.draw(p) end
    for _, d in ipairs(game.debris) do
        love.graphics.setColor(.52, .32, .2, clamp(d.life, 0, 1))
        love.graphics.rectangle("fill", d.x, d.y, 5, 5)
    end
    Particles.draw(game.fx)

    Atmosphere.lightVolume(p,region,love.timer.getTime())
    Lighting.playerAura(p)
    Lighting.influence(p)
    if region == 6 then Lighting.astralDistortion(cam, DESIGN_W, DESIGN_H) end
    Atmosphere.foreground(cam,region,DESIGN_W,DESIGN_H,love.timer.getTime())
    love.graphics.pop()
end

local function drawMapOverlay()
    love.graphics.setColor(.008, .012, .025, .96)
    love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
    love.graphics.setFont(game.titleFont); love.graphics.setColor(.72, .84, .79)
    love.graphics.printf("CARTOGRAFÍA DE LAS PROFUNDIDADES", 0, 35, DESIGN_W, "center")
    love.graphics.setFont(game.smallFont)
    local cardW, cardH, scale = 360, 235, 5
    for region = 1, REGION_COUNT do
        local col, row = (region - 1) % 3, math.floor((region - 1) / 3)
        local bx, by = 70 + col * 405, 105 + row * 265
        love.graphics.setColor(.06, .07, .1); love.graphics.rectangle("fill", bx, by, cardW, cardH, 7)
        love.graphics.setColor(game.mapUnlocked[region] and {.35, .72, .63} or {.22, .23, .29})
        love.graphics.rectangle("line", bx, by, cardW, cardH, 7)
        love.graphics.print(string.format("%02d  %s", region, REGION_NAMES[region]), bx + 18, by + 14)
        if not game.mapUnlocked[region] then
            love.graphics.setColor(.38, .39, .44); love.graphics.printf("FRAGMENTO NO ENCONTRADO", bx, by + 112, cardW, "center")
        else
            local firstRow, lastRow = World.regionRows(region)
            local mx, my = bx + 48, by + 54
            for ty = firstRow, lastRow do
                for tx = 1, MAP_W do
                    local c = tileAt(tx, ty)
                    if solidTile(c,tx,ty) then
                        love.graphics.setColor(c == "X" and {.92, .38, .2} or {.32, .35 + region * .05, .43 + region * .055})
                        love.graphics.rectangle("fill", mx + (tx - 1) * scale, my + (ty - firstRow) * scale, scale, scale)
                    elseif c == "A" then
                        love.graphics.setColor(.95, .68, .23); love.graphics.rectangle("fill", mx + (tx - 1) * scale + 2, my + (ty - firstRow) * scale + 2, 3, 3)
                    elseif c == "C" then
                        love.graphics.setColor(1, .4, .1); love.graphics.rectangle("fill", mx + (tx - 1) * scale, my + (ty - firstRow) * scale, scale, scale)
                    end
                end
            end
            local pRegion = regionForRow(math.floor(game.player.y / TILE) + 1)
            if pRegion == region then
                love.graphics.setColor(.95, .95, .72)
                love.graphics.circle("fill", mx + (game.player.x / TILE) * scale, my + (game.player.y / TILE - firstRow + 1) * scale, 5)
            end
        end
        if game.clues[region] and game.clues[region].collected then
            love.graphics.setColor(.78, .66, .42); love.graphics.rectangle("fill", bx + cardW - 118, by + 12, 100, 24, 3)
            love.graphics.setColor(.12, .1, .12); love.graphics.printf(region .. "  VER DIBUJO", bx + cardW - 116, by + 17, 96, "center")
        end
    end
    love.graphics.setColor(.7, .72, .71)
    love.graphics.printf(Input.usingGamepad() and "LB / RB  CRIATURAS     VIEW o B  CERRAR" or "Q / E  CRIATURAS     TAB o ESC  CERRAR     1–5  DIBUJOS", 0, 672, DESIGN_W, "center")
end

local function drawClueOverlay(index)
    love.graphics.setColor(.006, .005, .012, .93); love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
    local px, py, pw, ph = 365, 72, 550, 550
    love.graphics.setColor(.72, .63, .45); love.graphics.rectangle("fill", px - 8, py - 8, pw + 16, ph + 16, 5)
    love.graphics.setColor(.82, .76, .62); love.graphics.rectangle("fill", px, py, pw, ph, 3)
    ClueDetails.draw(index,px,py)
    love.graphics.setColor(.2, .12, .14); love.graphics.setLineWidth(2.5)
    if index == 1 then
        love.graphics.polygon("line", px + 70, py + 330, px + 190, py + 150, px + 305, py + 330)
        love.graphics.rectangle("line", px + 176, py + 240, 42, 90)
        love.graphics.circle("line", px + 405, py + 240, 25)
        love.graphics.line(px + 405, py + 265, px + 405, py + 375, px + 360, py + 430, px + 405, py + 375, px + 450, py + 430)
        love.graphics.line(px + 405, py + 300, px + 350, py + 340, px + 405, py + 300, px + 462, py + 335)
    elseif index == 2 then
        for i = 1, 5 do
            local x, y = px + 80 + ((i * 91) % 390), py + 85 + i * 72
            love.graphics.circle("line", x, y, 22); love.graphics.line(x - 22, y, x + 38, y + 45)
        end
        love.graphics.line(px + 60, py + 450, px + 180, py + 350, px + 290, py + 430, px + 470, py + 180)
    elseif index == 3 then
        for i = 0, 4 do love.graphics.rectangle("line", px + 45 + i * 105, py + 80, 70, 350) end
        love.graphics.circle("line", px + 275, py + 205, 24)
        love.graphics.line(px + 275, py + 229, px + 275, py + 350, px + 225, py + 420, px + 275, py + 350, px + 325, py + 420)
        love.graphics.setColor(.5, .23, .3); love.graphics.circle("line", px + 275, py + 205, 48)
    elseif index == 4 then
        love.graphics.setFont(game.font)
        love.graphics.printf("NO ME LLEVARON\n\nESCUCHÉ EL CANTO\n\nY ELEGÍ BAJAR", px + 70, py + 135, pw - 140, "center")
        love.graphics.setColor(.38, .18, .25)
        love.graphics.line(px + 120, py + 410, px + 430, py + 410)
        love.graphics.printf("— tu hija", px + 80, py + 435, pw - 160, "right")
    else
        -- Un umbral rodeado de nudos: la imagen insinúa una condición común
        -- sin convertir la nota en una lista de tareas.
        love.graphics.rectangle("line",px+205,py+155,140,250)
        love.graphics.arc("line","open",px+275,py+155,70,math.pi,math.pi*2)
        for i=1,7 do
            local a=-math.pi*.85+(i-1)*(math.pi*1.7/6)
            local x,y=px+275+math.cos(a)*185,py+290+math.sin(a)*170
            love.graphics.push(); love.graphics.translate(x,y); love.graphics.rotate(a+i*.4)
            love.graphics.polygon("line",0,-16,13,-4,8,13,-8,13,-13,-4)
            love.graphics.circle("line",0,0,5)
            love.graphics.pop()
        end
        love.graphics.setFont(game.font)
        love.graphics.printf("EL UMBRAL NO CONOCE LLAVES",px+55,py+455,pw-110,"center")
    end
    love.graphics.setLineWidth(1)
    love.graphics.setFont(game.smallFont); love.graphics.setColor(.25, .16, .17)
    love.graphics.printf(CLUE_TEXTS[index] or "El dibujo no tiene palabras.", px + 35, py + ph - 72, pw - 70, "center")
    love.graphics.setColor(.8, .76, .7); love.graphics.printf(Input.usingGamepad() and "A o B para guardar el dibujo" or "E, TAB o ESC para guardar el dibujo", 0, 655, DESIGN_W, "center")
end

local function drawUI()
    local p = game.player
    love.graphics.setFont(game.smallFont)
    -- Explorer instrumentation: separate metal-framed modules replace the old
    -- overlapping text slab and keep long objectives inside their own column.
    love.graphics.setColor(0,0,0,.38); love.graphics.rectangle("fill",25,25,305,94,7)
    love.graphics.setColor(.025,.026,.038,.92); love.graphics.rectangle("fill",20,20,305,94,7)
    love.graphics.setColor(.31,.28,.25,.9); love.graphics.rectangle("line",20.5,20.5,304,93,7)
    love.graphics.setColor(.76,.62,.39); love.graphics.print("ESTADO",34,29)
    for i = 1, p.maxHp do
        local hx=34+(i-1)*31
        love.graphics.setColor(.22,.17,.18); love.graphics.rectangle("fill",hx,52,24,14,3)
        if i<=p.hp then
            love.graphics.setColor(.5,.03,.06,.3); love.graphics.rectangle("fill",hx-3,49,30,20,4)
            love.graphics.setColor(.82,.12,.15); love.graphics.rectangle("fill",hx,52,24,14,3)
            love.graphics.setColor(1,.35,.3,.65); love.graphics.rectangle("fill",hx+3,54,14,3,1)
        end
        love.graphics.setColor(.48,.34,.31); love.graphics.rectangle("line",hx,52,24,14,3)
    end
    local flashPulse=game.lightFlashPulse or 0
    local rechargePulse=game.lightRechargePulse or 0
    local hudTime=love.timer.getTime()
    love.graphics.setColor(flashPulse>0 and {1,.3,.24} or (rechargePulse>0 and {.55,.9,.68} or {.64,.62,.57}))
    love.graphics.print(rechargePulse>.18 and "LUZ  ↟" or "LUZ",34,82)
    if flashPulse>0 then
        love.graphics.setColor(.75,.035,.025,.18+flashPulse*.28)
        love.graphics.rectangle("fill",73,78,228,24,4)
    elseif rechargePulse>0 then
        love.graphics.setColor(.22,.82,.48,.08+rechargePulse*.12)
        love.graphics.rectangle("fill",73,78,228,24,4)
    end
    love.graphics.setColor(.09,.085,.105); love.graphics.rectangle("fill",78,84,218,12,2)
    for segment=1,10 do
        local amount=p.light/10
        local charged=segment<=amount
        if flashPulse>0 and not charged and segment>amount and segment<=amount+2.2 then
            love.graphics.setColor(1,.12,.08,.3+flashPulse*.65)
        elseif rechargePulse>0 and charged and segment==math.max(1,math.ceil(amount)) then
            local shine=.55+.45*math.sin(hudTime*13)
            love.graphics.setColor(.55+shine*.35,.78+shine*.18,.35+shine*.2)
        else
            love.graphics.setColor(charged and {.92,.63,.16} or {.18,.16,.19})
        end
        love.graphics.rectangle("fill",81+(segment-1)*21,86,17,8,1)
    end
    love.graphics.setColor(.42,.34,.26); love.graphics.rectangle("line",78,84,218,12,2)
    if flashPulse>0 then
        local drainX=81+clamp(p.light/100,0,1)*210
        love.graphics.setColor(1,.26,.12,flashPulse)
        love.graphics.line(drainX,81,drainX,100)
    elseif rechargePulse>0 then
        local scan=81+((hudTime*105)%210)
        love.graphics.setColor(.72,1,.58,.18+rechargePulse*.42)
        love.graphics.rectangle("fill",scan,84,3,12)
    end

    -- Controls are available in pause; the full legend accompanies arrival only.
    if (game.zoneReveal or 0)>0 or (game.hudReveal or 0)<1 then
    love.graphics.setColor(.018,.019,.028,.78); love.graphics.rectangle("fill",505,20,750,38,6)
    love.graphics.setColor(.28,.27,.29,.72); love.graphics.rectangle("line",505.5,20.5,749,37,6)
    love.graphics.setColor(.7,.68,.64)
    local controlLegend=(Input.usingGamepad() and "LS" or Input.label("left").."/"..Input.label("right")).." MOVER  ·  "..Input.label("jump").." SALTAR  ·  "..Input.label("hook").." GANCHO  ·  "..Input.label("flash").." FLASH  ·  "..Input.label("light").." LUZ  ·  "..Input.label("pick").." PICO  ·  "..Input.label("map").." MAPA"
    local legendScale=math.min(1,710/love.graphics.getFont():getWidth(controlLegend))
    love.graphics.push()
    love.graphics.translate(879,32)
    love.graphics.scale(legendScale,legendScale)
    love.graphics.printf(controlLegend,-359,0,718,"center")
    love.graphics.pop()
    else
        love.graphics.setColor(.65,.63,.67,.5)
        love.graphics.printf(Input.usingGamepad() and "START  ·  PAUSA / CONTROLES" or "ESC  ·  PAUSA / CONTROLES",950,24,300,"right")
    end

    if (game.zoneReveal or 0)>0 then
    love.graphics.setColor(0,0,0,.32); love.graphics.rectangle("fill",25,133,455,76,6)
    love.graphics.setColor(.025,.026,.038,.88); love.graphics.rectangle("fill",20,128,455,76,6)
    love.graphics.setColor(.3,.27,.25,.82); love.graphics.rectangle("line",20.5,128.5,454,75,6)
    love.graphics.setColor(.88,.61,.22); love.graphics.print(game.zoneName or "",34,139)
    love.graphics.setColor(.7,.69,.65); love.graphics.printf(game.objective or "",34,165,413,"left")
    else
        love.graphics.setColor(.73,.59,.38,.65)
        love.graphics.print(game.zoneName or "",25,128)
    end
    local unlocked = 0
    for i = 1, REGION_COUNT do if game.mapUnlocked[i] then unlocked = unlocked + 1 end end
    love.graphics.setColor(.025,.026,.038,.88); love.graphics.rectangle("fill",1015,72,240,78,6)
    love.graphics.setColor(.26,.35,.36,.85); love.graphics.rectangle("line",1015.5,72.5,239,77,6)
    love.graphics.setColor(.43,.82,.73); love.graphics.print("MAPA  "..unlocked.."/"..REGION_COUNT,1030,83)
    love.graphics.setColor(.57,.72,.76); love.graphics.printf(HOOK_NAMES[game.hookLevel],1030,107,207,"left")
    local echoes,totalEchoes=threatProgress()
    love.graphics.setColor(.45,.4,.52); love.graphics.print("ECOS",1030,129)
    for i=1,totalEchoes do
        local x=1090+(i-1)*20
        love.graphics.setColor(i<=echoes and {.76,.48,.94,.88} or {.22,.18,.28,.9})
        love.graphics.push(); love.graphics.translate(x,136); love.graphics.rotate(math.pi*.25)
        love.graphics.rectangle(i<=echoes and "fill" or "line",-5,-5,10,10,1)
        love.graphics.pop()
    end
    if (game.saveNotice or 0)>0 then
        local age=3.2-game.saveNotice
        local alpha=clamp(math.min(age*4,game.saveNotice*1.4),0,1)
        local pulse=1+math.sin(hudTime*7)*.08
        love.graphics.push(); love.graphics.translate(1230,232); love.graphics.scale(pulse,pulse)
        love.graphics.setColor(.08,.035,.018,.82*alpha); love.graphics.circle("fill",0,0,23)
        love.graphics.setColor(1,.48,.12,.22*alpha); love.graphics.circle("fill",0,0,29)
        love.graphics.setColor(1,.72,.26,alpha); love.graphics.polygon("fill",-7,9,0,-15,8,9,0,3)
        love.graphics.pop()
        love.graphics.setFont(game.smallFont); love.graphics.setColor(.9,.72,.4,alpha)
        love.graphics.printf("LA LLAMA RECUERDA",1015,265,240,"right")
    end
    Journal.hud(game.bestiary,game.currentRegion or 1,hudTime,game.smallFont)
    local e, enemyDistance
    for _, candidate in ipairs(game.enemies) do
        local d = dist(candidate.x, candidate.y, p.x, p.y)
        if not candidate.dead and d < 420 and (not enemyDistance or d < enemyDistance) then e, enemyDistance = candidate, d end
    end
    if e and (e.awake or enemyDistance < 350) then
        love.graphics.setColor(0,0,0,.32); love.graphics.rectangle("fill",1020,165,240,61,6)
        love.graphics.setColor(.025,.02,.035,.9); love.graphics.rectangle("fill",1015,160,240,61,6)
        love.graphics.setColor(.38,.23,.27,.82); love.graphics.rectangle("line",1015.5,160.5,239,60,6)
        local enemyName = e.kind == "blind" and "EL OYENTE" or (e.kind == "astral" and "VIGÍA ASTRAL" or (e.kind == "bat" and "EL RESONANTE" or "CUSTODIO " .. e.id))
        love.graphics.setColor(.76,.67,.58); love.graphics.printf(enemyName,1026,169,218,"left")
        for i = 1, 3 do
            love.graphics.setColor(i > e.impacts and {.68, .12, .16} or {.24, .62, .45})
            love.graphics.rectangle("fill",1028+(i-1)*68,197,56,6,2)
        end
    end
    if nearFinalDoor() and not game.won then
        love.graphics.setColor(.9, .64, .22)
        love.graphics.printf(Input.label("hook").."  CRUZAR EL UMBRAL", 440, 555, 400, "center")
    end
    if game.nearClueIndex and not game.clueView then
        love.graphics.setColor(.9, .72, .36)
        love.graphics.printf(Input.label("hook").."  OBSERVAR DIBUJO", 440, 580, 400, "center")
    end
    if game.messageTimer > 0 then
        local alpha = clamp(game.messageTimer, 0, 1)
        love.graphics.setColor(.025, .02, .035, .9 * alpha); love.graphics.rectangle("fill", 230, 620, 820, 66, 5)
        love.graphics.setColor(.88, .82, .69, alpha); love.graphics.setFont(game.font)
        love.graphics.printf(game.message, 255, 640, 770, "center")
    end
    if game.zoneReveal > 0 then
        local age = 3.2 - game.zoneReveal
        local alpha = clamp(math.min(age * 2.5, game.zoneReveal * 1.2), 0, 1)
        love.graphics.setColor(.015, .018, .03, .72 * alpha); love.graphics.rectangle("fill", 350, 225, 580, 105, 6)
        love.graphics.setColor(.78, .68, .92, alpha); love.graphics.setFont(game.smallFont)
        love.graphics.printf("ESTRATO " .. game.currentRegion, 350, 246, 580, "center")
        love.graphics.setFont(game.titleFont); love.graphics.setColor(.88, .82, .94, alpha)
        love.graphics.printf(REGION_NAMES[game.currentRegion], 350, 271, 580, "center")
    end
    if game.encounterTitle then
        local elapsed = 3.4 - game.encounterTitle.timer
        local alpha = clamp(math.min(elapsed * 3, game.encounterTitle.timer * 1.4), 0, 1)
        love.graphics.setColor(.008, .006, .014, .78 * alpha); love.graphics.rectangle("fill", 0, 480, DESIGN_W, 95)
        love.graphics.setFont(game.titleFont); love.graphics.setColor(.85, .35, .28, alpha)
        love.graphics.printf(game.encounterTitle.title, 0, 492, DESIGN_W, "center")
        love.graphics.setFont(game.smallFont); love.graphics.setColor(.76, .69, .66, alpha)
        love.graphics.printf(game.encounterTitle.subtitle, 0, 540, DESIGN_W, "center")
    end
    if game.debugOverlay then
        local row = math.floor((p.y + p.h / 2) / TILE) + 1
        local col = math.floor((p.x + p.w / 2) / TILE) + 1
        love.graphics.setColor(.015, .02, .028, .94); love.graphics.rectangle("fill", 955, 575, 300, 112, 5)
        love.graphics.setColor(.36, .9, .7); love.graphics.print("DEBUG DE NIVELES", 972, 588)
        love.graphics.setColor(.72, .76, .74)
        love.graphics.print("F1–F6: viajar  ·  F9: puerta final", 972, 612)
        love.graphics.print(string.format("Nivel %d  ·  columna %d  ·  fila %d", regionForRow(row), col, row), 972, 635)
        love.graphics.print(string.format("x %.0f  y %.0f  vx %.0f  vy %.0f", p.x, p.y, p.vx, p.vy), 972, 658)
    end
end

local function travelNoise(n)
    return (math.sin(n * 91.733) * 43758.5453) % 1
end

local function drawTravelStreaks(speed, alpha)
    love.graphics.setLineWidth(2)
    for i = 1, 24 do
        local seed = travelNoise(i * 3.17)
        local y = 45 + travelNoise(i * 7.9) * (DESIGN_H - 90)
        local x = (travelNoise(i * 13.1) * DESIGN_W - love.timer.getTime() * speed * (1 + seed)) % (DESIGN_W + 180) - 90
        love.graphics.setColor(.72,.68,.72,alpha * (.25 + seed * .5))
        love.graphics.line(x,y,x-35-speed*.035,y)
    end
    love.graphics.setLineWidth(1)
end

local function drawCityTravel(localT)
    love.graphics.setColor(.025,.02,.055); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    love.graphics.setColor(.12,.08,.17,.8); love.graphics.circle("fill",1020,115,58)
    -- Travel across several screen widths. World indices feed every random
    -- choice, so crossing a spacing boundary reveals new buildings instead of
    -- replaying the same short row.
    local cameraX = localT * 8800
    for layer=1,2 do
        local spacing=layer==1 and 154 or 116
        local parallax=layer==1 and .23 or .47
        local scroll=cameraX*parallax
        local first=math.floor(scroll/spacing)-2
        for slot=0,math.ceil(DESIGN_W/spacing)+4 do
            local worldIndex=first+slot
            local seed=worldIndex*7.13+layer*103
            local width=(layer==1 and 102 or 78)+travelNoise(seed+4)*(layer==1 and 75 or 58)
            local height=(layer==1 and 150 or 105)+travelNoise(seed+8)*(layer==1 and 290 or 230)
            local x=worldIndex*spacing-scroll
            local y=570-height
            love.graphics.setColor(layer==1 and {.045,.038,.068} or {.064,.048,.073})
            love.graphics.rectangle("fill",x,y,width,height)
            love.graphics.setColor(.7,.49,.2,layer==1 and .09 or .19)
            for wx=x+15,x+width-10,23 do
                for wy=y+18,535,29 do
                    if travelNoise(worldIndex*19+wx*.017+wy*.071)>.5 then love.graphics.rectangle("fill",wx,wy,6,9) end
                end
            end
        end
    end
    love.graphics.setColor(.035,.03,.045); love.graphics.rectangle("fill",0,570,DESIGN_W,150)
    love.graphics.setColor(.16,.12,.13); love.graphics.rectangle("fill",0,610,DESIGN_W,6)
    for x=-64-(cameraX*.82)%96,DESIGN_W+64,96 do
        love.graphics.setColor(.22,.16,.12); love.graphics.rectangle("fill",x,613,54,5)
    end
    drawTravelStreaks(610,.34)
end

local function drawForestTravel(localT)
    love.graphics.setColor(.008,.025,.027); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    local cameraX = localT * 3900
    -- Marfil lunar, separado del follaje. El halo conserva apenas el verde
    -- enfermo de la mina sin volver a pintar la luna como otro árbol.
    love.graphics.setColor(.3,.48,.4,.1); love.graphics.circle("fill",1040,105,92)
    love.graphics.setColor(.72,.79,.78,.72); love.graphics.circle("fill",1040,105,67)
    love.graphics.setColor(.9,.9,.82,.2); love.graphics.circle("fill",1023,88,44)
    love.graphics.setColor(.35,.49,.43,.22)
    love.graphics.circle("fill",1062,120,12); love.graphics.circle("fill",1016,126,8); love.graphics.circle("fill",1051,77,6)
    for layer = 1,3 do
        local spacing = 105-layer*15
        local shift = cameraX*(.35+layer*.24)%spacing
        for i=-2,math.ceil(DESIGN_W/spacing)+2 do
            local x=i*spacing-shift
            local seed=travelNoise(i+math.floor(cameraX/spacing)+layer*71)
            local base=625+layer*18
            local h=220+seed*250+layer*18
            love.graphics.setColor(.025+layer*.008,.07+layer*.012,.065+layer*.01,.72)
            love.graphics.rectangle("fill",x-6,base-h*.58,12,h*.58)
            love.graphics.polygon("fill",x,base-h,x-48-layer*8,base-h*.25,x+48+layer*8,base-h*.25)
            love.graphics.polygon("fill",x,base-h*.82,x-62-layer*9,base-h*.04,x+62+layer*9,base-h*.04)
        end
    end
    love.graphics.setColor(.018,.035,.03); love.graphics.rectangle("fill",0,625,DESIGN_W,95)
    drawTravelStreaks(510,.32)
end

local function drawMineApproach(localT)
    love.graphics.setColor(.018,.014,.025); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    local approach = clamp(localT,0,1)
    local mouthX = DESIGN_W/2 + (1-approach)*360
    local mouthY = 390
    local scale = .48 + approach*1.05
    love.graphics.setColor(.075,.06,.075)
    love.graphics.polygon("fill",0,650,mouthX-370*scale,mouthY+80,mouthX-190*scale,105,mouthX,34,mouthX+260*scale,145,DESIGN_W,570,DESIGN_W,720,0,720)
    love.graphics.setColor(.16,.12,.11)
    for i=1,18 do
        local a=i*2.39
        local rx=mouthX+math.cos(a)*(165+travelNoise(i)*150)*scale
        local ry=mouthY+math.sin(a)*(120+travelNoise(i+3)*95)*scale
        love.graphics.polygon("fill",rx-18*scale,ry+12*scale,rx,ry-20*scale,rx+25*scale,ry+15*scale)
    end
    love.graphics.setColor(.002,.002,.006)
    love.graphics.ellipse("fill",mouthX,mouthY,105*scale,145*scale)
    love.graphics.setColor(.42,.27,.13,.38)
    love.graphics.rectangle("fill",mouthX-125*scale,mouthY-145*scale,13*scale,300*scale)
    love.graphics.rectangle("fill",mouthX+112*scale,mouthY-145*scale,13*scale,300*scale)
    love.graphics.rectangle("fill",mouthX-125*scale,mouthY-150*scale,250*scale,14*scale)
    drawTravelStreaks(650,.42)
end

local function drawTunnelRush(localT)
    love.graphics.setColor(.002,.002,.006); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    local cx,cy=DESIGN_W/2,DESIGN_H/2
    for i=10,1,-1 do
        local pulse=(localT*5+i*.13)%1
        local radius=35+pulse*pulse*720
        love.graphics.setColor(.22,.15,.17,(1-pulse)*.18)
        love.graphics.setLineWidth(3+pulse*8)
        love.graphics.ellipse("line",cx,cy,radius*1.35,radius*.72)
    end
    love.graphics.setLineWidth(1)
    drawTravelStreaks(980,.58)
    local fade=clamp((localT-.72)/.28,0,1)
    love.graphics.setColor(0,0,0,fade); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
end

local function drawPreparationCinematicSingleShot()
    local prep=game.preparation
    if not prep then return end
    local t=prep.t
    local function phase(a,b)
        local p=clamp((t-a)/(b-a),0,1)
        return p*p*(3-2*p)
    end
    local photoLift=phase(.62,1.18)
    local photoHold=phase(1.18,1.5)*(1-phase(1.82,2.08))
    local photoStore=phase(1.72,2.14)
    local pickTake=phase(2.04,2.58)
    local pickSet=phase(2.52,2.86)
    local hookTake=phase(2.82,3.28)
    local hookSet=phase(3.2,3.55)
    local ready=phase(3.48,4.08)
    local fadeIn=phase(0,.42)

    love.graphics.setColor(.006,.006,.012,1)
    love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    -- Cuarto previo al descenso: una única lámpara sobre la mesa y polvo quieto.
    love.graphics.setColor(.055,.043,.04,fadeIn)
    love.graphics.rectangle("fill",0,88,DESIGN_W,544)
    for i=1,8 do
        local bx=80+i*151
        love.graphics.setColor(.15,.1,.07,.28*fadeIn)
        love.graphics.rectangle("fill",bx,90,9,542)
        love.graphics.line(bx-35,155,bx+42,226)
    end
    love.graphics.setColor(.82,.52,.2,.075*fadeIn)
    love.graphics.circle("fill",425,335,240)
    love.graphics.setColor(.16,.095,.055,.95*fadeIn)
    love.graphics.rectangle("fill",250,456,390,24,4)
    love.graphics.setColor(.075,.052,.045,.95*fadeIn)
    love.graphics.rectangle("fill",276,480,22,152); love.graphics.rectangle("fill",590,480,22,152)

    -- Explorador grande, de perfil. La panza respira incluso antes del primer paso.
    local cx,ground=800,474
    local breathe=math.sin(t*2.1)*2*(1-ready*.45)
    local lean=-.05+ready*.08
    love.graphics.push(); love.graphics.translate(cx,ground); love.graphics.rotate(lean)
    love.graphics.setColor(0,0,0,.32); love.graphics.ellipse("fill",2,8,88,15)
    love.graphics.setColor(.07,.075,.085); love.graphics.line(-26,-2,-32,38); love.graphics.line(24,-2,35,38)
    love.graphics.setLineWidth(9); love.graphics.line(-32,38,-50,41); love.graphics.line(35,38,52,40); love.graphics.setLineWidth(1)
    love.graphics.setColor(.16,.25,.26)
    love.graphics.polygon("fill",-49,-125,31,-132,65,-42,47,4,-43,4,-64,-54)
    love.graphics.setColor(.27,.36,.35)
    love.graphics.ellipse("fill",5+breathe*.35,-59,62+breathe,68)
    love.graphics.setColor(.36,.22,.1); love.graphics.rectangle("fill",-46,-25,100,13,3)
    love.graphics.setColor(.91,.57,.13); love.graphics.rectangle("fill",17,-28,19,19,3)
    love.graphics.setColor(.73,.59,.46); love.graphics.ellipse("fill",-7,-157,43,48)
    love.graphics.polygon("fill",25,-169,51,-158,27,-149); love.graphics.circle("fill",49,-158,7)
    love.graphics.setColor(.17,.085,.055); love.graphics.arc("fill",-5,-149,46,0,math.pi)
    love.graphics.polygon("fill",8,-145,39,-137,19,-123)
    love.graphics.setColor(.035,.03,.026); love.graphics.circle("fill",15,-169,3)
    love.graphics.setColor(.13,.17,.17); love.graphics.arc("fill",-8,-198,46,math.pi,math.pi*2)
    love.graphics.setColor(.29,.34,.33); love.graphics.rectangle("fill",-55,-201,101,10,3)
    love.graphics.setColor(1,.65,.16); love.graphics.circle("fill",27,-202,8)
    -- Correas vacías que van recibiendo las herramientas.
    love.graphics.setColor(.48,.3,.14); love.graphics.setLineWidth(5)
    love.graphics.line(-38,-112,36,-18); love.graphics.line(39,-112,-25,-20)
    love.graphics.setLineWidth(1)
    love.graphics.pop()

    -- Foto: de la mesa a la mirada, luego al bolsillo sobre el corazón.
    local photoX=lerp(374,690,photoLift)
    local photoY=lerp(419,276,photoLift)
    if photoStore>0 then photoX=lerp(photoX,762,photoStore); photoY=lerp(photoY,354,photoStore) end
    local photoScale=1+photoHold*.32-photoStore*.35
    love.graphics.push(); love.graphics.translate(photoX,photoY); love.graphics.rotate(-.11+photoLift*.08+photoStore*.16); love.graphics.scale(photoScale)
    love.graphics.setColor(0,0,0,.3*(1-photoStore)); love.graphics.rectangle("fill",-29,-39,62,83,3)
    love.graphics.setColor(.78,.71,.57,1-photoStore*.75); love.graphics.rectangle("fill",-32,-42,62,83,3)
    love.graphics.setColor(.31,.2,.22,1-photoStore); love.graphics.rectangle("fill",-25,-35,48,51)
    love.graphics.setColor(.69,.5,.4,1-photoStore); love.graphics.circle("fill",-1,-17,12)
    love.graphics.setColor(.12,.07,.09,1-photoStore); love.graphics.arc("fill",-1,-21,12,math.pi,math.pi*2)
    love.graphics.setColor(.34,.19,.22,1-photoStore); love.graphics.polygon("fill",-17,15,-12,-4,-1,3,11,-4,17,15)
    love.graphics.pop()

    -- Brazo delantero acompaña cada objeto para que no parezcan teletransportarse.
    local handX,handY=690,300
    if t<2.05 then handX,handY=photoX,photoY
    elseif t<2.82 then handX,handY=lerp(692,475,pickTake),lerp(344,412,pickTake)
    else handX,handY=lerp(700,552,hookTake),lerp(348,424,hookTake) end
    love.graphics.setColor(.7,.56,.43); love.graphics.setLineWidth(10)
    love.graphics.line(772,344,735,355,handX,handY); love.graphics.circle("fill",handX,handY,7)
    love.graphics.setLineWidth(1)

    -- Pico: descansa horizontal y termina cruzado sobre la espalda.
    local pickX,pickY=lerp(470,800,pickSet),lerp(426,338,pickSet)
    local pickAngle=lerp(-.12,-2.18,pickSet)
    love.graphics.push(); love.graphics.translate(pickX,pickY); love.graphics.rotate(pickAngle)
    love.graphics.setColor(.39,.22,.1); love.graphics.rectangle("fill",-43,-3,86,6,2)
    love.graphics.setColor(.65,.69,.67); love.graphics.setLineWidth(5); love.graphics.line(31,-15,45,0,31,15); love.graphics.setLineWidth(1)
    love.graphics.pop()

    -- Gancho: el aro se levanta de la mesa y encastra en el cinturón.
    local hookX=lerp(555,844,hookSet); local hookY=lerp(429,441,hookSet)
    love.graphics.setColor(.58,.67,.65); love.graphics.setLineWidth(3)
    love.graphics.circle("line",hookX,hookY,12); love.graphics.arc("line","open",hookX+11,hookY-2,10,-.6,1.9)
    love.graphics.setColor(.48,.31,.14); love.graphics.circle("fill",hookX-9,hookY+10,5); love.graphics.setLineWidth(1)

    -- Motas alrededor de la foto; al guardarla, la luz se concentra en el pecho.
    for i=1,12 do
        local a=i*.9+t*.18
        local r=42+i*4
        love.graphics.setColor(.92,.62,.25,.08*photoHold+.1*ready)
        love.graphics.circle("fill",photoX+math.cos(a)*r,photoY+math.sin(a)*r*.5,1+i%2)
    end
    love.graphics.setColor(.78,.7,.62,.34*fadeIn)
    love.graphics.setFont(game.smallFont)
    love.graphics.printf("ANTES DEL DESCENSO",0,604,DESIGN_W,"center")
    love.graphics.setColor(.005,.004,.01,clamp((t-4.08)/.5,0,1))
    love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
end

-- Montaje en viñetas. Cada objeto tiene su propio plano y sus propias manos;
-- no hay un brazo elástico intentando conectar toda la escena de una vez.
local function drawPreparationCinematic()
    local prep=game.preparation
    if not prep then return end
    local t=prep.t
    local shot=t<1.35 and 1 or (t<2.25 and 2 or (t<3.35 and 3 or 4))
    local shotStarts={0,1.35,2.25,3.35}
    local shotEnds={1.35,2.25,3.35,4.65}
    local localT=clamp((t-shotStarts[shot])/(shotEnds[shot]-shotStarts[shot]),0,1)
    local ease=localT*localT*(3-2*localT)
    local cut=clamp(math.min(localT*8,(1-localT)*9),0,1)

    love.graphics.setColor(.006,.005,.011,1); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    love.graphics.setColor(.72,.61,.44,.1*cut)
    love.graphics.polygon("fill",45,43,1230,55,1212,671,61,660)
    love.graphics.setColor(.025,.022,.03,1)
    love.graphics.polygon("fill",55,53,1220,65,1202,661,71,650)

    if shot==1 then
        -- Sobre el hombro: la foto ocupa el centro y el hombre sólo es una masa
        -- reconocible por la gorra, la barba y los dedos que tiemblan al borde.
        local lift=1-ease
        love.graphics.setColor(.13,.17,.18); love.graphics.polygon("fill",90,650,145,238,390,160,545,650)
        love.graphics.setColor(.11,.145,.15); love.graphics.arc("fill",270,203,122,math.pi,math.pi*2)
        love.graphics.setColor(.31,.36,.34); love.graphics.rectangle("fill",132,185,272,23,5)
        love.graphics.setColor(.12,.07,.05); love.graphics.polygon("fill",352,229,446,299,398,394,326,320)
        local fx,fy=760,340+lift*85
        love.graphics.setColor(0,0,0,.5); love.graphics.rectangle("fill",fx-176,fy-211,366,464,8)
        love.graphics.setColor(.78,.72,.61); love.graphics.rectangle("fill",fx-184,fy-220,366,464,7)
        love.graphics.setColor(.26,.17,.2); love.graphics.rectangle("fill",fx-158,fy-192,314,330,3)
        love.graphics.setColor(.69,.5,.4); love.graphics.circle("fill",fx,fy-72,72)
        love.graphics.setColor(.11,.065,.08); love.graphics.arc("fill",fx,fy-91,72,math.pi,math.pi*2)
        love.graphics.polygon("fill",fx-68,fy-96,fx-37,fy-150,fx-4,fy-104,fx+30,fy-151,fx+70,fy-89)
        love.graphics.setColor(.07,.05,.06); love.graphics.circle("fill",fx-23,fy-72,6); love.graphics.circle("fill",fx+23,fy-72,6)
        love.graphics.setColor(.4,.21,.22); love.graphics.arc("line","open",fx,fy-39,22,.2,math.pi-.2)
        love.graphics.setColor(.42,.23,.27); love.graphics.polygon("fill",fx-98,fy+137,fx-72,fy-18,fx,fy+24,fx+74,fy-18,fx+100,fy+137)
        -- El borde conserva apenas una marca privada y gastada: la foto sugiere
        -- el vínculo sin explicar qué ocurrió ni decirle al jugador qué sentir.
        love.graphics.setColor(.25,.17,.14,.42); love.graphics.setLineWidth(2)
        love.graphics.line(fx-18,fy+194,fx-7,fy+187,fx+2,fy+196,fx+13,fy+185,fx+22,fy+191)
        love.graphics.setColor(.25,.17,.14,.18)
        love.graphics.line(fx-42,fy+207,fx+39,fy+205)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(.7,.56,.43)
        love.graphics.ellipse("fill",fx-172,fy+154,30,49); love.graphics.ellipse("fill",fx+170,fy+154,30,49)
        for side=-1,1,2 do
            for finger=0,3 do love.graphics.rectangle("fill",fx+side*(144+finger*7)-4,fy+105+finger*2,9,62,4) end
        end

    elseif shot==2 then
        -- Primerísimo plano: pecho, bolsillo y una foto que desaparece entre tela.
        love.graphics.setColor(.11,.18,.19); love.graphics.polygon("fill",80,660,150,70,1125,88,1200,660)
        for i=0,12 do love.graphics.setColor(.27,.38,.37,.08); love.graphics.line(100+i*90,90,35+i*91,650) end
        love.graphics.setColor(.46,.29,.13); love.graphics.setLineWidth(15); love.graphics.line(210,80,940,660); love.graphics.setLineWidth(1)
        local pocketX,pocketY=720,390
        love.graphics.setColor(.075,.115,.12); love.graphics.polygon("fill",pocketX-155,pocketY-52,pocketX+158,pocketY-49,pocketX+120,pocketY+180,pocketX-110,pocketY+180)
        love.graphics.setColor(.34,.45,.43); love.graphics.setLineWidth(4); love.graphics.line(pocketX-145,pocketY-43,pocketX+150,pocketY-40); love.graphics.setLineWidth(1)
        local py=lerp(125,405,ease)
        love.graphics.setColor(.77,.7,.58,1-ease*.72); love.graphics.rectangle("fill",pocketX-75,py,150,190,4)
        love.graphics.setColor(.3,.19,.21,1-ease*.8); love.graphics.rectangle("fill",pocketX-61,py+14,122,116)
        love.graphics.setColor(.68,.5,.41,1-ease*.82); love.graphics.circle("fill",pocketX,py+54,30)
        love.graphics.setColor(.7,.56,.44); love.graphics.ellipse("fill",pocketX-92,py+87,42,65); love.graphics.ellipse("fill",pocketX+92,py+87,42,65)
        love.graphics.setColor(.95,.61,.2,.12+.16*ease); love.graphics.circle("fill",pocketX,pocketY+42,65+ease*45)

    elseif shot==3 then
        -- Plano de cintura: hebilla, rollo de cuerda y gancho entrando en su cierre.
        love.graphics.setColor(.17,.26,.26); love.graphics.ellipse("fill",650,250,430,310)
        love.graphics.setColor(.075,.1,.105); love.graphics.rectangle("fill",90,390,1100,265)
        love.graphics.setColor(.4,.23,.1); love.graphics.rectangle("fill",80,334,1120,58,8)
        love.graphics.setColor(.86,.53,.13); love.graphics.rectangle("fill",570,326,160,75,8)
        love.graphics.setColor(.16,.1,.06); love.graphics.rectangle("fill",595,343,110,42,4)
        local spoolX,spoolY=860,370
        love.graphics.setColor(.08,.09,.09); love.graphics.circle("fill",spoolX,spoolY,74)
        love.graphics.setColor(.5,.61,.58); love.graphics.setLineWidth(6)
        for r=24,59,11 do love.graphics.circle("line",spoolX,spoolY,r) end
        local hx=lerp(300,835,ease); local hy=lerp(510,410,ease)
        love.graphics.setColor(.62,.7,.67); love.graphics.setLineWidth(10)
        love.graphics.arc("line","open",hx,hy,55,-1.25,1.7); love.graphics.line(hx+16,hy+50,hx-13,hy+80)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(.7,.56,.43); love.graphics.ellipse("fill",hx-58,hy+32,72,51)
        love.graphics.setColor(.84,.58,.18,.45*ease); love.graphics.circle("line",spoolX,spoolY,82+math.sin(t*12)*5)

    else
        -- Contraplano completo: sólo al final entendemos la silueta. El pico
        -- sube al hombro y la puerta exterior abre una línea blanca vertical.
        local lift=clamp(localT/.58,0,1); lift=lift*lift*(3-2*lift)
        love.graphics.setColor(.018,.017,.022); love.graphics.rectangle("fill",72,64,1128,595)
        love.graphics.setColor(.7,.57,.42,.18); love.graphics.rectangle("fill",1090,90,7,530)
        love.graphics.setColor(.05,.055,.06); love.graphics.ellipse("fill",620,628,205,24)
        love.graphics.setColor(.035,.035,.04)
        love.graphics.circle("fill",625,217,75); love.graphics.ellipse("fill",612,424,118,174)
        love.graphics.polygon("fill",667,203,725,218,675,238)
        love.graphics.setColor(.12,.14,.14); love.graphics.arc("fill",620,180,82,math.pi,math.pi*2)
        love.graphics.rectangle("fill",532,174,178,15,4)
        love.graphics.setColor(.035,.035,.04); love.graphics.setLineWidth(34)
        love.graphics.line(570,525,548,620); love.graphics.line(658,526,684,620)
        love.graphics.line(535,331,475,455); love.graphics.setLineWidth(1)
        local angle=lerp(-1.32,-.12,lift)
        local px=lerp(450,618,lift); local py=lerp(520,275,lift)
        love.graphics.push(); love.graphics.translate(px,py); love.graphics.rotate(angle)
        love.graphics.setColor(.3,.18,.09); love.graphics.rectangle("fill",-150,-7,300,14,4)
        love.graphics.setColor(.55,.59,.58); love.graphics.setLineWidth(12); love.graphics.line(112,-45,160,0,112,45); love.graphics.setLineWidth(1)
        love.graphics.pop()
        love.graphics.setColor(.08,.08,.09); love.graphics.setLineWidth(26); love.graphics.line(667,320,720,375-lift*65); love.graphics.setLineWidth(1)
        love.graphics.setColor(.9,.78,.6,.15+ease*.65); love.graphics.rectangle("fill",1094,92,4+ease*22,526)
    end

    -- Cortes negros sesgados, como pasar violentamente de una viñeta a otra.
    local edge=1-cut
    love.graphics.setColor(.003,.002,.006,edge)
    love.graphics.polygon("fill",0,0,DESIGN_W*(.72+edge*.28),0,DESIGN_W*(.58+edge*.42),DESIGN_H,0,DESIGN_H)
    love.graphics.setColor(.003,.002,.006,clamp((t-4.35)/.3,0,1))
    love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
end

local function drawTravelCinematic()
    local progress=clamp(game.travel.t/game.travel.duration,0,1)
    if progress < .3 then
        drawCityTravel(progress/.3)
    elseif progress < .63 then
        drawForestTravel((progress-.3)/.33)
    elseif progress < .84 then
        drawMineApproach((progress-.63)/.21)
    else
        drawTunnelRush((progress-.84)/.16)
    end
    love.graphics.setColor(.004,.003,.009,.92)
    love.graphics.rectangle("fill",0,0,DESIGN_W,52)
    love.graphics.rectangle("fill",0,DESIGN_H-52,DESIGN_W,52)
end

local function drawIntroDialogue()
    local dialogue=game.dialogue
    if not dialogue then return end
    local t=love.timer.getTime()
    local x,y,w,h=78,486,1124,172

    -- Layered navy panel with a pale bevel: an intentional nod to classic
    -- cinematic JRPG dialogue without copying a specific UI asset.
    love.graphics.setColor(0,0,0,.55); love.graphics.rectangle("fill",x+8,y+10,w,h,8)
    love.graphics.setColor(.035,.055,.13,.97); love.graphics.rectangle("fill",x,y,w,h,7)
    love.graphics.setColor(.08,.12,.25,.95); love.graphics.rectangle("fill",x+8,y+8,w-16,h-16,5)
    love.graphics.setLineWidth(3); love.graphics.setColor(.72,.76,.84,.9); love.graphics.rectangle("line",x+3,y+3,w-6,h-6,7)
    love.graphics.setLineWidth(1); love.graphics.setColor(.25,.34,.58,.8); love.graphics.line(x+10,y+44,x+w-10,y+44)

    -- Close side-profile portrait, matching the procedural in-world design.
    local px,py=x+80,y+91
    love.graphics.setColor(.018,.025,.065); love.graphics.circle("fill",px,py,56)
    love.graphics.setColor(.22,.3,.31); love.graphics.polygon("fill",px-33,py+48,px-25,py+7,px+22,py+4,px+38,py+48)
    love.graphics.setColor(.74,.61,.49); love.graphics.ellipse("fill",px,py-15,27,31)
    love.graphics.polygon("fill",px+18,py-24,px+38,py-14,px+18,py-8)
    love.graphics.circle("fill",px+37,py-14,6)
    love.graphics.setColor(.19,.105,.07); love.graphics.arc("fill",px,py-9,29,0,math.pi)
    love.graphics.polygon("fill",px+5,py-9,px+29,py-5,px+17,py+5)
    love.graphics.setColor(.05,.04,.035); love.graphics.circle("fill",px+10,py-23,3)
    love.graphics.setColor(.15,.18,.18); love.graphics.arc("fill",px,py-38,30,math.pi,math.pi*2)
    love.graphics.setColor(.3,.35,.34); love.graphics.rectangle("fill",px-31,py-40,67,7,2)
    love.graphics.setColor(1,.68,.22); love.graphics.circle("fill",px+19,py-42,6)

    love.graphics.setFont(game.smallFont); love.graphics.setColor(.92,.73,.36)
    love.graphics.print(dialogue.speaker,x+158,y+15)
    love.graphics.setFont(game.font); love.graphics.setColor(.95,.95,1)
    love.graphics.printf(dialogue.text:sub(1,dialogue.revealed),x+158,y+68,w-205,"left")
    love.graphics.setFont(game.smallFont); love.graphics.setColor(.5,.58,.75)
    local dialoguePrompt
    if Input.usingGamepad() then
        dialoguePrompt=dialogue.complete and "A  CONTINUAR" or "A  COMPLETAR"
    else
        dialoguePrompt="ENTER / "..Input.label("hook")..(dialogue.complete and "  CONTINUAR" or "  COMPLETAR")
    end
    local promptRight=x+w-24
    local promptWidth=260
    local promptX=promptRight-promptWidth
    local promptY=y+h-31
    -- Cursor-gadget: un pequeño gancho de explorador ocupa el lugar de la
    -- clásica mano de selección y late solamente cuando la frase está lista.
    local bob=dialogue.complete and math.sin(t*7)*2 or 0
    local hookX=promptX-22+bob
    love.graphics.setColor(.82,.63,.27,dialogue.complete and .95 or .48)
    love.graphics.setLineWidth(2)
    love.graphics.line(hookX-12,promptY+8,hookX-2,promptY+8,hookX+5,promptY+14)
    love.graphics.arc("line","open",hookX+7,promptY+8,7,-.15,math.pi*1.38)
    love.graphics.line(hookX+3,promptY+14,hookX-1,promptY+19)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(.5,.58,.75)
    love.graphics.printf(dialoguePrompt,promptX,promptY,promptWidth,"right")
end

local function drawDaughterPhoto()
    local t=love.timer.getTime()
    love.graphics.push()
    love.graphics.translate(185,345)
    love.graphics.rotate(-.045+math.sin(t*.7)*.004)
    -- Worn instant-photo frame and its soft shadow.
    love.graphics.setColor(0,0,0,.42); love.graphics.rectangle("fill",-101,-143,214,298,5)
    love.graphics.setColor(.77,.72,.61); love.graphics.rectangle("fill",-108,-151,214,298,4)
    love.graphics.setColor(.18,.19,.18); love.graphics.rectangle("fill",-92,-135,182,211,2)
    -- The daughter is drawn like a remembered photograph, warmer than the mine.
    love.graphics.setColor(.32,.23,.25); love.graphics.rectangle("fill",-92,-135,182,211)
    love.graphics.setColor(.45,.31,.3,.55)
    for i=1,9 do love.graphics.line(-92, -125+i*22, 90, -142+i*24) end
    love.graphics.setColor(.15,.1,.12); love.graphics.ellipse("fill",0,-44,53,63)
    love.graphics.setColor(.72,.54,.43); love.graphics.circle("fill",0,-38,43)
    love.graphics.setColor(.12,.075,.09)
    love.graphics.arc("fill",0,-55,43,math.pi,math.pi*2)
    love.graphics.polygon("fill",-42,-58,-22,-93,-4,-65,16,-94,43,-53)
    love.graphics.setColor(.09,.065,.07)
    love.graphics.circle("fill",-14,-40,4); love.graphics.circle("fill",14,-40,4)
    love.graphics.setColor(.44,.24,.22); love.graphics.arc("line","open",0,-20,13,.25,math.pi-.25)
    love.graphics.setColor(.38,.22,.25); love.graphics.polygon("fill",-57,76,-43,10,0,-1,44,10,60,76)
    love.graphics.setColor(.68,.45,.28); love.graphics.polygon("fill",-38,4,0,25,39,4,29,37,0,48,-30,37)
    -- Creases, tape and a tiny handwritten reminder keep it physical.
    love.graphics.setColor(.56,.48,.34,.75); love.graphics.rectangle("fill",-36,-163,72,22,2)
    love.graphics.setColor(.24,.18,.16); love.graphics.setFont(game.smallFont)
    love.graphics.printf("SEGUÍ LA LUZ",-94,99,188,"center")
    love.graphics.setColor(.42,.34,.28,.5); love.graphics.line(-94,86,91,82); love.graphics.line(67,88,84,137)
    love.graphics.pop()
end

local function drawControllerNotice()
    local notice=game.controllerNotice
    if not notice then return end
    local t=notice.t
    local alpha=clamp(t*2.8,0,1)*(1-(notice.fade or 0))
    local breathe=math.sin(t*1.8)*3
    -- El mundo ya está cargado por debajo de esta placa. El fondo debe seguir
    -- siendo completamente opaco durante el fade para no revelar el nivel 1
    -- ni antes del aviso ni en el corte hacia el montaje de preparación.
    love.graphics.setColor(.005,.004,.011,1)
    love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)

    love.graphics.push()
    love.graphics.translate(DESIGN_W/2,DESIGN_H/2-34+breathe)
    love.graphics.setLineWidth(3)
    -- Silueta del mando, dibujada para no depender de una marca concreta.
    love.graphics.setColor(.13,.12,.17,.96*alpha)
    love.graphics.polygon("fill",-168,20,-145,-68,-88,-98,88,-98,145,-68,168,20,137,84,79,49,-79,49,-137,84)
    love.graphics.setColor(.66,.54,.72,.72*alpha)
    love.graphics.polygon("line",-168,20,-145,-68,-88,-98,88,-98,145,-68,168,20,137,84,79,49,-79,49,-137,84)
    love.graphics.setColor(.035,.03,.045,alpha)
    love.graphics.circle("fill",-77,-18,29); love.graphics.circle("fill",77,-18,29)
    love.graphics.setColor(.72,.61,.43,.9*alpha)
    love.graphics.rectangle("fill",-111,-28,66,18,3); love.graphics.rectangle("fill",-87,-52,18,66,3)
    love.graphics.circle("fill",92,-38,9); love.graphics.circle("fill",116,-14,9)
    love.graphics.setColor(.43,.3,.53,.9*alpha)
    love.graphics.circle("fill",68,-14,9); love.graphics.circle("fill",92,10,9)
    love.graphics.setColor(.48,.45,.5,.65*alpha)
    love.graphics.circle("line",-77,-18,18); love.graphics.circle("line",77,-18,18)
    love.graphics.setLineWidth(1)
    love.graphics.pop()

    -- Pico y gancho cruzan el encuadre como herramientas, no como ornamento UI.
    love.graphics.setLineWidth(7)
    love.graphics.setColor(.35,.2,.1,.72*alpha)
    love.graphics.line(185,590,405,174)
    love.graphics.setColor(.48,.53,.52,.76*alpha)
    love.graphics.line(357,174,405,174,441,211)
    love.graphics.setColor(.48,.53,.52,.72*alpha)
    love.graphics.arc("line","open",1072,550,48,-1.35,1.72)
    love.graphics.line(1083,596,1047,630)
    love.graphics.setColor(.31,.25,.17,.55*alpha)
    love.graphics.line(1038,521,851,175)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(game.font)
    love.graphics.setColor(.84,.77,.65,.92*alpha)
    love.graphics.printf("RECOMENDADO JUGAR CON JOYSTICK",0,470,DESIGN_W,"center")
    love.graphics.setFont(game.smallFont)
    love.graphics.setColor(.44,.39,.48,(.52+math.sin(t*3)*.14)*alpha)
    love.graphics.printf(Input.usingGamepad() and "PRESIONÁ CUALQUIER BOTÓN" or "PRESIONÁ CUALQUIER TECLA",0,518,DESIGN_W,"center")
end

local function drawTitleScreen()
    local t = love.timer.getTime()
    local transition = game.titleTransition
    local dissolve = transition and clamp(transition.t / 1.45, 0, 1) or 0
    local intact = 1 - clamp(dissolve * 1.45, 0, 1)
    -- Keep the mine hidden behind an opaque veil. The first revealed place is
    -- the city in the travel cinematic, never the already-loaded first room.
    love.graphics.setColor(.006,.005,.012,1); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)

    -- Una única runa lenta: no explica nada, sólo sugiere que algo observa.
    local cx,cy=DESIGN_W/2,DESIGN_H/2-8
    love.graphics.push(); love.graphics.translate(cx,cy); love.graphics.rotate(t*.08+dissolve*dissolve*.55)
    love.graphics.scale(1+dissolve*.13,1+dissolve*.13)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(.43,.27,.57,.055*intact)
    love.graphics.circle("line",0,0,190+math.sin(t*.35)*5)
    love.graphics.arc("line","open",0,0,164,t*.12,t*.12+4.65)
    for i=1,6 do
        local a=i*math.pi/3
        local x,y=math.cos(a)*176,math.sin(a)*176
        love.graphics.polygon("line",x,y-10,x+9,y+6,x,y+13,x-9,y+6)
    end
    love.graphics.setColor(.58,.36,.72,.075)
    love.graphics.line(-118,0,0,-118,118,0,0,118,-118,0)
    love.graphics.circle("line",0,0,42)
    love.graphics.pop(); love.graphics.setLineWidth(1)

    -- Al confirmar, la geometría deja de ser un sello y se vuelve polvo.
    if transition then
        for i, shard in ipairs(transition.shards) do
            local delay = (i % 6) * .025
            local life = clamp((transition.t - delay) / 1.15, 0, 1)
            local distance = shard.radius + shard.speed * life * life
            local angle = shard.angle + shard.spin * life * .32
            local x = cx + math.cos(angle) * distance
            local y = cy + math.sin(angle) * distance + life * life * 34
            local alpha = math.sin(math.min(1, life) * math.pi) * (1 - clamp((life - .72) / .28, 0, 1))
            love.graphics.push(); love.graphics.translate(x,y); love.graphics.rotate(angle+shard.phase+life*shard.spin)
            love.graphics.setColor(.67,.39,.87,.65*alpha)
            love.graphics.polygon("line",0,-shard.size,shard.size*.72,0,0,shard.size,-shard.size*.72,0)
            love.graphics.setColor(.9,.62,1,.22*alpha)
            love.graphics.circle("fill",0,0,shard.size*.34)
            love.graphics.pop()
        end
    end

    love.graphics.setColor(.88,.8,.66,intact); love.graphics.setFont(game.titleFont)
    love.graphics.printf("LAS",0,255,DESIGN_W,"center")
    love.graphics.setFont(game.logoFont)
    love.graphics.printf("PROFUNDIDADES",0,299,DESIGN_W,"center")

    local pulse=(.7+math.sin(t*2.2)*.18)*intact
    local options=game.savedData and {"CONTINUAR DESDE EL ÚLTIMO CHECKPOINT","PARTIDA NUEVA"} or {"PARTIDA NUEVA"}
    love.graphics.setFont(game.smallFont)
    for i,label in ipairs(options) do
        local selected=i==game.titleIndex
        love.graphics.setColor(selected and {.78,.64,.88,pulse} or {.34,.31,.4,.65*intact})
        local optionY=450+(i-1)*42
        love.graphics.printf(label,0,optionY,DESIGN_W,"center")
        if selected then
            -- Marcadores dibujados: no dependen de glifos que la fuente pixel
            -- pueda reemplazar por cuadrados vacíos.
            local halfWidth=game.smallFont:getWidth(label)/2
            local markerY=optionY+game.smallFont:getHeight()/2
            local leftX=DESIGN_W/2-halfWidth-22
            local rightX=DESIGN_W/2+halfWidth+22
            local markerSize=6+math.sin(t*2.2)*1.2
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line",leftX,markerY-markerSize,leftX+markerSize,markerY,leftX,markerY+markerSize,leftX-markerSize,markerY)
            love.graphics.polygon("line",rightX,markerY-markerSize,rightX+markerSize,markerY,rightX,markerY+markerSize,rightX-markerSize,markerY)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(.3,.28,.34,.55*intact)
    if game.newGameConfirm then
        love.graphics.setColor(.78,.48,.38,.9*intact)
        love.graphics.printf(Input.usingGamepad() and "SE PERDERÁ EL PROGRESO  ·  A PARA CONFIRMAR" or "SE PERDERÁ EL PROGRESO  ·  ENTER PARA CONFIRMAR",0,548,DESIGN_W,"center")
    else
        love.graphics.printf(Input.usingGamepad() and "CRUCETA  ELEGIR     A  CONFIRMAR" or "W / S  ELEGIR     ENTER  CONFIRMAR",0,548,DESIGN_W,"center")
    end

    -- Firma mínima: permanece lejos del logotipo y se desvanece junto con la
    -- runa al comenzar, como parte de la portada y no como otro menú.
    local signaturePulse=.42+math.sin(t*.9)*.06
    love.graphics.setColor(.47,.43,.52,signaturePulse*intact)
    love.graphics.printf("DEVELOPED BY LESHUGGAH",0,680,DESIGN_W,"center")
end

local function drawAstralVision()
    local remaining=game.astralVision or 0
    if remaining<=0 then return end
    local age=1.05-remaining
    local fade=clamp(math.min(age*7,remaining*1.65),0,1)
    local t=love.timer.getTime()
    local seed=game.astralVisionSeed or 0
    -- The hit briefly replaces ordinary darkness with a layered impossible
    -- space. Everything is procedural so the vision never repeats exactly.
    love.graphics.setBlendMode("add")
    love.graphics.setColor(.2,.035,.42,.18*fade)
    love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    for echo=1,4 do
        local offset=math.sin(t*19+echo*2.1+seed)*echo*6*fade
        love.graphics.setColor(echo%2==0 and .24 or .68,.08,echo%2==0 and .9 or .48,.055*fade)
        love.graphics.rectangle("fill",offset,0,DESIGN_W,DESIGN_H)
    end
    local cx,cy=DESIGN_W/2,DESIGN_H/2
    for i=1,9 do
        local angle=i*2.399+seed+t*(i%2==0 and -.18 or .12)
        local radius=75+i*48+math.sin(t*3+i)*12
        local x,y=cx+math.cos(angle)*radius,cy+math.sin(angle)*radius*.58
        love.graphics.push(); love.graphics.translate(x,y); love.graphics.rotate(-angle+t*.3)
        love.graphics.setColor(.72,.42,1,(.08+i*.006)*fade)
        love.graphics.polygon("line",0,-11,9,0,0,13,-9,0)
        love.graphics.line(-15,0,15,0,0,-17,0,17)
        love.graphics.pop()
    end
    for ring=1,5 do
        local radius=(age*520+ring*115)%690
        love.graphics.setColor(.74,.5,1,(1-radius/700)*.16*fade)
        love.graphics.arc("line","open",cx,cy,radius,t*.3+ring,t*.3+ring+4.7)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(.02,.005,.04,.18*fade)
    for y=0,DESIGN_H,8 do
        local tear=math.sin(y*.035+t*24+seed)*13*fade
        love.graphics.rectangle("fill",tear,y,DESIGN_W,2)
    end
end

local function drawDepthTransition()
    local transition=game.depthTransition
    if not transition then return end
    local t=transition.t
    local alpha=clamp(math.min(t*1.8,(3.2-t)*1.25),0,1)
    local depth=clamp(((transition.to or 1)-1)/(REGION_COUNT-1),0,1)
    love.graphics.setColor(.02,.01,.035,.12*alpha)
    love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
    -- Los ojos tardan en adaptarse: un velo del color anterior se retira de
    -- arriba hacia abajo mientras el nuevo estrato gana contraste.
    love.graphics.setColor(.08+depth*.08,.045,.09+depth*.13,.13*alpha)
    for y=0,DESIGN_H,18 do
        local drift=math.sin(y*.024+t*2)*9
        love.graphics.rectangle("fill",drift,y,DESIGN_W,3)
    end
    if (transition.to or 1)>=3 and t<2.35 then
        -- Una forma demasiado grande para ser confirmada. Nunca ocupa el mismo
        -- lugar dos veces ni recibe nombre, barra o explicación.
        local apparition=math.sin(clamp(t/2.35,0,1)*math.pi)*.12
        local x=DESIGN_W*(.7+((transition.to or 1)%2)*.08)
        love.graphics.setColor(.005,.004,.012,apparition)
        love.graphics.ellipse("fill",x,405,72+depth*42,245+depth*80)
        love.graphics.line(x-48,520,x-92,690); love.graphics.line(x+42,520,x+88,690)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w / DESIGN_W, h / DESIGN_H)
    local ox, oy = (w - DESIGN_W * scale) / 2, (h - DESIGN_H * scale) / 2
    love.graphics.clear(.01, .008, .015)
    local showHud=game.started and not game.loading and not game.intro and not game.travel and not game.dialogue and not game.controllerNotice and
        not game.preparation and not game.paused and not game.mapOpen and not game.clueView and not game.won and not game.astralCinematic
    if showHud then
        love.graphics.setCanvas(game.uiCanvas)
        love.graphics.clear(0,0,0,0)
        love.graphics.push(); love.graphics.origin(); drawUI(); love.graphics.pop()
        love.graphics.setCanvas()
    end
    love.graphics.push(); love.graphics.translate(ox, oy); love.graphics.scale(scale)
    if game.loading then
        local t=love.timer.getTime()
        love.graphics.setColor(.006,.005,.012,1); love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
        love.graphics.push(); love.graphics.translate(DESIGN_W/2,DESIGN_H/2-35); love.graphics.rotate(t*.18)
        love.graphics.setLineWidth(2); love.graphics.setColor(.55,.34,.72,.24)
        love.graphics.circle("line",0,0,72)
        for i=1,6 do local a=i*math.pi/3; love.graphics.polygon("line",math.cos(a)*55,math.sin(a)*55-7,math.cos(a)*55+7,math.sin(a)*55+6,math.cos(a)*55-7,math.sin(a)*55+6) end
        love.graphics.pop(); love.graphics.setLineWidth(1)
        love.graphics.setFont(game.font); love.graphics.setColor(.76,.68,.58)
        love.graphics.printf("LA MINA RECUERDA SU VOZ",0,440,DESIGN_W,"center")
        local progress=game.loadingProgress or 0
        love.graphics.setColor(.16,.12,.2); love.graphics.rectangle("fill",440,486,400,4)
        love.graphics.setColor(.58,.36,.74); love.graphics.rectangle("fill",440,486,400*progress,4)
        love.graphics.setFont(game.smallFont); love.graphics.setColor(.4,.37,.44)
        love.graphics.printf(string.format("DESPERTANDO ECOS  %d%%",math.floor(progress*100)),0,505,DESIGN_W,"center")
        love.graphics.pop()
        return
    end
    drawWorld()
    drawAstralVision()
    drawDepthTransition()
    if (game.astralDefeatFlash or 0)>0 then
        local flash=clamp(game.astralDefeatFlash,0,1)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(.48,.18,.9,(.08+flash*.42)*(game.settings.flashIntensity or 1))
        love.graphics.rectangle("fill",0,0,DESIGN_W,DESIGN_H)
        love.graphics.setColor(.94,.82,1,flash*.34)
        love.graphics.circle("fill",DESIGN_W/2,DESIGN_H/2,80+flash*520)
        love.graphics.setBlendMode("alpha")
    end
    if showHud then
        love.graphics.setColor(1,1,1,clamp(game.hudReveal or 0,0,1))
        love.graphics.draw(game.uiCanvas,0,0)
    end
    if game.astralCinematic then
        local reveal=clamp((game.astralCinematic.astralDeathTime or 0)*3,0,1)
        love.graphics.setColor(.004,.002,.012,.9*reveal)
        love.graphics.rectangle("fill",0,0,DESIGN_W,58)
        love.graphics.rectangle("fill",0,DESIGN_H-58,DESIGN_W,58)
    end
    if game.mapOpen then
        if game.mapPage=="bestiary" then
            Bestiary.draw(game.bestiary,DESIGN_W,DESIGN_H,game.font,game.smallFont,Input.usingGamepad(),game.currentRegion)
        else
            drawMapOverlay()
        end
    elseif not game.started then
        drawTitleScreen()
    elseif game.paused then
        love.graphics.setColor(.01, .01, .02, .88); love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
        love.graphics.setColor(.85, .75, .57); love.graphics.setFont(game.titleFont); love.graphics.printf("PAUSA", 0, 30, DESIGN_W, "center")
        drawDaughterPhoto()
        ConfigurationRender.draw(game,Input.usingGamepad())
    end
    if game.controllerNotice then drawControllerNotice() end
    if game.preparation then drawPreparationCinematic() end
    if game.travel then drawTravelCinematic() end
    if game.dialogue then drawIntroDialogue() end
    if game.clueView then drawClueOverlay(game.clueView) end
    if game.intro then
        love.graphics.setColor(.005, .004, .01, .96)
        love.graphics.rectangle("fill", 0, 0, DESIGN_W, 92)
        love.graphics.rectangle("fill", 0, DESIGN_H - 92, DESIGN_W, 92)
        if game.intro.t > 1.5 then
            local alpha = clamp((game.intro.t - 1.5) * 1.8, 0, 1)
            local x,y,w,h=170,574,940,92
            love.graphics.setColor(0,0,0,.48*alpha); love.graphics.rectangle("fill",x+7,y+8,w,h,7)
            love.graphics.setColor(.035,.055,.13,.94*alpha); love.graphics.rectangle("fill",x,y,w,h,7)
            love.graphics.setColor(.08,.12,.25,.88*alpha); love.graphics.rectangle("fill",x+7,y+7,w-14,h-14,5)
            love.graphics.setLineWidth(2); love.graphics.setColor(.72,.76,.84,.82*alpha)
            love.graphics.rectangle("line",x+2,y+2,w-4,h-4,7); love.graphics.setLineWidth(1)
            love.graphics.setFont(game.smallFont); love.graphics.setColor(.92,.73,.36,alpha)
            love.graphics.print("LA MINA",x+24,y+13)
            love.graphics.setColor(.3,.4,.67,.7*alpha); love.graphics.line(x+22,y+39,x+w-22,y+39)
            love.graphics.setFont(game.font); love.graphics.setColor(.95,.95,1,alpha)
            love.graphics.printf("Primero entró el polvo. Después, él.",x+24,y+51,w-48,"left")
        end
        if (game.intro.flash or 0) > 0 then
            love.graphics.setColor(1, .72, .38, clamp(game.intro.flash * 4.8, 0, .82)*(game.settings.flashIntensity or 1))
            love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
        end
    end
    if game.won then
        local fade = clamp((game.winTimer-2.6) / 1.3, 0, .96)
        love.graphics.setColor(.01, .008, .018, fade); love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
        if game.winTimer<2.8 then
            love.graphics.setColor(.005,.004,.012,.88); love.graphics.rectangle("fill",0,0,DESIGN_W,72); love.graphics.rectangle("fill",0,648,DESIGN_W,72)
            love.graphics.setFont(game.font); love.graphics.setColor(.76,.58,.9,clamp(game.winTimer,0,1))
            love.graphics.printf("La puerta no se abre. Se aparta.",0,665,DESIGN_W,"center")
        elseif game.winTimer < 8.2 then
            local alpha = clamp(math.min((game.winTimer - 3) * 1.4, (8.2 - game.winTimer) * 1.1), 0, 1)
            love.graphics.setFont(game.titleFont); love.graphics.setColor(.82, .65, .92, alpha)
            love.graphics.printf("«Viniendo era la única forma de entenderlo.»", 120, 305, 1040, "center")
        else
            local photoPulse=.7+math.sin(game.winTimer*.8)*.04
            love.graphics.setColor(.1,.07,.1,.7); love.graphics.rectangle("fill",548,82,184,126,4)
            love.graphics.setColor(.72,.65,.53,photoPulse); love.graphics.rectangle("fill",554,88,172,114,3)
            love.graphics.setColor(.18,.11,.16); love.graphics.rectangle("fill",565,98,150,76)
            -- Dos figuras conocidas y una tercera presencia que no estaba en
            -- la foto inicial. Nunca se enfoca lo suficiente para explicarse.
            love.graphics.setColor(.54,.38,.38); love.graphics.circle("fill",606,126,15)
            love.graphics.polygon("fill",587,171,594,140,618,140,626,171)
            love.graphics.setColor(.25,.23,.27); love.graphics.circle("fill",665,124,17)
            love.graphics.polygon("fill",643,171,650,140,680,140,689,171)
            love.graphics.setColor(.035,.02,.055,.32+.1*math.sin(game.winTimer*2.1))
            love.graphics.ellipse("fill",704,137,13,35)
            love.graphics.setColor(.83, .72, .52); love.graphics.setFont(game.titleFont)
            love.graphics.printf("DEL OTRO LADO", 0, 220, DESIGN_W, "center")
            love.graphics.setFont(game.font); love.graphics.setColor(.82, .78, .7)
            love.graphics.printf("La puerta se cierra detrás de él.\nPor primera vez, el canto está adelante.", 300, 288, 680, "center")
            love.graphics.setColor(.9, .55, .18); love.graphics.printf("FIN DE LA DEMO", 0, 390, DESIGN_W, "center")
            love.graphics.setFont(game.smallFont); love.graphics.setColor(.55, .52, .5)
            local fragments = 0
            for _, fragment in ipairs(game.mapFragments) do if fragment.collected then fragments = fragments + 1 end end
            local minutes, seconds = math.floor(game.runTime / 60), math.floor(game.runTime % 60)
            love.graphics.printf(string.format("TIEMPO %02d:%02d   ·   PISTAS %d/%d   ·   SECRETOS %d/%d   ·   RESCATADOS %d/2", minutes, seconds, game.cluesFound, #game.clues, game.secretsFound, #game.secrets, (game.rescued[1] and 1 or 0) + (game.rescued[2] and 1 or 0)), 0, 455, DESIGN_W, "center")
            love.graphics.printf(string.format("MAPAS %d/%d   ·   CAÍDAS %d   ·   %s", fragments, REGION_COUNT, game.deaths, HOOK_NAMES[game.hookLevel]), 0, 480, DESIGN_W, "center")
            love.graphics.printf(Input.usingGamepad() and "A / START  ·  CRÉDITOS" or "ENTER / ESC  ·  CRÉDITOS", 0, 535, DESIGN_W, "center")
        end
        Credits.draw(game.winTimer,game,Input.usingGamepad())
    end
    love.graphics.pop()
end
