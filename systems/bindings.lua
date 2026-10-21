local B={}
B.actions={
 {id='left',label='MOVER A LA IZQUIERDA',key='a',pad='dpleft',canonical='left'},
 {id='right',label='MOVER A LA DERECHA',key='d',pad='dpright',canonical='right'},
 {id='up',label='TREPAR / ACORTAR CUERDA',key='w',pad='dpup',canonical='up'},
 {id='down',label='BAJAR / ALARGAR CUERDA',key='s',pad='dpdown',canonical='down'},
 {id='jump',label='SALTAR / SOLTARSE',key='space',pad='a',canonical='space'},
 {id='hook',label='GANCHO / INTERACTUAR',key='e',pad='x',canonical='e'},
 {id='pick',label='PICO',key='f',pad='b',canonical='f'},
 {id='flash',label='DESTELLO',key='q',pad='y',canonical='q'},
 {id='light',label='LINTERNA',key='l',pad='leftshoulder',canonical='l'},
 {id='map',label='MAPA / CUADERNO',key='tab',pad='back',canonical='tab'},
 {id='refuge',label='VOLVER AL REFUGIO',key='r',pad='rightstick',canonical='r'}
}
local validPad={a=true,b=true,x=true,y=true,back=true,leftshoulder=true,rightshoulder=true,leftstick=true,rightstick=true,dpup=true,dpdown=true,dpleft=true,dpright=true}
local names={space='ESPACIO',tab='TAB',leftshoulder='LB',rightshoulder='RB',back='VIEW',leftstick='LS CLICK',rightstick='RS CLICK',dpup='CRUCETA ARRIBA',dpdown='CRUCETA ABAJO',dpleft='CRUCETA IZQ.',dpright='CRUCETA DER.',up='ARRIBA',down='ABAJO',left='IZQUIERDA',right='DERECHA'}
B.values={keyboard={},gamepad={}}
function B.reset(device)
 for _,a in ipairs(B.actions) do B.values[device][a.id]=device=='keyboard' and a.key or a.pad end
end
function B.valid(device,value)
 if type(value)~='string' then return false end
 if device=='gamepad' then return validPad[value] or false end
 -- UI navigation and debug remain recoverable independently of the bindings.
 return value~='escape' and value~='return' and value~='kpenter' and not value:match('^f%d+$') and value~='unknown' and #value>0 and #value<32
end
function B.load()
 B.reset('keyboard'); B.reset('gamepad')
 if not love.filesystem.getInfo('controls.lua') then return end
 local ok,chunk=pcall(love.filesystem.load,'controls.lua')
 if not ok or not chunk then return end
 local success,data=pcall(chunk)
 if not success or type(data)~='table' then return end
 for _,device in ipairs({'keyboard','gamepad'}) do
  local used,candidate={},{}; local valid=type(data[device])=='table'
  for _,a in ipairs(B.actions) do
   local value=valid and data[device][a.id]
   if not B.valid(device,value) or used[value] then valid=false; break end
   used[value]=true; candidate[a.id]=value
  end
  if valid then B.values[device]=candidate end
 end
end
function B.save()
 local out={'return {'}
 for _,device in ipairs({'keyboard','gamepad'}) do
  out[#out+1]=device..'={'
  for _,a in ipairs(B.actions) do out[#out+1]=string.format('[%q]=%q,',a.id,B.values[device][a.id]) end
  out[#out+1]='},'
 end
 out[#out+1]='}'
 return love.filesystem.write('controls.lua',table.concat(out))
end
function B.assign(device,id,value)
 if not B.valid(device,value) then return false,'Reservado para menús o depuración.' end
 local previous=B.values[device][id]; local swapped
 for _,a in ipairs(B.actions) do
  if a.id~=id and B.values[device][a.id]==value then B.values[device][a.id]=previous; swapped=a.label end
 end
 B.values[device][id]=value
 local ok=B.save()
 return true,not ok and 'Aplicado. No se pudo guardar en disco.' or (swapped and 'Intercambiado con '..swapped or 'Control guardado.')
end
function B.key(device,value)
 for _,a in ipairs(B.actions) do if B.values[device][a.id]==value then return a.canonical end end
end
function B.label(id,device)
 local value=B.values[device or 'keyboard'][id] or '?'
 return names[value] or value:upper()
end
B.reset('keyboard'); B.reset('gamepad')
return B
