-- Estado de la entrada: teclado, mando y pantalla táctil escriben aquí y el juego
-- solo lee de aquí, así no distingue con qué se está jugando.
-- La interfaz detecta el modo según lo último que se usó.
local M = {}

M.TACTIL, M.MANDO, M.TECLADO = "tactil", "mando", "teclado"
M.ZONA_MUERTA = 0.25

M.modo = M.TECLADO
-- Verdadero si el mando es de PlayStation (cambia los nombres de los botones).
M.playstation = false

-- Valor de 0 a 1 de cada acción (los sticks dan valores intermedios).
M.valor = {}
-- Acciones apretadas en este cuadro. Se limpian al final de cada cuadro.
M.recien = {}
-- Joystick táctil, ya normalizado.
M.joy_x, M.joy_y = 0, 0

function M.apretar(accion, valor)
	valor = valor or 1
	if valor > M.ZONA_MUERTA and (M.valor[accion] or 0) <= M.ZONA_MUERTA then
		M.recien[accion] = true
	end
	M.valor[accion] = valor
end

function M.soltar(accion)
	M.valor[accion] = 0
end

function M.apretado(accion)
	return (M.valor[accion] or 0) > M.ZONA_MUERTA
end

function M.recien_apretado(accion)
	return M.recien[accion] == true
end

function M.fin_cuadro()
	M.recien = {}
end

function M.limpiar()
	M.valor = {}
	M.recien = {}
	M.joy_x, M.joy_y = 0, 0
end

local function eje(neg, pos)
	local function v(a)
		local x = M.valor[a] or 0
		return x > M.ZONA_MUERTA and x or 0
	end
	return v(pos) - v(neg)
end

local function limitar(x, y)
	local l = math.sqrt(x * x + y * y)
	if l > 1 then
		return x / l, y / l
	end
	return x, y
end

-- Vector de movimiento combinado (stick, teclado o joystick táctil), con y hacia abajo.
function M.mover()
	local x = eje("move_left", "move_right") + M.joy_x
	local y = eje("move_up", "move_down") + M.joy_y
	return limitar(x, y)
end

-- Vector de apuntado del stick derecho. Vacío si no se usa.
function M.apuntar()
	return limitar(eje("aim_left", "aim_right"), eje("aim_up", "aim_down"))
end

-- Texto corto del botón asociado a una acción, según el esquema activo.
function M.boton(accion)
	if M.modo == M.TACTIL then
		return "Toca"
	end
	if M.modo == M.TECLADO then
		local t = {interact = "E", attack = "J", dodge = "K", spell = "L", squad_wheel = "Q", menu = "Esc"}
		return t[accion] or "?"
	end
	local xbox = {interact = "A", attack = "X", dodge = "B", spell = "Y", squad_wheel = "LT", menu = "Menú"}
	local ps = {interact = "✕", attack = "□", dodge = "○", spell = "△", squad_wheel = "L2", menu = "Options"}
	return (M.playstation and ps or xbox)[accion] or "?"
end

return M
