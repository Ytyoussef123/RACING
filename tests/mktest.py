import sys
src=sys.argv[1] if len(sys.argv)>1 else 'corniche-rush.html'; dst=sys.argv[2] if len(sys.argv)>2 else 'test4.html'
s=open(src).read()
s='<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"></head><body>\n'+s
s=s.replace('https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js','dl/package/build/three.min.js').replace('https://cdn.jsdelivr.net/npm/three@0.128.0/','dl/package/')
a="  const input = { gas: false, brake: false, left: false, right: false, nitro: false, axis: 0, axisOn: false };"
assert a in s
s=s.replace(a, a+"\n  window.__S = S; Object.defineProperty(window, '__ck', { get: () => cockpit }); window.__cam = camera; window.__scene = scene; window.__input = input; window.__hero = hero; window.__update = update; window.__bodyStep = bodyStep; window.__renderer = renderer; Object.defineProperty(window, '__joyFull', { get: () => joyFull }); try { window.__ROUTE = ROUTE; window.__updateBend = updateBend; window.__bendForRender = bendForRender; } catch (e) {} try { window.__CARS = CARS; window.__useCar = useCar; window.__G = G; } catch (e) {} Object.defineProperty(window, '__RC', { get: () => RC }); Object.defineProperty(window, '__RACE', { get: () => RACE });")
s=s.replace('      menuT += dt;', '      menuT += dt; if (window.__menuT !== undefined) menuT = window.__menuT;')
s=s.replace('    palmLOD();\n', '    palmLOD(); if (window.__camOverride) window.__camOverride(camera);\n')
open(dst,'w').write(s)
