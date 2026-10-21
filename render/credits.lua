local C={start=15,duration=14}
function C.finished(t) return t>=C.start+C.duration end
function C.draw(t,game,pad)
 if t<C.start then return end
 local g=love.graphics; local age=t-C.start
 local fade=math.min(1,age/1.2)
 g.push('all')
 g.setColor(.006,.004,.012,fade); g.rectangle('fill',0,0,1280,720)
 local alpha=math.max(0,math.min(1,(age-.7)/1.2,(C.duration-age)/1.5))
 g.translate(640,260); g.rotate(age*.035)
 g.setColor(.42,.27,.63,alpha*.2); g.circle('line',0,0,83)
 g.polygon('line',0,-67,45,0,0,67,-45,0)
 g.rotate(-age*.035); g.translate(-640,-260)
 g.setFont(game.titleFont); g.setColor(.84,.76,.59,alpha)
 g.printf('LAS PROFUNDIDADES',0,233,1280,'center')
 g.setFont(game.smallFont); g.setColor(.63,.59,.68,alpha)
 g.printf('DEVELOPED BY',0,365,1280,'center')
 g.setFont(game.font); g.setColor(.9,.77,.53,alpha)
 g.printf('leshuggah',0,397,1280,'center')
 g.setFont(game.smallFont); g.setColor(.65,.58,.72,alpha)
 g.printf('Hecho con LÖVE',0,455,1280,'center')
 g.printf('Gracias por descender.',0,518,1280,'center')
 g.setColor(.48,.45,.52,alpha)
 g.printf(pad and 'A / START  ·  VOLVER AL MENÚ' or 'ENTER / ESC  ·  VOLVER AL MENÚ',0,650,1280,'center')
 g.pop()
end
return C
