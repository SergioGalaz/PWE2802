-- Abdón Cárcamo: se mueve, pesca, pelea con el arpón y usa el Revisorio.
local estado = require "juego.estado"
local entrada = require "juego.entrada"
local unidad = require "juego.unidad"
local util = require "juego.util"

local M = {}

M.RAPIDEZ = 340
M.RAPIDEZ_ESQUIVE = 1050
M.ALCANCE = 105
M.DANO = 22
M.COSTO_HECHIZO = 15
M.RADIO_HECHIZO = 170
M.DANO_HECHIZO = 45

function M.nuevo(x, y)
	local p = unidad.nueva("jugador", x, y)
	p.nombre = "Abdón"
	p.sprite = "abdon"
	p.radio = 24
	p.energia = 100
	p.frente_x, p.frente_y = 0, 1
	p.cd_ataque = 0
	p.t_esquive = 0
	p.cd_esquive = 0
	p.golpe = 0
	p.cercano = nil
	p.al_morir = function(u, mundo)
		mundo.jugador_cae()
	end
	return p
end

function M.usar_energia(p, n)
	p.energia = math.max(0, p.energia - n)
	if p.energia <= 0 then
		estado.decir("Abdón está agotado. Duerme para recuperar energía.")
	end
end

function M.atacar(p, mundo)
	if p.cd_ataque > 0 then
		return
	end
	p.cd_ataque = 0.4
	p.golpe = 0.18
	unidad.mostrar_ataque(p)
	estado.sonar("arpon")
	M.usar_energia(p, 0.5)
	for _, e in ipairs(mundo.entes_vivos()) do
		local dx, dy = e.x - p.x, e.y - p.y
		local d = util.largo(dx, dy)
		local nx, ny = util.norm(dx, dy)
		if d < M.ALCANCE + e.radio and (d < 30 or nx * p.frente_x + ny * p.frente_y > 0.2) then
			mundo.danar(e, M.DANO, p)
		end
	end
end

function M.esquivar(p)
	if p.cd_esquive > 0 or p.energia < 2 then
		return
	end
	p.t_esquive = 0.16
	p.cd_esquive = 0.8
	M.usar_energia(p, 2)
end

function M.hechizo(p, mundo)
	if estado.juicio < M.COSTO_HECHIZO then
		estado.decir("No te queda Juicio para leer el Revisorio.")
		return
	end
	estado.medidor("juicio", -M.COSTO_HECHIZO)
	estado.medidor("marea", 3)
	estado.sonar("revisorio")
	local cx, cy = p.x + p.frente_x * 150, p.y + p.frente_y * 150
	mundo.estallido(cx, cy, M.RADIO_HECHIZO, {0.6, 0.3, 0.9, 0.5})
	for _, e in ipairs(mundo.entes_vivos()) do
		if util.dist(e.x, e.y, cx, cy) < M.RADIO_HECHIZO then
			mundo.danar(e, M.DANO_HECHIZO, p)
		end
	end
	estado.historia("primer_hechizo", {
		{"Don Fermín", "Ojo con ese libro, patrón. Cada hechizo es un favor que le debe al mar."},
		{"Don Fermín", "La Marea sube y el Juicio baja. Yo lo anoto todo, por si acaso."},
	})
end

function M.danar(p, mundo, n, fuente)
	if p.t_esquive > 0 then
		return
	end
	unidad.danar(p, mundo, n, fuente)
end

function M.revivir(p, x, y)
	p.muerto = false
	p.hp = p.max_hp * 0.5
	p.x, p.y = x, y
end

local function buscar_cercano(p, mundo)
	local mejor, mejor_d = nil, math.huge
	for _, it in ipairs(mundo.interactuables()) do
		if mundo.puede_interactuar(it) then
			local d = util.dist(p.x, p.y, it.x, it.y)
			if d < it.radio_accion and d < mejor_d then
				mejor, mejor_d = it, d
			end
		end
	end
	p.cercano = mejor
end

function M.tick(p, mundo, dt)
	unidad.tick_estado(p, dt)
	p.cd_ataque = math.max(0, p.cd_ataque - dt)
	p.cd_esquive = math.max(0, p.cd_esquive - dt)
	p.golpe = math.max(0, p.golpe - dt)
	if p.muerto then
		return
	end
	local acepta = not estado.bloqueo and estado.espera_ui <= 0
	local ix, iy = 0, 0
	if not estado.bloqueo then
		ix, iy = entrada.mover()
	end
	if p.t_esquive > 0 then
		p.t_esquive = p.t_esquive - dt
		p.vx, p.vy = p.frente_x * M.RAPIDEZ_ESQUIVE, p.frente_y * M.RAPIDEZ_ESQUIVE
	else
		local rapidez = M.RAPIDEZ * (p.energia <= 0 and 0.6 or 1)
		p.vx, p.vy = ix * rapidez, iy * rapidez
		if util.largo(ix, iy) > 0.15 then
			p.frente_x, p.frente_y = util.norm(ix, iy)
		end
	end
	local ax, ay = entrada.apuntar()
	if util.largo(ax, ay) > 0.35 and not estado.bloqueo then
		p.frente_x, p.frente_y = util.norm(ax, ay)
	end
	unidad.mover(p, mundo, dt, {terreno = true, barricadas = true})
	p.mira_x, p.mira_y = p.frente_x, p.frente_y
	buscar_cercano(p, mundo)
	if acepta then
		if entrada.recien_apretado("attack") then
			M.atacar(p, mundo)
		end
		if entrada.recien_apretado("dodge") then
			M.esquivar(p)
		end
		if entrada.recien_apretado("spell") then
			M.hechizo(p, mundo)
		end
		if entrada.recien_apretado("interact") and p.cercano then
			mundo.interactuar(p.cercano)
		end
	end
end

return M
