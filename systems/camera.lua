local Camera = {}

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function lerp(a,b,t) return a+(b-a)*t end

function Camera.update(camera, player, dt, worldWidth, worldHeight, tile, viewWidth, viewHeight)
    local maxX, maxY = worldWidth * tile - viewWidth, worldHeight * tile - viewHeight
    local desiredX = clamp(player.vx * .46, -118, 118)
    local desiredY = clamp(player.vy * .235, -48, 178)
    if player.hook then
        -- Mientras cuelga, mostrar parte del camino entre el cuerpo y el agarre
        -- permite preparar el salto siguiente sin tirones de cámara.
        desiredY=desiredY+clamp((player.hook.y-(player.y+player.h/2))*.18,-72,42)
        desiredX=desiredX+clamp((player.hook.x-(player.x+player.w/2))*.08,-42,42)
    end
    camera.lookX=lerp(camera.lookX or 0,desiredX,1-math.pow(.012,dt))
    local verticalSpeed=desiredY>(camera.lookY or 0) and .004 or .035
    camera.lookY=lerp(camera.lookY or 0,desiredY,1-math.pow(verticalSpeed,dt))
    local targetX = clamp(player.x + player.w/2 + camera.lookX - viewWidth/2, 0, math.max(0,maxX))
    local targetY = clamp(player.y + player.h/2 + camera.lookY - viewHeight*.42, 0, math.max(0,maxY))
    camera.x = lerp(camera.x,targetX,1-math.pow(.00032,dt))
    camera.y = lerp(camera.y,targetY,1-math.pow(.00022,dt))
end

return Camera
