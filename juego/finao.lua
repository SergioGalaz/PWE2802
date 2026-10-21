-- Un Finao: ahogado reanimado que trabaja de día y pelea de noche.
-- Su oficio en vida define su rol.
local estado = require "juego.estado"
local unidad = require "juego.unidad"
local util = require "juego.util"

local M = {}

M.SEGUIR, M.ATACAR, M.DEFENDER, M.RETIRARSE = 1, 2, 3, 4
M.NOMBRE_ORDEN = {"Seguir", "Atacar", "Defender", "Retirarse"}

M.ROLES = {
	muralla = {nombre = "Muralla", hp = 130, dano = 8, alcance = 50, rapidez = 150, cd = 0.9, color = {0.45, 0.6, 0.4}},
	arponero = {nombre = "Arponero", hp = 70, dano = 11, alcance = 230, rapidez = 170, cd = 1.1, color = {0.35, 0.65, 0.6}},
	rezador = {nombre = "Rezador", hp = 70, dano = 4, alcance = 50, rapidez = 160, cd = 1.0, color = {0.7, 0.7, 0.5}},
	saqueador = {nombre = "Saqueador", hp = 80, dano = 9, alcance = 50, rapidez = 220, cd = 0.7, color = {0.6, 0.5, 0.35}},
	contador = {nombre = "Contador", hp = 55, dano = 3, alcance = 50, rapidez = 150, cd = 1.2, color = {0.55, 0.55, 0.65}},
}
M.LISTA_ROLES = {"muralla", "arponero", "rezador", "saqueador", "contador"}
M.OFICIOS = {
	muralla = {"carpintero", "leñador", "herrero"},
	arponero = {"pescador", "lobero"},
	rezador = {"sacristán", "beata", "profesora"},
	saqueador = {"contrabandista", "comerciante"},
	contador = {"contador"},
}
M.NOMBRES = {
	"Don Lautaro", "Doña Elcira", "El Chumbeque", "Doña Rosalba", "Don Eleuterio", "La Meche",
	"Don Abelino", "Doña Filomena", "El Guatón Ruiz", "Don Belarmino", "Doña Ercilia", "El Tito",
}
M.TRABAJOS = {"ahumadero", "muelle", "descanso"}
M.NOMBRE_TRABAJO = {ahumadero = "Ahumadero", muelle = "Muelle", descanso = "Descanso"}

-- Crea un Finao nuevo con oficio al azar, o con los datos dados.
function M.nuevo(datos, x, y)
	local f = unidad.nueva("finao", x, y)
	f.nombre = datos.nombre or util.elegir(M.NOMBRES)
	f.rol = datos.rol or util.elegir(M.LISTA_ROLES)
	f.oficio = datos.oficio or util.elegir(M.OFICIOS[f.rol])
	f.frescura = datos.frescura or 100
	f.moral = datos.moral or 80
	f.trabajo = datos.trabajo or "descanso"
	if datos.en_cuadrilla == nil then
		f.en_cuadrilla = true
	else
		f.en_cuadrilla = datos.en_cuadrilla
	end
	local rol = M.ROLES[f.rol]
	f.max_hp = rol.hp
	f.hp = (datos.hp and datos.hp > 0) and math.min(datos.hp, f.max_hp) or f.max_hp
	f.color = rol.color
	f.radio = 20
	f.sprite = "finao_" .. f.rol
	f.orden = M.SEGUIR
	f.defender_x, f.defender_y = 0, 0
	f.cd_ataque = 0
	f.radio_accion = 80
	f.desvio_x, f.desvio_y = util.azar(-70, 70), util.azar(-70, 70)
	f.peleo = false
	f.al_morir = function(u, mundo)
		mundo.finao_cae(u)
	end
	return f
end

function M.a_tabla(f)
	return {
		nombre = f.nombre, rol = f.rol, oficio = f.oficio, frescura = f.frescura,
		moral = f.moral, trabajo = f.trabajo, en_cuadrilla = f.en_cuadrilla, hp = f.hp,
	}
end

function M.nombre_rol(f)
	return M.ROLES[f.rol].nombre
end

function M.resumen(f)
	return string.format("%s. En vida fue %s; en la cuadrilla es %s. Frescura %d, moral %d.",
		f.nombre, f.oficio, M.nombre_rol(f):lower(), math.floor(f.frescura), math.floor(f.moral))
end

-- Devuelve falso si el Finao se niega por tener la moral baja.
function M.dar_orden(f, orden, x, y)
	if f.moral < 30 and math.random() < 0.4 then
		return false
	end
	f.orden = orden
	f.defender_x, f.defender_y = x, y
	return true
end

local function atacar(f, mundo, rol)
	local t = f.objetivo
	f.cd_ataque = rol.cd
	unidad.mostrar_ataque(f, t.x - f.x, t.y - f.y)
	local dano = rol.dano
	if f.rol == "arponero" then
		mundo.disparo(f.x, f.y, t.x, t.y)
		if t.tipo_ente == "mar" then
			dano = dano * 1.5
		end
	end
	mundo.danar(t, dano, f)
end

function M.tick(f, mundo, dt)
	unidad.tick_estado(f, dt)
	f.cd_ataque = math.max(0, f.cd_ataque - dt)
	if f.muerto then
		return
	end
	if f.aturdido > 0 then
		f.vx, f.vy = 0, 0
		return
	end
	local rol = M.ROLES[f.rol]
	if f.rol == "rezador" then
		for _, o in ipairs(mundo.finaos()) do
			if o ~= f and util.dist(o.x, o.y, f.x, f.y) < 200 then
				unidad.curar(o, 4 * dt)
			end
		end
	end
	local p = mundo.jugador
	local dx, dy = f.x, f.y
	f.objetivo = nil
	if estado.es_noche() and f.en_cuadrilla then
		f.peleo = true
		if f.orden == M.SEGUIR then
			f.objetivo = mundo.ente_cercano(p.x, p.y, 340)
			dx, dy = p.x + f.desvio_x, p.y + f.desvio_y
		elseif f.orden == M.ATACAR then
			f.objetivo = mundo.ente_cercano(f.x, f.y, 1400)
			dx, dy = p.x + f.desvio_x, p.y + f.desvio_y
		elseif f.orden == M.DEFENDER then
			f.objetivo = mundo.ente_cercano(f.defender_x, f.defender_y, 300)
			dx, dy = f.defender_x + f.desvio_x, f.defender_y + f.desvio_y
		else
			local lx, ly = mundo.lugar_trabajo("descanso")
			dx, dy = lx + f.desvio_x, ly + f.desvio_y
		end
	else
		local lx, ly = mundo.lugar_trabajo(estado.es_noche() and "descanso" or f.trabajo)
		dx, dy = lx + f.desvio_x * 0.6, ly + f.desvio_y * 0.6
		-- Si un ente se acerca demasiado, se defiende igual.
		f.objetivo = mundo.ente_cercano(f.x, f.y, 140)
	end
	local t = f.objetivo
	if t then
		if util.dist(f.x, f.y, t.x, t.y) > rol.alcance + t.radio then
			dx, dy = t.x, t.y
		else
			dx, dy = f.x, f.y
			if f.cd_ataque <= 0 then
				atacar(f, mundo, rol)
			end
		end
	end
	unidad.ir_hacia(f, dx, dy, rol.rapidez * (f.moral < 30 and 0.7 or 1), 14)
	unidad.mover(f, mundo, dt, {terreno = true})
end

-- Paso del tiempo al amanecer. Devuelve falso si el Finao se desarmó.
function M.nuevo_dia(f)
	if estado.gastar({sal = 1}) then
		f.frescura = f.frescura - 4
	else
		f.frescura = f.frescura - 15
	end
	if f.peleo then
		f.moral = math.max(0, f.moral - 10)
	end
	f.peleo = false
	f.hp = f.max_hp
	return f.frescura > 0
end

return M
