-- Fixed pencil marks: no random shimmer, new instructions or puzzle symbols.
local D={}
local function stroke(points)
 local g=love.graphics
 g.setColor(.29,.21,.19,.42); g.setLineWidth(1.2); g.line(points)
end
function D.draw(index,x,y)
 local g=love.graphics
 g.push('all'); g.translate(x,y)
 -- Subtle fibres, an old fold and softly worn corners.
 for i=1,95 do
  local px=12+(i*137)%521; local py=12+(i*83)%522
  g.setColor(.43,.32,.2,.065); g.line(px,py,px+3+i%4,py+.7)
 end
 g.setColor(.49,.37,.24,.08); g.line(272,8,276,195,273,365,278,540)
 g.setColor(.98,.9,.73,.12); g.line(274,8,278,195,275,365,280,540)
 stroke({12,38,35,13,60,12}); stroke({507,536,531,515,536,490})
 if index==1 then
  stroke({59,437,120,435,161,440,225,436,296,439,342,435,471,439})
  stroke({126,245,157,263,192,195,232,249,252,252})
  stroke({182,155,187,149,194,154,198,162})
  for i=1,6 do stroke({88+i*15,322,96+i*15,310}) end
  stroke({170,330,170,236,221,236,221,330})
  for i=1,4 do stroke({180,250+i*15,188,243+i*15}) end
  -- Hair, a dress and small shoes retain the original stick-figure silhouette.
  stroke({382,240,381,226,392,214,410,212,426,225,429,249,421,258})
  stroke({385,233,393,226,403,235,414,225,427,234})
  g.setColor(.37,.24,.29,.13); g.polygon('fill',396,284,414,286,433,365,377,365)
  stroke({396,282,377,365,433,365,414,283})
  stroke({357,430,352,434,368,434}); stroke({446,430,456,434,464,434})
  g.setColor(.29,.2,.2,.65); g.circle('fill',398,242,1.7); g.circle('fill',414,242,1.7)
  stroke({400,251,406,253,411,250})
  for i=1,3 do local px=85+i*48; stroke({px-4,435,px-7,427,px,436,px+4,426}) end
 elseif index==2 then
  for i=1,5 do
   local px,py=80+((i*91)%390),85+i*72
   stroke({px-18,py-11,px-9,py-20,px+6,py-22,px+17,py-12})
   for j=1,3 do stroke({px-12+j*6,py+8,px-5+j*6,py-5}) end
   stroke({px+14,py+27,px+21,py+30,px+28,py+25})
  end
  stroke({62,458,179,359,290,438,469,190})
  for i=1,8 do local px=60+i*48; stroke({px,454-i*4,px+6,451-i*4}) end
 elseif index==3 then
  for i=0,4 do
   local px=45+i*105
   stroke({px+9,87,px+12,186,px+7,265,px+11,414})
   stroke({px+55,88,px+58,195,px+52,284,px+57,424})
   for j=1,4 do stroke({px+14,100+j*65,px+25,106+j*65,px+21,119+j*65}) end
   stroke({px-6,435,px+18,429,px+45,434,px+78,432})
  end
  stroke({252,205,250,191,262,177,283,175,298,193,300,216})
  g.setColor(.39,.24,.32,.12); g.polygon('fill',266,247,285,247,307,343,244,343)
  stroke({267,245,244,343,307,343,284,245})
 elseif index==4 then
  -- Keep the letter legible; only a loose twig and pencil underlining.
  stroke({92,109,130,96,171,102,199,96})
  stroke({105,100,101,86,116,95,125,81,132,95})
  stroke({120,413,210,415,299,412,429,414})
  stroke({428,113,436,102,439,85,446,103,455,107})
 else
  stroke({197,406,197,154,207,118,239,91,274,81,312,93,338,118,353,153,353,406})
  stroke({215,399,215,161,225,136,251,116})
  stroke({334,397,333,171,327,149})
  for i=1,6 do stroke({209,373-i*27,218,364-i*27}) end
  stroke({172,420,203,412,258,417,309,412,374,420})
 end
 g.pop()
end
return D
