-- Un ente de la noche. Los del monte rondan el bosque; los ahogados de Cai Cai
-- suben del mar en noches de Marea Bruja y van hacia la iglesia.
local estado = require "juego.estado"
local unidad = require "juego.unidad"
local util = require "juego.util"

local M = {}

M.TIPOS = {
	trauco = {nombre = "Trauco", hp = 60, dano = 9, rapidez = 130, radio = 20, tipo = "monte"},
	fiura = {nombre = "Fiura", hp = 45, dano = 6, rapidez = 115, radio = 18, tipo = "monte"},
	ahogado = {nombre = "Ahogado", hp = 40, dano = 8, rapidez = 95, radio = 21, tipo = "mar"},
	-- Subjefes: más vida, una habilidad propia y una barra en la pantalla.
	chonchon = {nombre = "Chonchón", hp = 140, dano = 10, rapidez = 165, radio = 18, tipo = "monte", jefe = true, vuela = true},
	invunche = {nombre = "Invunche", hp = 260, dano = 16, rapidez = 85, radio = 26, tipo = "monte", jefe = true},
}
M.T_EMBESTIDA = 0.6
M.RAPIDEZ_EMBESTIDA = 3.6
M.AGRO = 380
M.AGRO_HORDA = 170

function M.nuevo(tipo, x, y, horda)
	local t = M.TIPOS[tipo]
	local e = unidad.nueva("ente", x, y)
	e.tipo = tipo
	e.horda = horda
	e.nombre = t.nombre
	e.max_hp = t.hp
	e.hp = t.hp
	e.radio = t.radio
	e.tipo_ente = t.tipo
	e.sprite = tipo
	e.jefe = t.jefe or false
	if e.jefe then
		e.escala = 2
	end
	-- El Chonchón vuela: pasa sobre las barricadas.
	if t.vuela then
		e.altura = 30
	end
	-- Las hordas son muchas: sin nombre encima, para no tapar la pelea.
	e.con_nombre = not horda or e.jefe
	e.casa_x, e.casa_y = x, y
	e.rumbo_x, e.rumbo_y = x, y
	e.cd_habilidad = 4
	e.cd_ataque = 0
	e.pulso = 0
	e.pulso_radio = 0
	e.pulso_color = {1, 1, 1, 0.3}
	e.embestida = 0
	e.embestida_x, e.embestida_y = 0, 0
	e.embestida_golpe = false
	e.al_morir = function(u, mundo, fuente)
		mundo.ente_muerto(u, fuente)
		unidad.caer(u)
	end
	return e
end

local function pulso(e, r, color)
	e.pulso = 0.4
	e.pulso_radio = r
	e.pulso_color = color
end

local function habilidad(e, mundo)
	if e.tipo == "trauco" then
		-- Su mirada paraliza a los Finaos cercanos. A los vivos no les hace nada.
		e.cd_habilidad = 6
		local golpe = false
		for _, f in ipairs(mundo.finaos()) do
			if util.dist(f.x, f.y, e.x, e.y) < 210 then
				unidad.aturdir(f, 2)
				golpe = true
			end
		end
		if golpe then
			pulso(e, 210, {1, 0.85, 0.2, 0.35})
		end
	elseif e.tipo == "fiura" then
		-- Su aliento pudre a los Finaos y enferma a Abdón.
		e.cd_habilidad = 5
		local golpe = false
		for _, a in ipairs(mundo.aliados()) do
			if util.dist(a.x, a.y, e.x, e.y) < 150 then
				mundo.danar(a, 6, e)
				if a.frescura then
					a.frescura = math.max(0, a.frescura - 4)
				end
				golpe = true
			end
		end
		if golpe then
			pulso(e, 150, {0.5, 0.9, 0.2, 0.35})
		end
	elseif e.tipo == "chonchon" then
		-- El grito "¡tue, tue!": paraliza a los Finaos y le quita Juicio a Abdón.
		e.cd_habilidad = 5
		local golpe = false
		for _, f in ipairs(mundo.finaos()) do
			if util.dist(f.x, f.y, e.x, e.y) < 260 then
				unidad.aturdir(f, 1.5)
				golpe = true
			end
		end
		local p = mundo.jugador
		if util.dist(p.x, p.y, e.x, e.y) < 260 then
			estado.medidor("juicio", -3)
			golpe = true
		end
		if golpe then
			estado.sonar("revisorio", -4, 0)
			estado.decir("¡Tue, tue! El grito del Chonchón te hiela la sangre.")
			pulso(e, 260, {0.85, 0.5, 0.2, 0.35})
		end
	elseif e.tipo == "invunche" then
		-- Embiste en línea recta contra el que tenga más cerca.
		e.cd_habilidad = 7
		local t = mundo.aliado_cercano(e.x, e.y, 420)
		if t then
			e.embestida_x, e.embestida_y = util.norm(t.x - e.x, t.y - e.y)
			e.embestida = M.T_EMBESTIDA
			e.embestida_golpe = false
			unidad.mostrar_ataque(e, e.embestida_x, e.embestida_y)
			pulso(e, 90, {0.8, 0.3, 0.25, 0.35})
		end
	else
		e.cd_habilidad = 99
	end
end

local function embestir(e, mundo, dt, t)
	e.embestida = e.embestida - dt
	e.pose_ataque = 0.1
	local v = t.rapidez * M.RAPIDEZ_EMBESTIDA
	e.vx, e.vy = e.embestida_x * v, e.embestida_y * v
	unidad.mover(e, mundo, dt, {barricadas = true})
	if e.embestida_golpe then
		return
	end
	for _, a in ipairs(mundo.aliados()) do
		if util.dist(a.x, a.y, e.x, e.y) < e.radio + a.radio + 10 then
			mundo.danar(a, 14, e)
			unidad.aturdir(a, 1)
			e.embestida_golpe = true
			estado.sonar("golpe", 0, 0)
		end
	end
end

function M.tick(e, mundo, dt)
	unidad.tick_estado(e, dt)
	e.cd_ataque = math.max(0, e.cd_ataque - dt)
	e.cd_habilidad = e.cd_habilidad - dt
	e.pulso = math.max(0, e.pulso - dt)
	if e.muerto then
		return
	end
	if e.aturdido > 0 then
		e.vx, e.vy = 0, 0
		return
	end
	local t = M.TIPOS[e.tipo]
	if e.embestida > 0 then
		embestir(e, mundo, dt, t)
		return
	end
	if e.cd_habilidad <= 0 then
		habilidad(e, mundo)
	end
	local obj = mundo.aliado_cercano(e.x, e.y, e.horda and M.AGRO_HORDA or M.AGRO)
	local dx, dy = e.x, e.y
	if obj then
		dx, dy = obj.x, obj.y
		if util.dist(e.x, e.y, obj.x, obj.y) < e.radio + obj.radio + 22 then
			dx, dy = e.x, e.y
			if e.cd_ataque <= 0 then
				e.cd_ataque = 1
				unidad.mostrar_ataque(e, obj.x - e.x, obj.y - e.y)
				mundo.danar(obj, t.dano, e)
			end
		end
	elseif e.horda then
		local b = mundo.barricada_delante(e.x, e.y)
		if b then
			dx, dy = e.x, e.y
			if e.cd_ataque <= 0 then
				e.cd_ataque = 1
				unidad.mostrar_ataque(e, b.x - e.x, b.y - e.y)
				mundo.danar_barricada(b, t.dano)
			end
		elseif util.dist(e.x, e.y, mundo.IGLESIA_X, mundo.IGLESIA_Y) < 70 then
			mundo.ente_en_iglesia(e)
			return
		else
			dx, dy = mundo.IGLESIA_X, mundo.IGLESIA_Y
		end
	else
		if util.dist(e.x, e.y, e.rumbo_x, e.rumbo_y) < 20 then
			e.rumbo_x = e.casa_x + util.azar(-260, 260)
			e.rumbo_y = e.casa_y + util.azar(-160, 160)
		end
		dx, dy = e.rumbo_x, e.rumbo_y
	end
	local rapidez = t.rapidez * ((obj == nil and not e.horda) and 0.55 or 1)
	unidad.ir_hacia(e, dx, dy, rapidez, 6)
	unidad.mover(e, mundo, dt, {barricadas = e.altura == 0})
end

return M
