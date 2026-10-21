local Enemies = {}

local function create(spawn,kind,index,tile)
    local w = kind=="astral" and 58 or (kind=="bat" and 46 or 38)
    local h = kind=="astral" and 54 or (kind=="bat" and 25 or 32)
    return {id=index,kind=kind,x=spawn.x,y=spawn.y+tile-h,w=w,h=h,vx=0,vy=0,grounded=false,
        phase=index*1.7,awake=false,introduced=false,impacts=0,windup=0,charging=false,
        chargeTimer=0,targetX=0,stun=0,dead=false,deathTimer=0,soundTimer=0,usedSeals={},tellFXTimer=0,
        voiceTimer=1.5+index*.7,stepSoundTimer=0,lastAwake=false,noise=0,
        soundTargetY=spawn.y,homeX=spawn.x,homeY=spawn.y,wingTimer=0,luredToChime=nil,
        mood="dormant",moodTime=0,lastSensedX=spawn.x,lastSensedY=spawn.y,searchTimer=0,
        variant=(index-1)%3+1,hesitation=.35+(index%4)*.17}
end

function Enemies.fromWorld(findChars,tile)
    local result={}
    local function addAll(marker,kind)
        for _,spawn in ipairs(findChars(marker)) do result[#result+1]=create(spawn,kind,#result+1,tile) end
    end
    addAll("E","custodian"); addAll("G","blind"); addAll("O","astral"); addAll("J","bat")
    return result
end

function Enemies.allDefeated(list)
    for _,enemy in ipairs(list or {}) do if not enemy.dead then return false end end
    return true
end

return Enemies
