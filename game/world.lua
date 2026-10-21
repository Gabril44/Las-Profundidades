local World = {width = 52, height = 134, regionHeight = 22}

World.regionNames = {"MINAS ABANDONADAS","LOS CONTRAPESOS","CÁMARA RESONANTE","JARDÍN CIEGO","CIUDAD QUE RECUERDA","EL FARO IMPOSIBLE"}
World.debugSpawns = {{x=4,y=3},{x=8,y=25},{x=11,y=47},{x=7,y=69},{x=33,y=91},{x=9,y=113}}

function World.regionForRow(row) return math.max(1,math.min(#World.regionNames,math.floor((row-1)/World.regionHeight)+1)) end
function World.regionRows(region) local first=(region-1)*World.regionHeight+1; return first,math.min(World.height,first+World.regionHeight-1) end

function World.build()
 local grid={}; for y=1,World.height do grid[y]={}; for x=1,World.width do grid[y][x]="." end end
 for x=1,World.width do grid[1][x],grid[World.height][x]="#","#" end
 for y=1,World.height do grid[y][1],grid[y][World.width]="#","#" end
 local function put(x,y,c) if grid[y] and grid[y][x] then grid[y][x]=c end end
 local function platform(x,y,n,c) for px=x,math.min(World.width-1,x+n-1) do put(px,y,c or "#") end end
 local function wall(x,a,b,c) for y=a,b do put(x,y,c or "#") end end

 -- 1. La entrada original.
 put(1,2,"W"); put(1,3,"W"); put(4,3,"S"); platform(2,4,12,"R")
 platform(14,8,9); put(18,7,"A"); put(26,9,"A"); put(20,7,"D")
 platform(30,12,10); put(35,11,"A"); put(32,11,"N")
 platform(40,16,10); put(45,15,"A"); put(43,15,"E"); wall(50,11,15,"X")
 platform(23,20,11); put(36,17,"A"); put(28,19,"A"); put(25,19,"M"); put(31,19,"K"); wall(33,17,19,"B")
 platform(2,22,12,"R"); put(6,21,"C"); put(11,21,"A")

 -- 2. Los Contrapesos: dos Custodios y placas que sostienen el ascensor.
 platform(7,26,12); put(12,25,"A"); put(18,25,"E"); put(20,24,"A")
 -- El primer borde desemboca claramente en el encastre del piso medio.
 platform(22,30,27); put(34,29,"E"); put(23,29,"f"); wall(49,28,31,"R"); put(48,29,"R")
 -- El segundo borde cae en sentido contrario sobre el encastre inferior.
 platform(2,35,20); put(20,34,"f"); put(16,34,"j"); put(14,34,"A"); put(19,32,"A"); wall(22,33,36,"R"); put(3,34,"R")
 platform(23,39,7,"p"); platform(31,37,7,"p"); platform(39,35,7,"p")
 put(27,35,"A"); put(35,33,"A"); put(43,31,"A")
 platform(2,44,50,"R"); put(26,44,"b"); put(5,43,"C"); put(10,43,"M"); put(13,43,"D"); put(17,41,"U")

 -- 3. Cámara Resonante.
 platform(10,48,11); put(15,47,"A"); put(21,45,"A")
 platform(27,52,18); put(31,51,"Y"); put(36,51,"Y"); put(41,51,"Y"); put(43,49,"J")
 platform(5,57,13); put(9,56,"A"); put(14,56,"Y"); wall(19,53,56,"g")
 platform(24,61,18); put(33,58,"A")
 -- Las dos campanas obligan a cruzar toda la Cámara Resonante: primero puede
 -- descubrirse cualquiera, pero el segundo eco siempre espera al otro extremo.
 put(4,65,"T"); put(47,65,"T")
 -- El anclaje sobre la abertura permite regresar desde el Jardín cuando el
 -- sello resonante está abierto; tira al jugador centrado por el canal.
 put(26,64,"A")
 platform(2,66,50,"R"); put(26,66,"g"); put(41,65,"E"); wall(49,62,65,"X"); put(45,65,"M")

 -- 4. Jardín Ciego: r se endurece con luz; o sostiene en oscuridad.
 platform(4,70,13,"R"); put(8,69,"C"); put(15,69,"A"); put(25,69,"A")
 wall(23,69,74,"r"); platform(27,74,13,"o"); put(32,71,"A"); put(39,73,"D")
 -- Columna de regreso: no crea suelo ni evita comprender las raíces. Une los
 -- agarres inferiores con la entrada mediante saltos encadenados de gancho.
 put(20,73,"A"); put(27,76,"A")
 platform(7,79,12,"r"); put(12,76,"A"); wall(20,78,82,"o")
 platform(24,83,16,"R"); put(29,82,"A"); put(36,80,"A"); put(38,82,"N")
 platform(2,88,50,"R"); put(25,88,"r"); put(44,85,"A"); put(46,87,"M"); put(34,87,"K")

 -- 5. Ciudad que recuerda: el destello materializa puentes de sombra.
 -- Un aro adelantado sobre el borde izquierdo completa la subida desde el
 -- agarre central sin convertir la fogata en un salto de alcance máximo.
 platform(31,92,15,"R"); put(33,90,"A"); put(36,91,"C"); put(41,91,"A")
 platform(12,96,13,"i"); put(17,93,"A"); put(27,94,"A")
 platform(3,102,15,"R"); put(8,101,"G"); wall(2,97,101,"X")
 -- El sello del Oyente espera en otra plataforma. La criatura evita la runa
 -- durante su patrulla y sólo salta hacia ella al perseguir un ruido reciente.
 platform(25,106,18,"i"); put(28,105,"Z"); put(30,103,"A"); put(38,105,"D"); put(42,105,"M")
 platform(2,110,50,"R"); put(25,110,"s"); put(46,109,"A"); put(33,109,"U")

 -- 6. Faro imposible: los caminos existen solamente dentro del aura del Vigía.
 platform(8,114,11); put(13,113,"A"); put(17,113,"Z"); put(23,111,"V")
 platform(27,118,13,"m"); put(29,117,"Z"); put(34,115,"V"); put(40,117,"M")
 platform(40,122,10,"m"); put(47,121,"Z"); put(45,119,"V"); put(29,121,"V")
 platform(18,126,12,"m"); put(24,123,"V"); put(21,125,"U"); put(28,125,"K")
 platform(2,129,50,"R"); put(26,129,"n")
 platform(6,130,5,"H"); platform(17,130,5,"H"); platform(27,130,4,"H")
 platform(34,133,16,"R"); put(41,132,"O")
 platform(2,133,12,"R"); put(4,132,"L"); put(7,132,"C"); put(11,132,"A"); put(9,132,"D")

 local rows={}; for y=1,World.height do rows[y]=table.concat(grid[y]) end; return rows
end
return World
