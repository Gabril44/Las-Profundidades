local Ambience = {timer = 24, detailTimer = 48}

local profiles = {
    [1] = {
        main = {"deepRumble", "timberGroan"},
        detail = {"deepWhisper"}, interval = {26, 44}
    },
    [2] = {
        main = {"deepRumble", "timberGroan", "caveWind"},
        detail = {"deepWhisper"}, interval = {23, 41}
    },
    [3] = {
        main = {"deepRumble", "deepWhisper", "timberGroan"},
        detail = {"caveWind"}, interval = {21, 38}
    },
    [4] = {
        main = {"deepRumble", "deepWhisper", "caveWind"},
        detail = {"timberGroan"}, interval = {19, 35}
    }
}

local function choose(list)
    return list[math.random(#list)]
end

function Ambience.update(dt, region, play)
    Ambience.timer = Ambience.timer - dt
    Ambience.detailTimer = Ambience.detailTimer - dt
    local profile = profiles[region] or profiles[4]

    if Ambience.timer <= 0 then
        play(choose(profile.main), .035)
        Ambience.timer = profile.interval[1] + math.random() * (profile.interval[2] - profile.interval[1])
    end

    -- A rare second layer gives the cave depth without filling every silence.
    if Ambience.detailTimer <= 0 then
        play(choose(profile.detail), .025)
        Ambience.detailTimer = 44 + math.random() * 34
    end
end

function Ambience.reset(silence)
    local pause=silence or 18
    Ambience.timer, Ambience.detailTimer = pause + math.random() * 8, pause + 28 + math.random() * 18
end

return Ambience
