local Settings = {}

Settings.defaults = {
    effectsVolume = .85,
    cameraShake = 1,
    hookAssist = 1,
    highContrastAnchors = false,
    holdToGrapple = false,
    flashIntensity = 1,
    vibration = true,
}

function Settings.load()
    local result = {}
    for key, value in pairs(Settings.defaults) do result[key] = value end
    if love.filesystem.getInfo("settings.lua") then
        local ok, chunk = pcall(love.filesystem.load, "settings.lua")
        if ok and chunk then
            local worked, data = pcall(chunk)
            if worked and type(data) == "table" then
                for key, value in pairs(data) do if result[key] ~= nil then result[key] = value end end
            end
        end
    end
    return result
end

function Settings.save(data)
    local text = string.format("return {effectsVolume=%s,cameraShake=%s,hookAssist=%s,highContrastAnchors=%s,holdToGrapple=%s,flashIntensity=%s,vibration=%s}",
        data.effectsVolume, data.cameraShake, data.hookAssist, tostring(data.highContrastAnchors), tostring(data.holdToGrapple),data.flashIntensity,tostring(data.vibration))
    return love.filesystem.write("settings.lua", text)
end

return Settings
