-- Lo que Abdón puede usar en el mundo: muelle, ahumadero, mesa de brujería, cama,
-- almacén, leña, barricadas y cuerpos en la playa. Cada uno sabe si se puede usar,
-- qué dice el aviso y qué hace.
local estado = require "juego.estado"
local jugador = require "juego.jugador"

local M = {}

local TIPOS = {}

-- El muelle: Abdón pesca con un minijuego y un Finao arponero puede pescar solo.
TIPOS.muelle = {
	titulo = "Muelle", w = 90, h = 200, radio = 120,
	puede = function()
		return not estado.es_noche()
	end,
	texto = function()
		return "Pescar"
	end,
	usar = function(s, mundo)
		local p = mundo.jugador
		if p.energia < 5 then
			estado.decir("Abdón está muy cansado para pescar.")
			return
		end
		jugador.usar_energia(p, 5)
		estado.pedir("pesca")
	end,
	tick = function(s, mundo, dt)
		if estado.es_noche() then
			return
		end
		local n = mundo.trabajando_en("muelle", true)
		if n == 0 then
			return
		end
		s.avance = s.avance + dt * estado.escala * n
		if s.avance >= 30 then
			s.avance = 0
			estado.sumar("pescado", 1)
		end
	end,
}

-- El ahumadero: convierte pescado fresco en ahumado, que se vende mejor.
-- Los Finaos asignados lo hacen funcionar más rápido.
M.T_AHUMADO = 15
TIPOS.ahumadero = {
	titulo = "Ahumadero", sprite = "ahumadero", w = 112, h = 112, radio = 120,
	texto = function(s)
		if estado.cantidad("pescado") > 0 then
			return string.format("Ahumar %d pescado", estado.cantidad("pescado"))
		end
		return string.format("Ahumadero: %d en el humo", s.cola)
	end,
	usar = function(s)
		local n = estado.cantidad("pescado")
		if n == 0 then
			estado.decir("No hay pescado fresco. Ve a pescar al muelle.")
			return
		end
		estado.gastar({pescado = n})
		s.cola = s.cola + n
		estado.decir(string.format("%d pescado al humo.", n))
	end,
	tick = function(s, mundo, dt)
		if s.cola == 0 then
			s.avance = 0
			return
		end
		local n = mundo.trabajando_en("ahumadero", true)
		s.avance = s.avance + dt * estado.escala * (1 + n)
		if s.avance >= M.T_AHUMADO then
			s.avance = 0
			s.cola = s.cola - 1
			estado.sumar("pescado_ahumado", 1)
			estado.historia("primer_ahumado", {
				{"Don Fermín", "Pescado ahumado: dura más y Lucio lo paga mejor. El humo es lo único en esta isla que no viene del mar."},
			})
		end
	end,
}

-- La mesa de brujería: con un cuerpo, sal, brea y el Revisorio se reanima un Finao.
M.COSTO_REANIMAR = {cuerpo = 1, sal = 1, brea = 1}
TIPOS.mesa = {
	titulo = "Mesa de brujería", sprite = "mesa_brujeria", w = 112, h = 80, radio = 120,
	texto = function()
		return "Reanimar un Finao (" .. estado.texto_costos(M.COSTO_REANIMAR) .. ")"
	end,
	usar = function(s, mundo)
		local p = mundo.jugador
		if not estado.alcanza(M.COSTO_REANIMAR) then
			estado.decir("Falta material: " .. estado.texto_costos(M.COSTO_REANIMAR) .. ".")
			return
		end
		if p.energia < 10 then
			estado.decir("Reanimar cansa. Abdón necesita dormir.")
			return
		end
		estado.gastar(M.COSTO_REANIMAR)
		jugador.usar_energia(p, 10)
		estado.medidor("juicio", -5)
		estado.medidor("marea", 1)
		estado.sonar("reanimar", 0, 0)
		mundo.reanimar()
	end,
}

-- La cama del palafito: recupera energía y salta la noche.
TIPOS.cama = {
	titulo = "Cama", sprite = "cama", w = 112, h = 72, radio = 120,
	texto = function()
		if estado.fase == estado.DIA then
			return "Dormir (solo al atardecer o de noche)"
		end
		return "Dormir hasta el amanecer"
	end,
	usar = function(s, mundo)
		if estado.fase == estado.DIA then
			estado.decir("Todavía es de día. Hay pega que hacer.")
			return
		end
		mundo.dormir()
	end,
}

-- El almacén de Lucio: se vende lo que se produce y se compra lo que falta.
TIPOS.almacen = {
	titulo = "Almacén de Lucio", sprite = "almacen", w = 160, h = 150, radio = 120,
	puede = function()
		return not estado.es_noche()
	end,
	texto = function()
		return "Comprar y vender"
	end,
	usar = function()
		estado.pedir("tienda")
	end,
}

-- Leña del monte: madera para barricadas, solo de día y unas pocas veces por día.
M.USOS_LENA = 4
TIPOS.lena = {
	titulo = "Leña del monte", sprite = "lena", w = 112, h = 56, radio = 120,
	puede = function(s)
		return not estado.es_noche() and s.usos > 0
	end,
	texto = function(s)
		return string.format("Cortar leña (+2 madera, quedan %d hoy)", s.usos)
	end,
	usar = function(s, mundo)
		local p = mundo.jugador
		if p.energia < 8 then
			estado.decir("Abdón no tiene fuerzas para el hacha.")
			return
		end
		jugador.usar_energia(p, 8)
		s.usos = s.usos - 1
		estado.sumar("madera", 2)
	end,
}

-- Barricada de la playa. Se construye con madera y frena a los ahogados de la horda.
M.COSTO_BARRICADA = {madera = 3}
M.COSTO_REPARAR = {madera = 1}
M.HP_BARRICADA = 150
TIPOS.barricada = {
	titulo = "Barricada", sprite = "barricada", w = 184, h = 48, radio = 130,
	puede = function(s)
		return s.hp < M.HP_BARRICADA
	end,
	texto = function(s)
		if s.hp <= 0 then
			return "Construir barricada (" .. estado.texto_costos(M.COSTO_BARRICADA) .. ")"
		end
		return "Reparar barricada (" .. estado.texto_costos(M.COSTO_REPARAR) .. ")"
	end,
	usar = function(s)
		local nueva = s.hp <= 0
		if not estado.gastar(nueva and M.COSTO_BARRICADA or M.COSTO_REPARAR) then
			estado.decir("Falta madera. Hay leña en el monte.")
			return
		end
		s.hp = nueva and M.HP_BARRICADA or math.min(M.HP_BARRICADA, s.hp + 60)
	end,
}

-- Un ahogado en la playa. Se recoge para reanimarlo en la mesa de brujería.
TIPOS.cuerpo = {
	titulo = "Ahogado", sprite = "cuerpo", w = 64, h = 20, radio = 90,
	texto = function()
		return "Recoger el cuerpo"
	end,
	usar = function(s)
		estado.sumar("cuerpo", 1)
		estado.decir("Recogiste un cuerpo. Huele a mar y a mala suerte.")
		s.borrar = true
	end,
}

function M.nueva(tipo, x, y)
	local t = TIPOS[tipo]
	return {
		clase = "estacion", tipo = tipo, x = x, y = y, titulo = t.titulo, sprite = t.sprite,
		w = t.w, h = t.h, radio_accion = t.radio, def = t,
		avance = 0, cola = 0, usos = M.USOS_LENA, hp = 0,
	}
end

function M.puede(s, mundo)
	return s.def.puede == nil or s.def.puede(s, mundo)
end

function M.texto(s, mundo)
	return s.def.texto(s, mundo)
end

function M.usar(s, mundo)
	s.def.usar(s, mundo)
end

function M.tick(s, mundo, dt)
	if s.def.tick then
		s.def.tick(s, mundo, dt)
	end
end

return M
