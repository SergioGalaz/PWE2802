-- Corre la prueba automática de la demo sin abrir el juego, con LuaJIT:
--   luajit tools/prueba.lua
-- Es la misma prueba que corre dentro de Defold (juego/prueba.lua).
local raiz = arg[0]:match("^(.*)/tools/[^/]*$") or "."
package.path = raiz .. "/?.lua;" .. package.path

local prueba = require "juego.prueba"
prueba.empezar()
while true do
	local listo, ok = prueba.paso(1 / 60)
	if listo then
		os.exit(ok and 0 or 1)
	end
end
