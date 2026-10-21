local Rope = {}

function Rope.draw(player, level, tension)
    if not player.hook then return end
    local x1, y1 = player.x + player.w / 2, player.y + 13
    local targetX,targetY=player.hook.x,player.hook.y
    local progress=1
    if player.hook.deploying then
        local raw=math.min(1,(player.hook.shotTime or 0)/math.max(.001,player.hook.shotDuration or .2))
        progress=1-(1-raw)^3
    end
    local x2=x1+(targetX-x1)*progress
    local y2=y1+(targetY-y1)*progress
    local dx, dy = x2 - x1, y2 - y1
    local length = math.max(1, math.sqrt(dx * dx + dy * dy))
    local links = math.max(3, math.floor(length / 11))
    local colors = {{.72,.62,.48},{.55,.72,.72},{.42,.88,.72},{.72,.52,1}}
    local color = colors[level] or colors[1]
    if level >= 3 and not player.hook.deploying then
        love.graphics.setColor(color[1], color[2], color[3], .13 + tension * .12)
        love.graphics.setLineWidth(6); love.graphics.line(x1,y1,x2,y2)
    end
    if not player.hook.deploying and tension>.78 then
        love.graphics.setColor(color[1],color[2],color[3],.11+tension*.12)
        love.graphics.setLineWidth(4+tension*3); love.graphics.line(x1,y1,x2,y2)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setLineWidth(1.5)
    for i = 0, links - 1 do
        local a, b = i / links, (i + 1) / links
        local unfurl=player.hook.deploying and (1-progress)*7 or 0
        local sway = math.sin(i * 1.7 + love.timer.getTime() * 7) * ((1 - tension) * 2+unfurl)
        love.graphics.setColor(color)
        love.graphics.line(x1 + dx*a + sway, y1 + dy*a, x1 + dx*b - sway, y1 + dy*b)
        if i % 2 == 0 then love.graphics.circle("line", x1 + dx*b, y1 + dy*b, level >= 2 and 2.4 or 1.8) end
    end
    love.graphics.setLineWidth(1)
    -- Visible iron head flies ahead of the uncoiling links, then bites into the
    -- anchor. Its prongs orient along the actual trajectory.
    local angle=math.atan2(targetY-y1,targetX-x1)
    love.graphics.push(); love.graphics.translate(x2,y2); love.graphics.rotate(angle)
    love.graphics.setColor(.18,.14,.12,.7); love.graphics.circle("fill",-3,0,5+level*.25)
    love.graphics.setColor(color); love.graphics.setLineWidth(2)
    love.graphics.line(-5,0,5,0,1,-6,7,-2,1,0,7,2,1,6)
    love.graphics.setLineWidth(1); love.graphics.pop()
    if not player.hook.deploying then
        local bite=.5+.5*math.sin(love.timer.getTime()*16)
        love.graphics.setColor(color[1],color[2],color[3],.18+bite*.18*tension)
        love.graphics.circle("line",x2,y2,5+bite*4)
        for i=1,3 do
            local a=i*2.094+love.timer.getTime()*.25
            love.graphics.line(x2+math.cos(a)*5,y2+math.sin(a)*5,x2+math.cos(a)*(8+tension*5),y2+math.sin(a)*(8+tension*5))
        end
    end
    if player.hook.deploying then
        for i=1,3 do
            local trail=8+i*7
            love.graphics.setColor(color[1],color[2],color[3],.2/i)
            love.graphics.line(x2-math.cos(angle)*trail,y2-math.sin(angle)*trail,x2-math.cos(angle)*(trail+9),y2-math.sin(angle)*(trail+9))
        end
    end
end

return Rope
