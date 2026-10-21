local Audio = {pendingEchoes = {}}

-- Sólo los sonidos que pertenecen físicamente a la cueva reciben cola. La UI,
-- la voz cercana, los pasos y el movimiento conservan precisión y claridad.
local cavernous = {
    impact=true, collapse=true, explosionAir=true, rockCrack=true,
    debrisFall=true, distantCollapse=true, metalCreak=true, timberGroan=true,
    chainRattle=true, pick=true, counterweight=true, mineralBell=true,
    crystalAlarm=true, doorOpen=true, deepRumble=true, custodianRoar=true,
    listenerCall=true, astralVoice=true, batScreech=true, batRoar=true,
    batCrash=true, roots=true, gearJingle=true
    ,caveDrop=true, cavePebble=true, caveGroan=true, astralScream=true,
    astralReturn=true, astralBurst=true
}

local function tone(frequency, duration, volume)
    local rate, samples = 22050, math.floor(22050 * duration)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / rate
        local envelope = math.min(1, t * 18) * math.min(1, (duration - t) * 8)
        local wave = math.sin(t * frequency * math.pi * 2) * .65 + math.sin(t * frequency * .5 * math.pi * 2) * .35
        data:setSample(i, wave * volume * envelope)
    end
    return love.audio.newSource(data, "static")
end

local function sweep(fromFrequency, toFrequency, duration, volume)
    local rate, samples = 22050, math.floor(22050 * duration)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t, progress = i / rate, (i / rate) / duration
        local phase = 2 * math.pi * (fromFrequency * t + (toFrequency - fromFrequency) * t * t / (2 * duration))
        local envelope = math.min(1, t * 24) * math.max(0, 1 - progress) ^ 1.4
        data:setSample(i, math.sin(phase) * volume * envelope)
    end
    return love.audio.newSource(data, "static")
end

local function noise(duration, volume, softness)
    local rate, samples, filtered = 22050, math.floor(22050 * duration), 0
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    softness = softness or .78
    for i = 0, samples - 1 do
        local t = i / rate
        filtered = filtered * softness + (math.random() * 2 - 1) * (1 - softness)
        local envelope = math.min(1, t * 35) * math.max(0, 1 - t / duration) ^ 1.7
        data:setSample(i, filtered * volume * envelope)
    end
    return love.audio.newSource(data, "static")
end

-- A handful of short physical events combined in one buffer.  Keeping these
-- procedural means the demo remains tiny and every ambience sound belongs to
-- the same slightly unreal acoustic world.
local function debris(duration, volume, hits, low)
    local rate, samples = 22050, math.floor(22050 * duration)
    local data, filtered = love.sound.newSoundData(samples, rate, 16, 1), 0
    local events = {}
    for n = 1, hits do
        events[n] = {
            at = math.random() * duration * .86,
            strength = .45 + math.random() * .55,
            frequency = (low or 80) + math.random() * 230
        }
    end
    for i = 0, samples - 1 do
        local t, sample = i / rate, 0
        filtered = filtered * .84 + (math.random() * 2 - 1) * .16
        for _, event in ipairs(events) do
            local age = t - event.at
            if age >= 0 and age < .22 then
                local decay = math.exp(-age * (18 + event.frequency * .025))
                sample = sample + math.sin(age * event.frequency * math.pi * 2) * decay * event.strength
                sample = sample + filtered * decay * event.strength * .55
            end
        end
        data:setSample(i, math.max(-1, math.min(1, sample * volume)))
    end
    return love.audio.newSource(data, "static")
end

local function groan(duration, volume)
    local rate, samples = 22050, math.floor(22050 * duration)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t, p = i / rate, (i / rate) / duration
        local bend = 54 + math.sin(p * math.pi) * 21 + math.sin(p * 8.3) * 3
        local scrape = math.sin(t * bend * math.pi * 2) + math.sin(t * bend * 2.03 * math.pi * 2) * .32
        local envelope = math.sin(math.min(1, p) * math.pi) ^ .65
        data:setSample(i, scrape * volume * envelope)
    end
    return love.audio.newSource(data, "static")
end

-- Subgrave cinematográfico: se percibe como una masa moviéndose bajo la roca,
-- no como una nota. La deriva lenta y el aire filtrado le quitan filo digital.
local function deepRumble(duration, volume)
    local rate, samples = 22050, math.floor(22050 * duration)
    local data, phase, filtered = love.sound.newSoundData(samples, rate, 16, 1), 0, 0
    for i = 0, samples - 1 do
        local t, p = i / rate, (i / rate) / duration
        local frequency = 34 - p * 7 + math.sin(t * 1.7) * 1.8
        phase = phase + frequency * math.pi * 2 / rate
        filtered = filtered * .992 + (math.random() * 2 - 1) * .008
        local body = math.sin(phase) * .72 + math.sin(phase * .503) * .32
        local envelope = math.sin(math.min(1, p) * math.pi) ^ .7
        local tremor = .84 + .16 * math.sin(t * 4.1)
        data:setSample(i, math.max(-1, math.min(1, (body + filtered * .55) * volume * envelope * tremor)))
    end
    return love.audio.newSource(data, "static")
end

-- Una gota grande y lejana: ataque blando, dos resonancias inarmónicas y una
-- cola oscura. Está pensada para aparecer aislada, nunca como metrónomo.
local function caveDrop()
    local rate,duration=22050,1.65
    local data=love.sound.newSoundData(math.floor(rate*duration),rate,16,1)
    for i=0,data:getSampleCount()-1 do
        local t=i/rate
        local strike=math.exp(-t*34)
        local tail=math.exp(-t*2.6)
        local wave=math.sin(t*735*math.pi*2)*strike*.55+
            math.sin(t*413*math.pi*2)*tail*.18+
            math.sin(t*187*math.pi*2)*tail*.08
        data:setSample(i,wave*.12)
    end
    return love.audio.newSource(data,"static")
end

local function astralScream()
    local rate,duration=22050,2.45
    local data=love.sound.newSoundData(math.floor(rate*duration),rate,16,1)
    local phase,air=0,0
    for i=0,data:getSampleCount()-1 do
        local t,p=i/rate,i/data:getSampleCount()
        local frequency=118+math.sin(p*math.pi)*165-p*52+math.sin(t*17)*13
        phase=phase+frequency*math.pi*2/rate
        air=air*.9+(math.random()*2-1)*.1
        local throat=math.sin(phase)+math.sin(phase*1.51)*.38+math.sin(phase*.49)*.24
        local envelope=math.min(1,t*5)*math.max(0,1-p)^.58
        data:setSample(i,math.max(-1,math.min(1,(throat*.68+air*.24)*.23*envelope)))
    end
    return love.audio.newSource(data,"static")
end

local function creatureVoice(base, duration, volume, character)
    local rate, samples = 22050, math.floor(22050 * duration)
    local data, filtered, phase = love.sound.newSoundData(samples, rate, 16, 1), 0, 0
    character = character or 1
    for i = 0, samples - 1 do
        local t, p = i / rate, (i / rate) / duration
        local wobble = math.sin(t * (3.1 + character) * math.pi * 2) * (.08 + character * .015)
        local freq = base * (1 + wobble) * (1 - p * .28)
        phase = phase + freq * math.pi * 2 / rate
        filtered = filtered * (.88 + character * .015) + (math.random() * 2 - 1) * (.12 - character * .015)
        local throat = math.sin(phase) * .52 + math.sin(phase * 1.503) * .23 + math.sin(phase * .497) * .18
        local tremor = math.sin(t * (13 + character * 7)) * .08
        local attack = math.min(1, t * (7 + character * 2))
        local release = math.max(0, 1 - p) ^ (1.1 + character * .15)
        local pulse = .72 + .28 * math.sin(t * (8 + character * 3)) ^ 2
        data:setSample(i, math.max(-1, math.min(1, (throat + filtered * .38 + tremor) * volume * attack * release * pulse)))
    end
    return love.audio.newSource(data, "static")
end

-- Brief voiced formants for dialogue. The changing harmonics imply syllables
-- and breath without turning the procedural murmur into intelligible speech.
local function humanMurmur(base, vowel)
    local rate,duration=22050,.085
    local samples=math.floor(rate*duration)
    local data=love.sound.newSoundData(samples,rate,16,1)
    local phase,filtered=0,0
    for i=0,samples-1 do
        local t,p=i/rate,i/samples
        phase=phase+base*(1-math.sin(p*math.pi)*.055)*math.pi*2/rate
        filtered=filtered*.82+(math.random()*2-1)*.18
        local throat=math.sin(phase)*.62+math.sin(phase*(2.02+vowel*.08))*.2+math.sin(phase*(3.7-vowel*.11))*.1
        local envelope=math.min(1,t*70)*math.max(0,1-p)^1.8
        data:setSample(i,(throat+filtered*.06)*.075*envelope)
    end
    return love.audio.newSource(data,"static")
end

local function jobs()
    return {
        {"hook",function() return tone(185,.12,.16) end},{"release",function() return tone(285,.09,.1) end},
        {"mantle",function() return tone(235,.18,.09) end},{"flash",function() return tone(620,.22,.13) end},
        {"impact",function() return tone(58,.34,.22) end},{"rumble",function() return tone(54,.18,.09) end},
        {"deepRumble",function() return deepRumble(2.35,.105) end},
        {"caveDrop",caveDrop},{"cavePebble",function() return debris(.8,.035,2,64) end},
        {"caveGroan",function() return groan(2.9,.022) end},{"caveAir",function() return noise(3.6,.012,.997) end},
        {"collapse",function() return tone(38,.8,.2) end},{"explosionAir",function() return noise(.72,.28,.5) end},
        {"stoneRain",function() return noise(1.35,.17,.82) end},{"jump",function() return sweep(175,330,.14,.09) end},
        {"land",function() return noise(.16,.18,.72) end},{"step",function() return noise(.075,.075,.68) end},
        {"rope",function() return noise(.09,.055,.92) end},{"lowBattery",function() return tone(92,.16,.07) end},
        {"gearJingle",function() return debris(.19,.055,4,310) end},{"cloth",function() return noise(.13,.035,.9) end},
        {"breath",function() return noise(.36,.028,.975) end},
        {"pick",function() return noise(.11,.17,.55) end},{"hurt",function() return sweep(170,62,.28,.14) end},
        {"discovery",function() return sweep(310,690,.48,.09) end},{"refuge",function() return tone(220,.58,.075) end},
        {"alert",function() return sweep(82,260,.38,.13) end},{"charge",function() return sweep(145,48,.52,.18) end},
        {"guardianDown",function() return sweep(118,31,.9,.2) end},{"lift",function() return sweep(48,145,1.1,.13) end},
        {"astralScream",astralScream},{"astralReturn",function() return sweep(440,27,2.35,.18) end},
        {"astralBurst",function() return noise(1.05,.24,.86) end},
        {"caveWind",function() return noise(1.8,.035,.985) end},{"metalCreak",function() return sweep(74,46,.7,.045) end},
        {"deepWhisper",function() return sweep(190,82,1.2,.025) end},{"astralPulse",function() return tone(132,.85,.035) end},
        {"stoneTicks",function() return debris(1.15,.085,7,115) end},{"debrisFall",function() return debris(2.1,.12,15,62) end},
        {"rockCrack",function() return debris(.72,.18,4,42) end},{"chainRattle",function() return debris(1.3,.075,12,240) end},
        {"timberGroan",function() return groan(1.75,.055) end},{"distantCollapse",function() return debris(2.8,.14,24,31) end},
        {"custodianBreath",function() return creatureVoice(48,.8,.15,1) end},{"custodianRoar",function() return creatureVoice(71,1.15,.22,1) end},
        {"custodianStep",function() return debris(.28,.11,1,24) end},{"listenerCall",function() return creatureVoice(185,1.4,.09,3) end},
        {"listenerSkitter",function() return debris(.38,.08,8,210) end},{"astralVoice",function() return creatureVoice(112,1.8,.11,2) end},
        {"astralHurt",function() return creatureVoice(245,.65,.14,3) end},{"batScreech",function() return creatureVoice(430,.72,.09,3) end},
        {"batFlutter",function() return noise(.24,.045,.76) end},{"batRoar",function() return creatureVoice(235,1.08,.14,2) end},
        {"mineralBell",function() return sweep(760,310,1.25,.11) end},{"batCrash",function() return debris(.85,.18,13,48) end},
        {"crystalAlarm",function() return sweep(980,240,1.1,.1) end},{"counterweight",function() return debris(.42,.3,9,38) end},
        {"roots",function() return creatureVoice(72,.8,.08,2) end},{"doorOpen",function() return sweep(58,185,2.2,.18) end},
        {"cityRush",function() return noise(1.65,.07,.965) end},{"cityDrone",function() return tone(43,1.55,.045) end},
        {"travelWhoosh",function() return sweep(115,520,.34,.11) end},{"forestRush",function() return noise(1.8,.095,.91) end},
        {"branchPass",function() return debris(.72,.1,8,170) end},{"mineApproach",function() return sweep(92,41,1.25,.095) end},
        {"tunnelRush",function() return noise(1.05,.16,.84) end},{"tunnelPulse",function() return sweep(48,235,.85,.12) end},
        {"humanVoice1",function() return humanMurmur(108,1) end},{"humanVoice2",function() return humanMurmur(115,2) end},
        {"humanVoice3",function() return humanMurmur(102,3) end}
    }
end

function Audio.beginLoad(settings)
    Audio.settings = settings
    Audio.pendingEchoes = {}
    local list = jobs()
    return {}, {jobs=list,index=1,total=#list,failed=0,done=false}
end

function Audio.loadStep(sounds,loader,count)
    count = count or 2
    for _=1,count do
        local job=loader.jobs[loader.index]
        if not job then loader.done=true; break end
        local ok,result=pcall(job[2])
        if ok then sounds[job[1]]=result else loader.failed=loader.failed+1 end
        loader.index=loader.index+1
    end
    if loader.index>loader.total then loader.done=true end
    return loader.done,(loader.index-1)/loader.total
end

function Audio.load(settings)
    local sounds,loader=Audio.beginLoad(settings)
    while not loader.done do Audio.loadStep(sounds,loader,4) end
    return sounds
end

function Audio.play(sounds, name, jitter)
    local source = sounds and sounds[name]
    if not source then return end
    -- Clones allow a distant collapse to keep ringing while a pebble or a
    -- gameplay sound starts; static Source data is shared, so this stays cheap.
    local voice = source:clone()
    voice:setVolume((Audio.settings and Audio.settings.effectsVolume or 1))
    local basePitch = 1 + (math.random() * 2 - 1) * (jitter or (name == "step" and .1 or .025))
    voice:setPitch(basePitch)
    voice:play()
    if cavernous[name] then
        -- Dos respuestas desiguales: una pared cercana y una galería enorme.
        -- Bajar tono y volumen simula la absorción de aire, tierra y roca.
        Audio.pendingEchoes[#Audio.pendingEchoes+1] = {source=source,delay=.19,gain=.22,pitch=basePitch*.91}
        Audio.pendingEchoes[#Audio.pendingEchoes+1] = {source=source,delay=.53,gain=.085,pitch=basePitch*.82}
    end
end

function Audio.update(dt)
    for i = #Audio.pendingEchoes, 1, -1 do
        local echo = Audio.pendingEchoes[i]
        echo.delay = echo.delay - dt
        if echo.delay <= 0 then
            local voice = echo.source:clone()
            voice:setVolume((Audio.settings and Audio.settings.effectsVolume or 1) * echo.gain)
            voice:setPitch(echo.pitch)
            voice:play()
            table.remove(Audio.pendingEchoes, i)
        end
    end
end

function Audio.clearEchoes()
    Audio.pendingEchoes = {}
end

function Audio.shutdown()
    Audio.pendingEchoes={}
    -- Las voces se crean como clones, por lo que detener solamente las fuentes
    -- guardadas no alcanza. love.audio.stop corta también ecos y colas activas.
    if love and love.audio then pcall(love.audio.stop) end
end

return Audio
