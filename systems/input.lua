local Input = {joystick = nil, aimX = 0, aimY = 0, lastDevice = "keyboard"}
local Bindings=require('systems.bindings')
Input.bindings=Bindings

function Input.update()
    local sticks = love.joystick.getJoysticks()
    Input.joystick = nil
    for _,stick in ipairs(sticks) do if stick:isGamepad() then Input.joystick=stick; break end end
    if Input.joystick and Input.joystick:isGamepad() then
        Input.aimX, Input.aimY = Input.joystick:getGamepadAxis("rightx"), Input.joystick:getGamepadAxis("righty")
        local lx,ly=Input.joystick:getGamepadAxis("leftx"),Input.joystick:getGamepadAxis("lefty")
        if math.abs(lx)>.2 or math.abs(ly)>.2 or math.abs(Input.aimX)>.25 or math.abs(Input.aimY)>.25 then Input.lastDevice="gamepad" end
    else Input.aimX, Input.aimY = 0, 0 end
end

local defaultDirections={left='a',right='d',up='w',down='s'}
local function keyboardDown(action)
 local key=Bindings.values.keyboard[action]
 if key and love.keyboard.isDown(key) then return true end
 return defaultDirections[action]==key and not Bindings.key('keyboard',action) and love.keyboard.isDown(action) or false
end

function Input.moveX()
    local keys=Bindings.values.keyboard
    local keyboard = (keyboardDown('right') and 1 or 0) - (keyboardDown('left') and 1 or 0)
    if keyboard ~= 0 then Input.lastDevice="keyboard"; return keyboard end
    if Input.joystick then
        local axis = Input.joystick:getGamepadAxis("leftx")
        if math.abs(axis) > .18 then return axis end
        local buttons=Bindings.values.gamepad
        return (Input.joystick:isGamepadDown(buttons.right) and 1 or 0)-(Input.joystick:isGamepadDown(buttons.left) and 1 or 0)
    end
    return 0
end

function Input.isDown(action)
    local key=Bindings.values.keyboard[action]
    if keyboardDown(action) then return true end
    if not Input.joystick then return false end
    local vertical=Input.joystick:getGamepadAxis('lefty')
    if action=='up' and vertical < -.3 then return true end
    if action=='down' and vertical > .3 then return true end
    local button=Bindings.values.gamepad[action]
    return button and Input.joystick:isGamepadDown(button) or false
end

function Input.usingAimStick() return math.sqrt(Input.aimX^2 + Input.aimY^2) > .35 end

function Input.noteKeyboard() Input.lastDevice="keyboard" end
function Input.noteGamepad() Input.lastDevice="gamepad" end
function Input.usingGamepad() return Input.lastDevice=="gamepad" and Input.joystick~=nil end

function Input.gamepadKey(button)
    return button=='start' and 'escape' or Bindings.key('gamepad',button) or (button=='rightshoulder' and 'e' or nil)
end

function Input.keyboardKey(key)
    if key=='escape' or key:match('^f%d+$') then return key end
    local mapped=Bindings.key('keyboard',key)
    if mapped then return mapped end
    if defaultDirections[key] and Bindings.values.keyboard[key]==defaultDirections[key] then return key end
end
function Input.label(action)
    return Bindings.label(action,Input.usingGamepad() and 'gamepad' or 'keyboard')
end

return Input
