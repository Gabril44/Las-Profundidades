local PlayerRender = {}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function easeOut(t) return 1 - (1 - t) * (1 - t) end

local function limb(x1, y1, x2, y2, width, color)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(width)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.circle("fill", x2, y2, width * .42)
    love.graphics.setLineWidth(1)
end

local function drawPick(p, cx, cy)
    if (p.pickTimer or 0) <= 0 then return end
    local t = 1 - p.pickTimer / .32
    local aimX, aimY = p.pickAimX or p.facing, p.pickAimY or 0
    local aimAngle = math.atan2(aimY, aimX)
    local windup = -p.facing * 1.75
    local arc = t < .34 and (windup * (1 - easeOut(t / .34))) or (p.facing * easeOut((t - .34) / .66) * .38)
    love.graphics.push()
    love.graphics.translate(cx + p.facing * 4, cy - 3)
    love.graphics.rotate(aimAngle + arc)
    love.graphics.setColor(.44, .29, .16)
    love.graphics.setLineWidth(4)
    love.graphics.line(0, 0, 25, 0)
    love.graphics.setColor(.72, .75, .72)
    love.graphics.setLineWidth(3)
    love.graphics.line(21, -9, 28, 0, 21, 9)
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

function PlayerRender.draw(p)
    if p.invuln > 0 and math.floor(p.invuln * 12) % 2 ~= 0 then return end
    local cx, cy = p.x + p.w / 2, p.y + p.h / 2
    local speed = math.abs(p.vx or 0)
    local cycle = p.walkCycle or 0
    local walkBlend = p.walkBlend or 0
    local stride = math.sin(cycle) * walkBlend
    local leftLift = math.max(0, math.cos(cycle)) * walkBlend
    local rightLift = math.max(0, -math.cos(cycle)) * walkBlend
    local idle = math.sin(love.timer.getTime() * 2.2) * (1 - (p.walkBlend or 0))
    local land = clamp((p.landTimer or 0) / .2, 0, 1)
    local release = clamp((p.releaseTimer or 0) / .24, 0, 1)
    local pick = clamp((p.pickTimer or 0) / .32, 0, 1)
    local flash = clamp((p.flashTimer or 0) / .42, 0, 1)
    local airborne = not p.grounded and not p.introShy
    local edge = clamp(p.edgeFactor or (p.nearEdge and 1 or 0),0,1)
    local idleTime = p.idleTime or 0
    local idleAwake=clamp((idleTime-.82)/.18,0,1)*(1-walkBlend)
    local exertion=clamp(p.exertion or 0,0,1)
    local danger=clamp(p.danger or 0,0,1)
    local hurt=clamp((p.hurtTimer or 0)/.58,0,1)
    local depth=clamp(((p.depth or 1)-1)/5,0,1)
    local hookFail=clamp((p.hookFailTimer or 0)/.48,0,1)
    local pickFail=clamp((p.pickFailTimer or 0)/.52,0,1)
    local refuge=clamp(p.refugeFactor or 0,0,1)
    local exhausted=clamp(p.exhausted or 0,0,1)
    local zoneGesture=clamp((p.zoneGestureTimer or 0)/.9,0,1)
    local idlePulse=math.sin(p.breathPhase or love.timer.getTime()*2.1)
    local idlePose, idlePoseStrength = 0, 0
    if idleTime > 1 and walkBlend < .08 and p.grounded and not p.hook and edge<.08 then
        local poseClock = (idleTime - 1) % 11.2
        idlePose = math.floor(poseClock / 2.8) + 1
        local poseTime = poseClock % 2.8
        idlePoseStrength = math.sin(clamp(poseTime / .24, 0, 1) * math.pi * .5) *
            math.sin(clamp((2.8 - poseTime) / .3, 0, 1) * math.pi * .5)
    end
    local hookDx, hookDy = 0, 0
    if p.hook then
        local dx, dy = p.hook.x - cx, p.hook.y - cy
        local length = math.max(1, math.sqrt(dx * dx + dy * dy))
        hookDx, hookDy = dx / length, dy / length
    end

    -- A compact, alternating gait keeps both feet planted in turn. The old
    -- animation lifted each leg from unrelated phases and looked slippery.
    local bob = (1 - math.cos(cycle * 2)) * .65 * walkBlend + idle * .7 + idleAwake*(1-idlePulse)*.48
    local lean = clamp((p.vx or 0) / 1100, -.14, .14)
    if edge>0 then lean = lean + p.facing * (.035+.075*edge) end
    if idlePose == 1 then lean = lean - p.facing * .21 * idlePoseStrength end
    if idlePose == 2 then lean = lean + p.facing * .055 * idlePoseStrength end
    if p.hook then lean = lean + hookDx * .2 end
    if release > 0 then lean = lean - p.facing * release * .22 end
    if pick > 0 then lean = lean - p.facing * pick * .15 end
    if hurt>0 then lean=lean-p.facing*math.sin(hurt*math.pi)*.16 end
    lean=lean+math.sin(love.timer.getTime()*31)*danger*.012
    lean=lean-p.facing*exhausted*.08
    local stretch = airborne and clamp(math.abs(p.vy or 0) / 1400, 0, .16) or 0
    local squash = (p.squash or 0) + land * .18
    local gearSwing = stride * 1.25 + (p.gearX or 0)
    local gearLift = p.gearY or 0
    local bellyBreath = idlePulse * ((1-walkBlend)*(.65+idleAwake*.85)+exertion*1.35+danger*.35)
    local bellyLagX = p.bellyX or 0
    local bellyLagY = p.bellyY or 0
    local bellyMotion = clamp((math.abs(p.bellyVX or 0)+math.abs(p.bellyVY or 0))/38,0,4.8)
    local bellyFlight = airborne and clamp(math.abs(bellyLagY)*.55,0,4.2) or 0
    local bellyKick = land * 3.8 + math.abs(stride) * 1.15 + bellyMotion
    local beardLagX = (p.beardX or 0) + (p.hook and -hookDx * .75 or 0)
    local beardLagY = p.beardY or 0
    local helmetTilt = (p.helmetAngle or 0) - lean*.35
    local helmetLift = idlePose == 3 and idlePoseStrength * 7.5 or 0

    -- Motion echoes are deliberately sparse: they appear only on forceful actions.
    if release > 0 or (p.hookKick or 0) > .15 then
        for i = 2, 1, -1 do
            love.graphics.setColor(.32, .42, .44, .08 * i * math.max(release, p.hookKick or 0))
            love.graphics.rectangle("fill", p.x - p.facing * i * 5, p.y + 13, p.w - 8, 22, 2)
        end
    end

    -- The lamp casts a stretched, imperfect double behind him. It grows with
    -- depth and trembles when he is afraid instead of following like a decal.
    if p.lanternOn then
        local shadowSway=math.sin(love.timer.getTime()*17)*danger*5
        love.graphics.setColor(.015,.008,.024,.16+depth*.08)
        love.graphics.push(); love.graphics.translate(cx-p.facing*(35+depth*18)+shadowSway,p.y+p.h)
        love.graphics.scale(1.65+depth*.3,2.05+depth*.45)
        love.graphics.polygon("fill",-7,0,7,0,11,-18,6,-31,-5,-31,-11,-18)
        love.graphics.circle("fill",0,-34,9)
        love.graphics.pop()
    end
    if (p.astralEcho or 0)>0 then
        local echo=p.astralEcho
        love.graphics.setColor(.65,.32,1,.2*echo)
        love.graphics.push(); love.graphics.translate(-p.facing*(9+echo*12),-echo*7)
        love.graphics.rectangle("line",p.x+3,p.y+12,p.w-6,p.h-12,5)
        love.graphics.circle("line",cx,p.y+10,12+echo*3)
        love.graphics.pop()
    end

    love.graphics.push()
    -- The drawing is intentionally larger than the physics body. Anchoring at
    -- the feet preserves every jump and collision while making him readable.
    local characterScale = 1.4
    love.graphics.translate(cx, p.y + p.h)
    love.graphics.scale(characterScale, characterScale)
    love.graphics.translate(-cx, -(p.y + p.h))
    love.graphics.translate(cx, cy - bob + land * 4)
    love.graphics.rotate(lean)
    local idleSquash=idleAwake*(.012+idlePulse*.009)
    love.graphics.scale(1 + squash - stretch * .45+idleSquash, 1 - squash + stretch-idleSquash)
    love.graphics.translate(-cx, -cy)

    local hipY = p.y + 32
    local weightShift=idleAwake*math.sin(love.timer.getTime()*1.15)*1.6
    local rising = airborne and clamp(-(p.vy or 0)/420,0,1) or 0
    local falling = airborne and clamp((p.vy or 0)/500,0,1) or 0
    local legSpread = airborne and (5+rising*5-falling*2) or stride * 4.5
    if p.hook then legSpread = math.sin(love.timer.getTime() * 6) * 4 + hookDx * 5 end
    if release > 0 then legSpread = p.facing * 7 * release end
    love.graphics.setColor(.075, .065, .085)
    love.graphics.setLineWidth(5)
    love.graphics.line(p.x + 9+weightShift*.25, hipY-rising*2, p.x + 7 + legSpread-weightShift*.35, p.y + 42 - leftLift * 4-rising*7+falling*2)
    love.graphics.line(p.x + 18+weightShift*.25, hipY-rising*2, p.x + 20 - legSpread+weightShift*.35, p.y + 42 - rightLift * 4-rising*7+falling*2)
    love.graphics.setLineWidth(1)

    -- Compact field pack and hook spool, each with its own delayed mass.
    local backSide = -p.facing
    local packX=cx+backSide*9+gearSwing*.35
    local packY=p.y+24+gearLift
    love.graphics.push(); love.graphics.translate(packX,packY); love.graphics.rotate((p.packAngle or 0)*p.facing); love.graphics.translate(-packX,-packY)
    love.graphics.setColor(.105, .12, .12)
    love.graphics.rectangle("fill", cx + backSide * 9 - 4 + gearSwing*.35, p.y + 17 + gearLift, 8, 15, 2)
    love.graphics.setColor(.48, .34, .18)
    love.graphics.circle("fill", cx + backSide * 10 + gearSwing*.55, p.y + 22 + gearLift, 4)
    love.graphics.setColor(.72, .55, .28)
    love.graphics.circle("line", cx + backSide * 10 + gearSwing*.55, p.y + 22 + gearLift, 2.4)
    love.graphics.setColor(.34,.39,.37); love.graphics.line(packX-backSide*2,p.y+18+gearLift,packX+backSide*2,p.y+31+gearLift)
    love.graphics.pop()

    -- Connected torso silhouette. The shoulder stays fixed while the front of
    -- the coat swells into the belly; the back only yields slightly.
    local flap = clamp(-(p.vy or 0) / 420, -3, 5) + clamp(-(p.vx or 0) / 150, -2.5, 2.5)
    local frontSign = p.facing
    local connectedLagX = bellyLagX * .2
    local connectedLagY = bellyLagY * .34
    local bellyBulge = 12.2 + bellyKick * .58 + math.abs(bellyBreath)
    local frontBellyX = cx + frontSign * bellyBulge + connectedLagX
    local backBodyX = cx - frontSign * (10.8 + bellyKick*.16) + connectedLagX * .12
    local leftMidX = frontSign < 0 and frontBellyX or backBodyX
    local rightMidX = frontSign > 0 and frontBellyX or backBodyX
    love.graphics.setColor(.205-depth*.035, .27-depth*.045, .285-depth*.04)
    love.graphics.polygon("fill", p.x + 5, p.y + 13, p.x + p.w - 5, p.y + 13,
        p.x + p.w - 1, p.y + 20, rightMidX - flap * .18, p.y + 27 + connectedLagY,
        p.x + p.w - 4 - flap, p.y + 35, p.x + 4 - flap * .55, p.y + 35,
        leftMidX - flap * .12, p.y + 27 + connectedLagY, p.x + 1, p.y + 20)
    love.graphics.setColor(.28, .35, .355)
    love.graphics.arc("line", "open", cx - flap * .18, p.y + 27, 12, .12, math.pi - .12)

    -- A lighter front panel describes the belly without becoming a detached
    -- circle. Every point is anchored between chest, waist and belt.
    local bellyTopY = p.y + 18 + connectedLagY*.12
    local bellyMidY = p.y + 26 + connectedLagY
    local bellyBottomY = p.y + 33 + connectedLagY*.22
    love.graphics.setColor(.235,.31,.32,.94)
    love.graphics.polygon("fill",
        cx-frontSign*1.5,bellyTopY,
        cx+frontSign*7,bellyTopY+1,
        frontBellyX,bellyMidY,
        frontBellyX-frontSign*2,bellyMidY+4,
        cx+frontSign*5,bellyBottomY,
        cx-frontSign*2,bellyBottomY-2)
    love.graphics.setColor(.43,.5,.49,.78)
    love.graphics.line(cx+frontSign*5,bellyTopY+1,frontBellyX-frontSign*.5,bellyMidY,frontBellyX-frontSign*2,bellyMidY+4)
    love.graphics.setColor(.13,.17,.18,.65)
    love.graphics.line(cx-frontSign*1,bellyBottomY-2,cx+frontSign*5,bellyBottomY,frontBellyX-frontSign*2,bellyMidY+4)
    love.graphics.setColor(.13, .17, .19)
    love.graphics.line(p.x + 5, p.y + 30, p.x + p.w - 5 - flap, p.y + 34)

    -- Harness straps keep every hanging object visibly connected to his body.
    love.graphics.setColor(.11,.085,.065,.86)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx-backSide*3,p.y+14,cx+backSide*7,p.y+29)
    love.graphics.line(cx+backSide*2,p.y+14,cx-backSide*5,p.y+29)
    love.graphics.setLineWidth(1)

    -- Utility belt wraps around the moving mass instead of cutting straight
    -- through it, making the belly's attachment unmistakable.
    love.graphics.setColor(.15, .105, .07)
    love.graphics.setLineWidth(4)
    local beltBackX = cx-frontSign*9
    local beltFrontX = frontBellyX-frontSign*2
    love.graphics.line(beltBackX,p.y+29,cx,p.y+30,beltFrontX,p.y+30+connectedLagY*.42)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(.72, .51, .22)
    local buckleX = cx+frontSign*5
    love.graphics.rectangle("line", buckleX-3, p.y + 28+connectedLagY*.18, 6, 5, 1)
    local beltSwing=math.sin(p.beltAngle or 0)*3.5
    local frontX = (frontSign > 0 and beltFrontX-6 or beltFrontX)+beltSwing
    love.graphics.setColor(.47, .27, .12)
    love.graphics.rectangle("fill", frontX + gearSwing*.25, p.y + 30 + gearLift*.55, 7, 7, 1)
    love.graphics.setColor(.88, .58, .16)
    love.graphics.rectangle("fill", frontX + 2 + gearSwing*.25, p.y + 31 + gearLift*.55, 3, 4, 1)
    local clipX = p.facing > 0 and p.x + 4 or p.x + 22
    love.graphics.setColor(.62, .67, .64)
    love.graphics.arc("line", "open", clipX + gearSwing*.65, p.y + 34 + gearLift*.7, 3, -.7, math.pi + .8)

    -- A separate hip lantern lags behind turns and falls, making the equipment
    -- feel attached by a loose metal loop instead of painted onto the coat.
    local lampPivotX,lampPivotY=cx-backSide*5,p.y+31
    local lampAngle=(p.lampAngle or 0)*p.facing
    local lampX=lampPivotX+math.sin(lampAngle)*8
    local lampY=lampPivotY+math.cos(lampAngle)*8
    love.graphics.setColor(.42,.45,.43); love.graphics.line(lampPivotX,lampPivotY,lampX,lampY)
    love.graphics.setColor(.12,.15,.14); love.graphics.rectangle("fill",lampX-3,lampY-2,6,7,1)
    love.graphics.setColor(.88,.6,.18,p.lanternOn and .9 or .28); love.graphics.rectangle("fill",lampX-1.5,lampY,3,3,1)

    -- Strict side profile: the rear of the skull, brow, nose and beard form one
    -- unmistakable contour. The face always points with the belly and lamp.
    local headX = cx + p.facing*1.3 - p.facing * release * 3
    local headY = p.y + 10 + pick * 2 - (p.mantlePose or 0) * 3 + edge*2.2
    love.graphics.setColor(.62, .49, .38)
    love.graphics.circle("fill", headX - p.facing * 7.5, headY + 1.2, 2.9)
    love.graphics.setColor(.74, .61, .49)
    love.graphics.ellipse("fill", headX-p.facing*.7, headY, 8.7, 9.2)
    -- Bridge plus rounded tip keeps the nose visible even against dark rock.
    love.graphics.polygon("fill",headX+p.facing*4.6,headY-3,headX+p.facing*10.4,headY+.4,headX+p.facing*4.8,headY+2.3)
    love.graphics.circle("fill",headX+p.facing*10.1,headY+.55,2.2)

    -- Full beard and moustache carry the friendly older silhouette from the
    -- reference while remaining legible at the game's tiny scale.
    love.graphics.setColor(.19, .105, .07)
    love.graphics.arc("fill", headX-p.facing*.7 + beardLagX, headY + 1 + beardLagY, 9, 0, math.pi)
    love.graphics.circle("fill", headX - p.facing * 3.4 + beardLagX*.55, headY + 2.7 + beardLagY*.5, 3.5)
    love.graphics.polygon("fill",headX+p.facing*1,headY+1.4,headX+p.facing*8.2,headY+2.8,headX+p.facing*4,headY+5.4)
    love.graphics.setColor(.76, .62, .49)
    love.graphics.circle("fill",headX+p.facing*7.2,headY+2.55,1.05)
    -- Only the near eye is visible. It tracks downward before a ledge.
    love.graphics.setColor(.055,.045,.04)
    local eyeX=headX+p.facing*(3.25+(p.lookX or 0)*.7)
    local eyeY=headY-2.15+edge*1.25+(p.lookY or 0)*.75
    love.graphics.ellipse("fill",eyeX,eyeY,1.28+danger*.48,math.max(.18,(1.28+danger*.22)*(1-(p.blinkAmount or 0))))
    -- Brow and jaw communicate strain at a scale where a full face rig would
    -- be unreadable.
    love.graphics.setLineWidth(1)
    love.graphics.line(eyeX-p.facing*2,eyeY-2-danger,eyeX+p.facing*2.5,eyeY-1+danger*.5)
    if exertion>.35 then
        love.graphics.setColor(.16,.08,.055,.8)
        love.graphics.line(headX+p.facing*4,headY+5,headX+p.facing*(6+exertion*2),headY+5.5+idlePulse*.6)
    end

    -- Protective miner cap with a small lamp, brim and reinforced crown.
    love.graphics.push()
    love.graphics.translate(headX, headY - 4.5 - helmetLift)
    love.graphics.rotate(helmetTilt + (idlePose==3 and p.facing*.09*idlePoseStrength or 0))
    love.graphics.setColor(.15, .18, .18)
    love.graphics.arc("fill", 0, 0, 9.5, math.pi, math.pi * 2)
    love.graphics.setColor(.26, .31, .3)
    love.graphics.rectangle("fill", -10, -1, 20, 3, 1)
    love.graphics.line(0, -8.5, 0, -.5)
    local lampPower = p.lanternOn and clamp((p.light or 0)/22,0,1) or .12
    if (p.light or 0) < 20 then lampPower = lampPower * (.55 + math.max(0,math.sin(love.timer.getTime()*19))*.45) end
    love.graphics.setColor(.78, .55, .19, .45 + lampPower*.55)
    love.graphics.circle("fill", p.facing * 5.5, -2.7, 2.7)
    love.graphics.setColor(1, .82, .38, lampPower)
    love.graphics.circle("fill", p.facing * 6.2, -2.7, 1.2)
    love.graphics.pop()

    local shoulderX, shoulderY = cx+p.facing*.7, p.y + 20
    if hurt>.02 then
        -- One arm protects the ribs while the other searches for balance.
        limb(shoulderX+p.facing*4,shoulderY,frontBellyX-p.facing*3,p.y+27,4,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*(11+hurt*7),shoulderY+8-hurt*5,3,{.68,.55,.45})
    elseif p.mantle then
        local lift = p.mantlePose or 0
        limb(shoulderX - 5, shoulderY, p.x + 1, p.y + 6 - lift * 8, 4, {.74, .61, .49})
        limb(shoulderX + 5, shoulderY, p.x + p.w - 1, p.y + 6 - lift * 8, 4, {.74, .61, .49})
    elseif p.hook then
        limb(shoulderX, shoulderY, shoulderX + hookDx * 20, shoulderY + hookDy * 20, 4, {.74, .61, .49})
        limb(shoulderX - p.facing * 4, shoulderY + 2, shoulderX - p.facing * 10 - hookDx * 4, shoulderY + 10, 3, {.68, .55, .45})
    elseif pick > 0 then
        limb(shoulderX, shoulderY, shoulderX + p.facing * 9, shoulderY - 8, 4, {.74, .61, .49})
    elseif flash > 0 then
        limb(shoulderX, shoulderY, shoulderX + p.facing * 19, shoulderY - 2, 4, {.84, .7, .51})
        love.graphics.setColor(1, .72, .2, .8 * flash)
        love.graphics.circle("fill", shoulderX + p.facing * 21, shoulderY - 3, 4 + flash * 3)
    elseif hookFail>.02 then
        -- He checks the empty launcher, then glances back toward the missed aim.
        limb(shoulderX+p.facing*4,shoulderY,shoulderX+p.facing*15,shoulderY-3-hookFail*3,3,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX+p.facing*7,shoulderY+5,3,{.68,.55,.45})
        love.graphics.setColor(.52,.55,.52); love.graphics.circle("line",shoulderX+p.facing*17,shoulderY-4,3)
    elseif pickFail>.02 then
        -- The impact stays in his wrists; he shakes one hand before recovering.
        local shake=math.sin(love.timer.getTime()*38)*pickFail*3
        limb(shoulderX+p.facing*4,shoulderY,shoulderX+p.facing*15,shoulderY+4+shake,3,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*8,shoulderY+10,3,{.68,.55,.45})
    elseif refuge>.2 and walkBlend<.12 then
        -- Open palms, lowered shoulders and a warmer posture at the fire.
        local restTime=p.refugeRest or 0
        if restTime>2.2 then
            local photoX,photoY=cx+p.facing*13,p.y+29
            limb(shoulderX+p.facing*4,shoulderY,photoX+p.facing*3,photoY,3,{.82,.65,.48})
            limb(shoulderX-p.facing*4,shoulderY,photoX-p.facing*4,photoY+2,3,{.78,.61,.46})
            love.graphics.setColor(.81,.74,.6); love.graphics.rectangle("fill",photoX-5,photoY-7,10,13,1)
            love.graphics.setColor(.34,.2,.22); love.graphics.rectangle("fill",photoX-3.5,photoY-5,7,7)
        else
            limb(shoulderX+p.facing*4,shoulderY,shoulderX+p.facing*17,shoulderY+4,3,{.82,.65,.48})
            limb(shoulderX-p.facing*4,shoulderY,shoulderX+p.facing*13,shoulderY+8,3,{.78,.61,.46})
        end
    elseif exhausted>.16 and walkBlend<.12 then
        -- One hand braces the knee while the torso rises with heavy breaths.
        limb(shoulderX+p.facing*4,shoulderY,frontBellyX-p.facing*2,p.y+35,4,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*9,shoulderY+10,3,{.68,.55,.45})
    elseif zoneGesture>.04 then
        -- His characteristic promise: two taps over the photograph in his coat.
        local tap=math.abs(math.sin((1-zoneGesture)*math.pi*4))
        limb(shoulderX+p.facing*4,shoulderY,cx+p.facing*(5+tap*2),p.y+23,3,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*8,shoulderY+9,3,{.68,.55,.45})
    elseif edge>.05 then
        -- He tests the drop early: front hand balances, rear hand guards the
        -- belt. The amount grows continuously as the ledge approaches.
        limb(shoulderX+p.facing*4,shoulderY,shoulderX+p.facing*(9+edge*8),shoulderY+4+edge*5,3,{.78,.64,.49})
        limb(shoulderX-p.facing*4,shoulderY+1,shoulderX-p.facing*(7+edge*3),shoulderY+9,3,{.61,.49,.4})
    elseif idlePose == 1 and idlePoseStrength > .02 then
        -- He stretches his lower back under the weight of the equipment.
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*(18+idlePoseStrength*4),shoulderY+15,3,{.74,.61,.49})
        limb(shoulderX+p.facing*4,shoulderY,shoulderX+p.facing*(14+idlePoseStrength*3),shoulderY+12,3,{.74,.61,.49})
    elseif idlePose == 2 and idlePoseStrength > .02 then
        -- A quick battery and belt check.
        limb(shoulderX+p.facing*4,shoulderY,frontX+3+p.facing*idlePoseStrength*2,p.y+33,3,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*8,shoulderY+9,3,{.74,.61,.49})
        love.graphics.setColor(.84,.55,.14)
        love.graphics.rectangle("fill",frontX+1,p.y+28,6,9,1)
        love.graphics.setColor(1,.78,.3)
        love.graphics.rectangle("fill",frontX+3,p.y+29,2,4,1)
    elseif idlePose == 3 and idlePoseStrength > .02 then
        -- He reseats the helmet before moving on.
        limb(shoulderX+p.facing*4,shoulderY,headX+p.facing*9,headY-8-helmetLift,3,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,shoulderX-p.facing*8,shoulderY+9,3,{.74,.61,.49})
    elseif idlePose == 4 and idlePoseStrength > .02 then
        -- He checks the worn photograph without turning it into a cutscene.
        local photoX,photoY=shoulderX+p.facing*15,shoulderY+7
        limb(shoulderX+p.facing*4,shoulderY,photoX,photoY,3,{.74,.61,.49})
        limb(shoulderX-p.facing*4,shoulderY,photoX-p.facing*5,photoY+2,3,{.68,.55,.45})
        love.graphics.setColor(.79,.72,.58); love.graphics.rectangle("fill",photoX-4,photoY-5,8,10,1)
        love.graphics.setColor(.33,.2,.22); love.graphics.rectangle("fill",photoX-2.5,photoY-3.5,5,5)
    else
        limb(shoulderX - 6, shoulderY, p.x + 5 - stride * 3.2, p.y + 29, 3, {.74, .61, .49})
        limb(shoulderX + 6, shoulderY, p.x + 22 + stride * 3.2, p.y + 29, 3, {.74, .61, .49})
    end

    drawPick(p, cx, cy)

    -- Dirt accumulates as he descends. Fixed placements avoid visual noise and
    -- keep the wear readable as continuity rather than random particles.
    if depth>.05 then
        love.graphics.setColor(.12,.09,.07,.12+depth*.28)
        love.graphics.circle("fill",cx-p.facing*5,p.y+18,1.2+depth)
        love.graphics.ellipse("fill",cx+p.facing*7,p.y+28,2.2+depth,1.1)
        love.graphics.line(cx-6,p.y+34,cx+2,p.y+32)
        if depth>.55 then love.graphics.circle("fill",headX-p.facing*2,headY-5,1.2) end
    end
    love.graphics.pop()
end

return PlayerRender
