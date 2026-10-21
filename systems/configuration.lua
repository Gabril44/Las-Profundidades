local Settings=require('game.settings')
local Bindings=require('systems.bindings')
local C={page='settings',index=1,capture=nil,message=''}
C.rows={
 {label='VOLUMEN DE EFECTOS',key='effectsVolume',step=.1,min=0,max=1},
 {label='TEMBLOR DE CÁMARA',key='cameraShake',step=.25,min=0,max=1},
 {label='ASISTENCIA DEL GANCHO',key='hookAssist',step=.25,min=.5,max=1.5},
 {label='ANCLAJES DE ALTO CONTRASTE',key='highContrastAnchors'},
 {label='MANTENER PARA USAR GANCHO',key='holdToGrapple'},
 {label='INTENSIDAD DE DESTELLOS',key='flashIntensity',step=.25,min=.25,max=1},
 {label='VIBRACIÓN',key='vibration'},
 {label='CONTROLES DEL TECLADO',page='keyboard'},
 {label='CONTROLES DEL JOYSTICK',page='gamepad'},
 {label='SALIR DEL JUEGO',quit=true}
}
function C.count() return C.page=='settings' and #C.rows or #Bindings.actions+2 end
function C.open() C.page='settings'; C.index=1; C.capture=nil; C.message='' end
function C.cancel(game)
 if C.capture then C.capture=nil; C.message='Asignación cancelada.'
 elseif C.page~='settings' then C.page='settings'; C.index=1; C.message=''
 else game.paused=false end
end
function C.receive(device,value)
 if not C.capture then return false end
 if device~=C.page then return true end
 local ok,message=Bindings.assign(device,C.capture,value)
 C.message=message
 if ok then C.capture=nil end
 return true
end
function C.key(game,key)
 if key=='escape' then C.cancel(game); return end
 if C.capture then C.receive('keyboard',key); return end
 if key=='up' or key=='w' then C.index=(C.index-2)%C.count()+1; return end
 if key=='down' or key=='s' then C.index=C.index%C.count()+1; return end
 local confirm=key=='return' or key=='kpenter'
 local dir=(key=='left' or key=='a') and -1 or 1
 if not (confirm or key=='left' or key=='a' or key=='right' or key=='d') then return end
 if C.page=='settings' then
  local row=C.rows[C.index]
  if row.page and confirm then C.page=row.page; C.index=1; C.message=''; return end
  if row.quit and confirm then love.event.quit(); return end
  if row.key then
   if row.step then game.settings[row.key]=math.max(row.min,math.min(row.max,game.settings[row.key]+dir*row.step))
   else game.settings[row.key]=not game.settings[row.key] end
   C.message=Settings.save(game.settings) and '' or 'No se pudo guardar en disco.'
  end
 elseif confirm then
  if C.index<=#Bindings.actions then C.capture=Bindings.actions[C.index].id; C.message=''
  elseif C.index==#Bindings.actions+1 then
   Bindings.reset(C.page); C.message=Bindings.save() and 'Controles originales restaurados.' or 'Aplicado. No se pudo guardar en disco.'
  else C.cancel(game) end
 end
end
function C.gamepad(game,button)
 if button=='start' then C.cancel(game); return end
 if C.capture then C.receive('gamepad',button); return end
 if button=='b' then C.cancel(game); return end
 local key=({a='return',dpup='up',dpdown='down',dpleft='left',dpright='right'})[button]
 if key then C.key(game,key) end
end
return C
