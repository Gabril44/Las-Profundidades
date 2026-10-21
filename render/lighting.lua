local Lighting = {}

local function segmentedRing(cx,cy,radius,segments,phase,color,alpha,width)
    love.graphics.setColor(color[1],color[2],color[3],alpha)
    love.graphics.setLineWidth(width or 1)
    local slice=math.pi*2/segments
    for i=0,segments-1 do
        local start=phase+i*slice
        love.graphics.arc("line","open",cx,cy,radius,start,start+slice*.46)
    end
    love.graphics.setLineWidth(1)
end

function Lighting.playerAura(player)
    local t=love.timer.getTime()
    local flicker=player.lanternOn and (math.sin(t*7.7)*2+math.sin(t*16.3)*.8) or 0
    local radius = player.lanternOn and (105 + player.light * 1.15+flicker) or 42
    local cx, cy = player.x + player.w / 2, player.y + player.h / 2
    for i = 9, 1, -1 do
        local r = radius * i / 9
        local alpha = .018 + (9 - i) * .005
        love.graphics.setColor(.12, .065, .025, alpha*.82)
        love.graphics.setLineWidth(2 + i)
        love.graphics.circle("line", cx, cy, r)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, .68, .3, player.lanternOn and .038 or .006)
    love.graphics.circle("fill", cx + player.facing * 28, cy - 3, radius * .56)
end

function Lighting.influence(player)
    local t=love.timer.getTime()
    local cx,cy=player.x+player.w/2,player.y+player.h/2
    if player.lanternOn and (player.light or 0)>0 then
        -- Radio real usado por los Custodios para notar la linterna encendida.
        -- Los cortes evitan que parezca una barrera física o una interfaz dura.
        local power=math.min(1,(player.light or 0)/24)
        local breathe=math.sin(t*1.8)*3
        segmentedRing(cx,cy,240+breathe,28,t*.025,{1,.57,.19},.055+.025*power,1)
        segmentedRing(cx,cy,233+breathe*.55,20,-t*.018,{1,.76,.35},.022+.018*power,1)
        for i=1,5 do
            local angle=t*.06+i*1.256
            local r=237+breathe+math.sin(t*.8+i)*4
            love.graphics.setColor(1,.7,.3,.055*power)
            love.graphics.circle("fill",cx+math.cos(angle)*r,cy+math.sin(angle)*r,1.4)
        end
    end

    local flash=math.max(0,math.min(1,(player.flashTimer or 0)/.42))
    if flash>0 then
        local age=1-flash
        local reveal=math.sin(math.min(1,age*1.45)*math.pi*.5)
        -- 430: reacción física inmediata. 900: el eco lejano que puede oír el
        -- Resonante. Comparten lenguaje, pero el segundo es frío y quebrado.
        segmentedRing(cx,cy,430,40,t*.07,{1,.64,.22},flash*.24*reveal,2.2)
        segmentedRing(cx,cy,900,58,-t*.045,{.76,.35,.72},flash*.18*reveal,1.6)
        for ring=1,3 do
            local radius=55+age*(375+ring*16)
            segmentedRing(cx,cy,radius,24+ring*4,t*.09+ring,{1,.82,.45},flash*(.11-ring*.018),1)
        end
    end
end

function Lighting.astralDistortion(camera, width, height)
    local t = love.timer.getTime()
    love.graphics.setColor(.55, .28, .9, .035)
    for i = 1, 8 do
        local y = camera.y + ((i * 113 + t * (4 + i)) % height)
        love.graphics.rectangle("fill", camera.x, y, width, 2 + i % 3)
    end
end

return Lighting
