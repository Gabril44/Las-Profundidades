local Save = {}

function Save.load()
    if not love.filesystem.getInfo("save.lua") then return nil end
    local ok, chunk = pcall(love.filesystem.load, "save.lua")
    if not ok or not chunk then return nil end
    local worked, data = pcall(chunk)
    return worked and type(data) == "table" and data or nil
end

function Save.write(game)
    if not game.checkpoint then return false end
    local maps, clues, secrets, rescued, enemies, seals, broken, chimes, traps, bindings, bestiary = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
    for i = 1, #(game.mapUnlocked or {}) do
        maps[i] = game.mapUnlocked[i] and true or false
    end
    for i,item in ipairs(game.clues or {}) do clues[i]=item.collected and true or false end
    for i,item in ipairs(game.secrets or {}) do secrets[i]=item.collected and true or false end
    for i = 1, 2 do rescued[i] = game.rescued[i] and true or false end
    for i, enemy in ipairs(game.enemies or {}) do enemies[i] = enemy.dead and true or false; seals[i]=enemy.sealed and true or false end
    for i, brittle in ipairs(game.breakables or {}) do broken[i] = brittle.broken and true or false end
    for i, chime in ipairs(game.chimes or {}) do chimes[i] = chime.broken and true or false end
    for i,plate in ipairs(game.puzzles and game.puzzles.plates or {}) do traps[i]=plate.locked and true or false end
    for i,enemy in ipairs(game.enemies or {}) do
        bindings[i]=0
        for plateIndex,plate in ipairs(game.puzzles and game.puzzles.plates or {}) do if enemy.boundPlate==plate then bindings[i]=plateIndex break end end
    end
    local journalKinds={"custodian","bat","blind","astral"}
    for i,kind in ipairs(journalKinds) do
        bestiary[i]=game.bestiary and game.bestiary.entries[kind] and game.bestiary.entries[kind].stage or 0
    end
    local function bools(values) local out = {}; for i, v in ipairs(values) do out[i] = tostring(v) end; return "{" .. table.concat(out, ",") .. "}" end
    local function nums(values) local out={}; for i,v in ipairs(values) do out[i]=tostring(v or 0) end; return "{"..table.concat(out,",").."}" end
    local text = string.format("return {x=%.3f,y=%.3f,hookLevel=%d,runTime=%.3f,deaths=%d,counterweight=%s,maps=%s,clues=%s,secrets=%s,rescued=%s,enemies=%s,seals=%s,broken=%s,chimes=%s,traps=%s,bindings=%s,bestiary=%s}",
        game.checkpoint.x, game.checkpoint.y, game.hookLevel or 1, game.runTime or 0, game.deaths or 0,
        tostring(game.puzzles and game.puzzles.counterweightSolved or false),
        bools(maps), bools(clues), bools(secrets), bools(rescued), bools(enemies),bools(seals), bools(broken), bools(chimes),bools(traps),nums(bindings),nums(bestiary))
    return love.filesystem.write("save.lua", text)
end

function Save.clear() return love.filesystem.remove("save.lua") end

return Save
