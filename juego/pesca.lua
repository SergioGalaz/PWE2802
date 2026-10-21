-- Minijuego de pesca: una marca va y viene por la barra y hay que tirar la red
-- cuando pasa por la zona buena. Tres intentos por salida.
local estado = require "juego.estado"
local util = require "juego.util"

local M = {}

M.INTENTOS = 3

function M.empezar()
	M.intentos = M.INTENTOS
	M.pescados = 0
	-- En bajamar la zona buena es más chica, pero salen mariscos además del pescado.
	M.ancho = estado.bajamar() and 0.15 or 0.22
	M.rapidez = util.azar(0.8, 1.1)
	M.nueva_zona()
	M.mensaje = "Tira la red cuando la marca pase por la zona verde."
end

function M.nueva_zona()
	M.centro = util.azar(0.2, 0.8)
	M.marca = 0
	M.sentido = 1
end

function M.tick(dt)
	if M.intentos == 0 then
		return
	end
	M.marca = M.marca + M.sentido * M.rapidez * dt
	if M.marca > 1 or M.marca < 0 then
		M.sentido = -M.sentido
		M.marca = util.clamp(M.marca, 0, 1)
	end
end

function M.tirar()
	if M.intentos == 0 then
		return
	end
	M.intentos = M.intentos - 1
	estado.sonar("chapuzon")
	local msg
	if math.abs(M.marca - M.centro) <= M.ancho / 2 then
		local n = math.random(1, 3) + (estado.bajamar() and 1 or 0)
		M.pescados = M.pescados + n
		estado.sumar("pescado", n)
		msg = string.format("¡Salieron %d!", n)
		estado.sonar("pesca", 0, 0)
		estado.historia("primera_pesca", {
			{"Don Fermín", "Buena. Ese pescado llévelo al ahumadero; fresco se pudre, ahumado se vende."},
		})
	else
		msg = "Nada. Solo algas y una bota."
	end
	if M.intentos == 0 then
		M.mensaje = string.format("%s Total de la salida: %d pescados.", msg, M.pescados)
	else
		M.nueva_zona()
		M.mensaje = msg
	end
end

function M.info()
	return string.format("%s  Intentos: %d. Marea: %s.", M.mensaje, M.intentos, estado.nombre_marea())
end

return M
