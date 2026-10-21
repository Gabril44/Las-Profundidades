local Atmosphere = {}

local palettes = {
    [1]={{.13,.075,.055},{.31,.16,.09},{.86,.43,.14}},
    [2]={{.025,.12,.11},{.08,.34,.29},{.32,.82,.61}},
    [3]={{.07,.025,.11},{.25,.08,.31},{.74,.31,.72}},
    [4]={{.018,.105,.045},{.11,.32,.12},{.52,.86,.28}},
    [5]={{.08,.018,.12},{.31,.07,.4},{.79,.34,.95}},
    [6]={{.04,.018,.14},{.19,.08,.42},{.73,.51,1}}
}

local function noise(seed)
    local value=math.sin(seed*12.9898+78.233)*43758.5453
    return value-math.floor(value)
end

local function visibleSpan(camera,width,parallax,padding)
    local left=camera.x*parallax-padding
    return left,left+width+padding*2
end

function Atmosphere.background(camera,region,width,height,t)
    local color=palettes[region] or palettes[6]
    -- Three strata move at different speeds. The lowest one is deliberately
    -- enormous: it suggests chambers that are never part of the playable map.
    for layer=1,3 do
        local parallax=.08+layer*.075
        local left,right=visibleSpan(camera,width,parallax,180)
        local spacing=260-layer*34
        for index=math.floor(left/spacing)-1,math.ceil(right/spacing)+1 do
            local seed=index*17+region*71+layer*113
            local x=camera.x+index*spacing-camera.x*parallax
            local baseY=camera.y+height*(.2+layer*.2)+noise(seed)*height*.24
            local w=85+noise(seed+3)*155
            local h=130+noise(seed+7)*310
            love.graphics.setColor(color[1][1],color[1][2],color[1][3],.18+layer*.045)
            love.graphics.ellipse("fill",x,baseY,w,h)
            love.graphics.setColor(color[2][1],color[2][2],color[2][3],.035+layer*.018)
            love.graphics.arc("line","open",x,baseY,w*.72,math.pi,math.pi*2)
        end
    end

    -- Distant lights refuse to explain whether they are lamps, eyes or stars.
    for i=1,11 do
        local seed=i*43+region*89
        local x=camera.x+((noise(seed)*width+t*(1+i%3)*.7)%width)
        local y=camera.y+70+noise(seed+1)*(height-150)
        local pulse=.5+.5*math.sin(t*(.35+noise(seed+2)) + seed)
        love.graphics.setColor(color[3][1],color[3][2],color[3][3],.025+pulse*.045)
        love.graphics.circle("fill",x,y,2+pulse*3)
        love.graphics.circle("line",x,y,9+pulse*9)
    end
end

function Atmosphere.worldMotion(camera,region,width,height,t)
    local color=palettes[region] or palettes[6]
    -- Hanging cables, fibrous tendrils and impossible threads all use the same
    -- restrained motion language, growing less mechanical with depth.
    local count=region<3 and 7 or 11
    love.graphics.setLineWidth(region>=4 and 2 or 1)
    for i=1,count do
        local seed=i*97+region*211
        local x=camera.x+((noise(seed)*width-camera.x*.42)%(width+160))-80
        local length=90+noise(seed+2)*260
        local sway=math.sin(t*(.32+noise(seed+4)*.45)+seed)*10*(.4+region*.12)
        love.graphics.setColor(color[2][1],color[2][2],color[2][3],.08)
        love.graphics.line(x,camera.y-15,x+sway,camera.y+length)
        if region>=3 then
            love.graphics.setColor(color[3][1],color[3][2],color[3][3],.08)
            love.graphics.circle("line",x+sway,camera.y+length,3+(i%3)*2)
        end
    end
    love.graphics.setLineWidth(1)
end

function Atmosphere.lightVolume(player,region,t)
    if not player.lanternOn or (player.light or 0)<=0 then return end
    local cx,cy=player.x+player.w/2+player.facing*12,player.y+player.h*.42
    local strength=math.min(1,(player.light or 0)/28)
    local reach=155+strength*115
    local flutter=math.sin(t*8.3)*2+math.sin(t*17.1)*.8
    local direction=player.facing
    for layer=5,1,-1 do
        local spread=34+layer*15
        local alpha=(.008+layer*.004)*strength
        love.graphics.setColor(1,.65,.25,alpha)
        love.graphics.polygon("fill",cx,cy-5,cx+direction*reach,cy-spread+flutter,cx+direction*reach,cy+spread+flutter,cx,cy+6)
    end
    -- Dust becomes visible only while crossing the cone.
    for i=1,18 do
        local seed=i*67+region*19
        local travel=(noise(seed)+t*(.012+noise(seed+3)*.018))%1
        local x=cx+direction*(24+travel*(reach-30))
        local radius=(18+travel*58)*(noise(seed+1)*2-1)
        local y=cy+radius+math.sin(t*.7+seed)*5
        love.graphics.setColor(1,.75,.39,.08*(1-travel)*strength)
        love.graphics.circle("fill",x,y,1+noise(seed+5)*1.6)
    end
end

function Atmosphere.foreground(camera,region,width,height,t)
    local color=palettes[region] or palettes[6]
    -- A few close links stay in the outer margin, never over the play space.
    love.graphics.setLineWidth(3)
    for side=-1,1,2 do
        local edge=camera.x+(side<0 and 12 or width-12)
        for link=0,8 do
            local y=camera.y+link*18-((camera.y*.14)%18)
            local x=edge+math.sin(t*.3+link*.15)*3
            love.graphics.setColor(.09,.075,.09,.65)
            if region<4 then love.graphics.ellipse('line',x,y,3,7)
            else love.graphics.line(x,y,x+side*5,y+11,x,y+20) end
        end
    end
    love.graphics.setLineWidth(1)
    -- Close silhouettes create occlusion at the screen edge and sell scale.
    love.graphics.setColor(color[1][1]*.45,color[1][2]*.45,color[1][3]*.45,.64)
    for side=-1,1,2 do
        local x=camera.x+(side<0 and -32 or width+32)
        local sway=math.sin(t*.24+side+region)*8
        love.graphics.ellipse("fill",x+sway,camera.y+height*.55,62+region*5,height*.72)
        if region>=4 then
            for i=1,5 do
                local y=camera.y+height*(.18+i*.13)
                love.graphics.line(x,y,x-side*(45+i*5)+sway,y-24+math.sin(t*.5+i)*11)
            end
        end
    end
end

return Atmosphere
