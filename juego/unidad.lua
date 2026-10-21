-- Base común de Abdón, los Finaos y los entes: vida, aturdimiento, movimiento,
-- choques y qué vista del sprite mostrar.
local estado = require "juego.estado"
local util = require "juego.util"

local M = {}

-- Crea una unidad con los campos comunes. `clase` es "jugador", "finao" o "ente".
function M.nueva(clase, x, y)
	return {
		clase = clase, x = x, y = y, vx = 0, vy = 0,
		max_hp = 100, hp = 100, radio = 22, nombre = "",
		aturdido = 0, destello = 0, muerto = false,
		-- Sprite en tres vistas (frente, espalda y lado), con cuadros de paso y de ataque.
		-- El lado mira a la derecha y se voltea.
		sprite = "", vista = "frente", izquierda = false,
		pose_ataque = 0, ataque_x = 0, ataque_y = 0,
		paso = 0, mira_x = 0, mira_y = 0,
		escala = 1.5, altura = 0, t_vuelo = 0,
		-- Al morir se ladea y se apaga; mientras, ya no cuenta para nada.
		caida = nil,
	}
end

function M.danar(u, mundo, cantidad, fuente)
	if u.muerto then
		return
	end
	u.hp = u.hp - cantidad
	u.destello = 0.12
	estado.sonar("golpe", -8)
	if u.hp <= 0 then
		u.hp = 0
		u.muerto = true
		if u.al_morir then
			u.al_morir(u, mundo, fuente)
		else
			M.caer(u)
		end
	end
end

-- Muestra el cuadro de ataque un momento, mirando hacia (dx, dy) si se da.
function M.mostrar_ataque(u, dx, dy)
	u.pose_ataque = 0.22
	u.ataque_x, u.ataque_y = dx or 0, dy or 0
end

function M.caer(u)
	u.muerto = true
	u.caida = u.caida or 0
end

function M.aturdir(u, s)
	u.aturdido = math.max(u.aturdido, s)
end

function M.curar(u, n)
	u.hp = math.min(u.max_hp, u.hp + n)
end

function M.tick_estado(u, dt)
	u.destello = math.max(0, u.destello - dt)
	u.aturdido = math.max(0, u.aturdido - dt)
	u.pose_ataque = math.max(0, u.pose_ataque - dt)
	u.t_vuelo = u.t_vuelo + dt
	if u.caida then
		u.caida = u.caida + dt
	end
	local dx, dy = u.vx, u.vy
	local mira = util.largo(u.mira_x, u.mira_y) > 0.1
	if mira then
		dx, dy = u.mira_x, u.mira_y
	end
	if u.pose_ataque > 0 and util.largo(u.ataque_x, u.ataque_y) > 0.1 then
		dx, dy = u.ataque_x, u.ataque_y
	end
	if util.largo(dx, dy) > 5 or mira then
		if math.abs(dy) > math.abs(dx) * 1.15 then
			u.vista = dy < 0 and "espalda" or "frente"
		else
			u.vista = "lado"
			u.izquierda = dx < 0
		end
	end
	if util.largo(u.vx, u.vy) > 10 then
		u.paso = u.paso + dt
	else
		u.paso = 0
	end
end

-- Mueve la unidad con su velocidad y la saca de lo que no puede atravesar.
-- `choca` puede tener `terreno` (el mar y los bordes) y `barricadas`.
function M.mover(u, mundo, dt, choca)
	u.x = u.x + u.vx * dt
	u.y = u.y + u.vy * dt
	local r = u.radio * 0.8
	if choca.terreno then
		u.x = util.clamp(u.x, r, mundo.ANCHO - r)
		u.y = util.clamp(u.y, r, mundo.MAR - r)
	end
	if choca.barricadas then
		for _, b in ipairs(mundo.barricadas) do
			if b.hp > 0 then
				M.empujar_fuera(u, b.x - 92, b.y - 24, b.x + 92, b.y + 24, r)
			end
		end
	end
end

-- Saca un círculo de un rectángulo, por el lado más corto.
function M.empujar_fuera(u, x0, y0, x1, y1, r)
	local cx, cy = util.clamp(u.x, x0, x1), util.clamp(u.y, y0, y1)
	local dx, dy = u.x - cx, u.y - cy
	local d = util.largo(dx, dy)
	if d >= r then
		return
	end
	if d > 1e-6 then
		u.x = cx + dx / d * r
		u.y = cy + dy / d * r
		return
	end
	-- El centro quedó adentro: sale por el borde más cercano.
	local izq, der, arr, aba = u.x - x0, x1 - u.x, u.y - y0, y1 - u.y
	local m = math.min(izq, der, arr, aba)
	if m == izq then
		u.x = x0 - r
	elseif m == der then
		u.x = x1 + r
	elseif m == arr then
		u.y = y0 - r
	else
		u.y = y1 + r
	end
end

-- Velocidad hacia un punto, o quieto si ya llegó.
function M.ir_hacia(u, x, y, rapidez, margen)
	local dx, dy = x - u.x, y - u.y
	if util.largo(dx, dy) > margen then
		local nx, ny = util.norm(dx, dy)
		u.vx, u.vy = nx * rapidez, ny * rapidez
	else
		u.vx, u.vy = 0, 0
	end
end

return M
