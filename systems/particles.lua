local Particles = {}

function Particles.spawn(list,x,y,count,color,forceX,forceY)
    if not list then return end
    for _=1,count do
        list[#list+1]={x=x,y=y,vx=(math.random()*2-1)*(forceX or 90),vy=-math.random()*(forceY or 80),
            life=.3+math.random()*.35,maxLife=.65,size=2+math.random()*3,color=color or {.5,.42,.35}}
    end
end

function Particles.emit(list, options)
    if not list then return end
    local o = options or {}
    for _=1,(o.count or 6) do
        local angle = (o.angle or -math.pi/2) + (math.random()*2-1)*(o.spread or math.pi)
        local speed = (o.speed or 100) * (.45 + math.random()*.75)
        list[#list+1]={x=o.x or 0,y=o.y or 0,vx=math.cos(angle)*speed+(o.baseVX or 0),
            vy=math.sin(angle)*speed+(o.baseVY or 0),life=o.life or (.25+math.random()*.3),
            maxLife=o.life or .55,size=(o.size or 2)*( .65+math.random()*.7),color=o.color or {.5,.42,.35},
            kind=o.kind or "square",gravity=o.gravity==nil and 260 or o.gravity,drag=o.drag or .08,
            rotation=math.random()*math.pi*2,spin=(math.random()*2-1)*8}
    end
end

function Particles.update(list,dt)
    for i=#list,1,-1 do
        local p=list[i]; p.life=p.life-dt; p.vy=p.vy+(p.gravity or 260)*dt
        p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt; p.vx=p.vx*math.pow(p.drag or .08,dt)
        p.rotation=(p.rotation or 0)+(p.spin or 0)*dt
        if p.life<=0 then table.remove(list,i) end
    end
end

function Particles.draw(list)
    for _,p in ipairs(list) do
        love.graphics.setColor(p.color[1],p.color[2],p.color[3],math.max(0,math.min(1,p.life/p.maxLife)))
        if p.kind=="spark" then
            love.graphics.setLineWidth(math.max(1,p.size*.55)); love.graphics.line(p.x,p.y,p.x-p.vx*.035,p.y-p.vy*.035); love.graphics.setLineWidth(1)
        elseif p.kind=="ring" then
            love.graphics.circle("line",p.x,p.y,p.size*(1+(1-p.life/p.maxLife)*4))
        elseif p.kind=="dust" then
            love.graphics.circle("fill",p.x,p.y,p.size*(.5+p.life/p.maxLife))
        else
            love.graphics.push(); love.graphics.translate(p.x,p.y); love.graphics.rotate(p.rotation or 0)
            love.graphics.rectangle("fill",-p.size/2,-p.size/2,p.size,p.size); love.graphics.pop()
        end
    end
end

return Particles
