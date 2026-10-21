local C=require('systems.configuration')
local B=require('systems.bindings')
local R={}
function R.draw(game,pad)
 local g=love.graphics
 g.setColor(.02,.022,.038,.96); g.rectangle('fill',337,110,875,533,12)
 g.setColor(.46,.37,.25); g.rectangle('line',337,110,875,533,12)
 g.setFont(game.font); g.setColor(.9,.76,.5)
 g.print(C.page=='settings' and 'CONFIGURACIÓN' or (C.page=='keyboard' and 'TECLADO' or 'JOYSTICK'),365,129)
 local count=C.count(); local first=math.max(1,math.min(C.index-8,count-9))
 g.setFont(game.smallFont)
 for i=first,math.min(count,first+9) do
  local y=174+(i-first)*37; local label,value
  if C.page=='settings' then
   local row=C.rows[i]; label=row.label
   value=row.key and (row.step and string.format('%d%%',math.floor(game.settings[row.key]*100+.5)) or (game.settings[row.key] and 'SÍ' or 'NO')) or (pad and 'A' or 'ENTER')
  else
   local action=B.actions[i]
   label=action and action.label or (i==#B.actions+1 and 'RESTAURAR ORIGINALES' or 'VOLVER')
   value=action and B.label(action.id,C.page) or (pad and 'A' or 'ENTER')
  end
  if i==C.index then
   g.setColor(.24,.17,.1,.85); g.rectangle('fill',351,y-7,846,32,4)
   g.setColor(.95,.71,.32); g.polygon('fill',358,y+2,364,y+7,358,y+12)
  end
  g.setColor(i==C.index and {.96,.83,.59} or {.67,.68,.72})
  g.print(label,378,y); g.printf(value,850,y,325,'right')
 end
 g.setColor(.6,.57,.65)
 g.printf(C.page=='gamepad' and 'LS mover / trepar · RS apuntar · START pausa · RB gancho si está libre' or 'ESC y ENTER permanecen disponibles para navegar.',361,552,820,'center')
 g.setColor(.88,.7,.39); g.printf(C.message,361,578,820,'center')
 g.setColor(.72,.72,.77)
 g.printf(pad and 'CRUCETA elegir  ·  A aceptar  ·  B / START volver' or 'W/S o flechas elegir  ·  ENTER aceptar  ·  ESC volver',350,615,845,'center')
 if C.capture then
  g.setColor(.006,.007,.015,.94); g.rectangle('fill',347,254,855,158,8)
  g.setColor(.92,.76,.43); g.setFont(game.font)
  g.printf(C.page=='keyboard' and 'PRESIONÁ UNA TECLA' or 'PRESIONÁ UN BOTÓN DEL JOYSTICK',370,280,805,'center')
  g.setFont(game.smallFont); g.setColor(.8,.81,.85)
  g.printf('Si ya está asignado, se intercambian las dos acciones.',370,327,805,'center')
  g.printf('ESC / START cancela.   '..C.message,370,363,805,'center')
 end
end
return R
