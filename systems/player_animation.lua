local Animation = {}

local function spring(value, velocity, target, stiffness, damping, dt, limit)
    velocity = velocity + ((target-value)*stiffness-velocity*damping)*dt
    value = value + velocity*dt
    if limit then value=math.max(-limit,math.min(limit,value)) end
    return value,velocity
end

function Animation.trigger(player, name, duration, strength)
    player.action = name
    player.actionTime = duration or .25
    player.actionDuration = duration or .25
    player.actionStrength = strength or 1
end

function Animation.update(player, dt)
    player.actionTime = math.max(0, (player.actionTime or 0) - dt)
    player.landTimer = math.max(0, (player.landTimer or 0) - dt)
    player.releaseTimer = math.max(0, (player.releaseTimer or 0) - dt)
    player.hurtTimer = math.max(0, (player.hurtTimer or 0) - dt)
    player.hookFailTimer=math.max(0,(player.hookFailTimer or 0)-dt)
    player.pickFailTimer=math.max(0,(player.pickFailTimer or 0)-dt)
    player.zoneGestureTimer=math.max(0,(player.zoneGestureTimer or 0)-dt)
    player.astralEcho=math.max(0,(player.astralEcho or 0)-dt*1.35)
    player.airTime = player.grounded and 0 or (player.airTime or 0) + dt
    -- Damped secondary-motion spring. It follows acceleration rather than
    -- teleporting with velocity, so the belly can be broad without detaching.
    local targetX = math.max(-5.2, math.min(5.2, -(player.vx or 0) / 52))
    local targetY = math.max(-5.5, math.min(6.8, -(player.vy or 0) / 78))
    local stiffness, damping = 78, 11
    player.bellyVX = (player.bellyVX or 0) + ((targetX-(player.bellyX or 0))*stiffness-(player.bellyVX or 0)*damping)*dt
    player.bellyVY = (player.bellyVY or 0) + ((targetY-(player.bellyY or 0))*stiffness-(player.bellyVY or 0)*damping)*dt
    player.bellyX = math.max(-6,math.min(6,(player.bellyX or 0)+(player.bellyVX or 0)*dt))
    player.bellyY = math.max(-6.5,math.min(7.5,(player.bellyY or 0)+(player.bellyVY or 0)*dt))
    local gearTargetX=math.max(-4,math.min(4,-(player.vx or 0)/70))
    local gearTargetY=math.max(-3,math.min(4,-(player.vy or 0)/130))
    player.gearX,player.gearVX=spring(player.gearX or 0,player.gearVX or 0,gearTargetX,105,15,dt,4.8)
    player.gearY,player.gearVY=spring(player.gearY or 0,player.gearVY or 0,gearTargetY,92,13,dt,4.8)
    local beardTargetX=math.max(-1.8,math.min(1.8,-(player.vx or 0)/155))
    local beardTargetY=math.max(-2,math.min(2.4,-(player.vy or 0)/220))
    player.beardX,player.beardVX=spring(player.beardX or 0,player.beardVX or 0,beardTargetX,112,16,dt,2.3)
    player.beardY,player.beardVY=spring(player.beardY or 0,player.beardVY or 0,beardTargetY,96,14,dt,2.6)
    local helmetTarget=math.max(-.16,math.min(.16,-(player.vx or 0)/1250))
    player.helmetAngle,player.helmetVelocity=spring(player.helmetAngle or 0,player.helmetVelocity or 0,helmetTarget,125,12,dt,.22)
    local accelerationLag=math.max(-.22,math.min(.22,-(player.vx or 0)/850))
    local fallLag=math.max(-.18,math.min(.22,-(player.vy or 0)/1800))
    player.packAngle,player.packVelocity=spring(player.packAngle or 0,player.packVelocity or 0,accelerationLag+fallLag,62,9,dt,.32)
    player.lampAngle,player.lampVelocity=spring(player.lampAngle or 0,player.lampVelocity or 0,-accelerationLag*1.45-fallLag*.55,48,7.5,dt,.42)
    player.beltAngle,player.beltVelocity=spring(player.beltAngle or 0,player.beltVelocity or 0,accelerationLag*.72,85,11,dt,.24)
    local active=math.min(1,math.abs(player.vx or 0)/230+math.abs(player.vy or 0)/720+(player.hook and .3 or 0))
    player.exertion=math.max(0,math.min(1,(player.exertion or 0)+(active*.8-.22)*dt))
    player.breathPhase=(player.breathPhase or 0)+dt*(2.2+(player.exertion or 0)*4+(player.danger or 0)*1.7)
    local exhaustedTarget=(player.grounded and not player.hook and (player.exertion or 0)>.72) and 1 or 0
    player.exhausted=player.exhausted+(exhaustedTarget-(player.exhausted or 0))*(1-math.pow(.018,dt))
    player.blinkClock=(player.blinkClock or 1)-dt
    if player.blinkClock<=0 then player.blinkClock=2.1+math.random()*3.4 end
    player.blinkAmount=player.blinkClock<.13 and math.sin((.13-player.blinkClock)/.13*math.pi) or 0
    if player.actionTime <= 0 then player.action = nil end
end

function Animation.progress(player, name)
    if player.action ~= name or not player.actionDuration or player.actionDuration <= 0 then return 0 end
    return 1 - player.actionTime / player.actionDuration
end

return Animation
