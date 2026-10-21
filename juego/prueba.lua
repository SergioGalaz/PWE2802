-- Prueba automática: juega los tres días de la demo a velocidad alta y revisa
-- que los sistemas principales funcionen. Corre dentro del juego (main.script,
-- con prueba.automatica = 1 en game.project) o con LuaJIT a secas:
--   luajit tools/prueba.lua
local estado = require "juego.estado"
local mundo = require "juego.mundo"
local finao = require "juego.finao"
local pesca = require "juego.pesca"
local tienda = require "juego.tienda"
local util = require "juego.util"

local M = {}

M.ESCALA = 40
M.MAX_CUADROS = 60000

local function buscar(titulo)
	for _, s in ipairs(mundo.estaciones) do
		if s.titulo == titulo then
			return s
		end
	end
end

function M.revisar(nombre, ok)
	M.resultados[#M.resultados + 1] = {nombre, ok}
	print(string.format("SMOKE %s: %s", ok and "OK  " or "FALLA", nombre))
end

function M.empezar()
	math.randomseed(7)
	M.resultados = {}
	M.cuadros = 0
	M.hecho = {}
	M.noche_lista = -1
	M.vio_ente, M.vio_horda = false, false
	M.jefes = {}
	estado.borrar_guardado()
	estado.reiniciar()
	mundo.nuevo()
	estado.corriendo = true
	estado.escala = M.ESCALA
	print("SMOKE: partida iniciada")
end

local function ida_y_vuelta()
	estado.guardar(mundo.a_tablas())
	local dia = estado.dia
	local ok = estado.hay_guardado()
	local copia = util.copiar(estado.recursos)
	local banderas = util.copiar(estado.banderas)
	ok = ok and estado.cargar()
	ok = ok and estado.dia == dia and #estado.finaos_guardados == #mundo.finaos()
	estado.recursos = copia
	estado.banderas = banderas
	return ok
end

local function jugar(n)
	local w = mundo
	local p = w.jugador
	if not M.hecho.reanimar and n > 5 then
		M.hecho.reanimar = true
		estado.sumar("cuerpo", 3)
		estado.sumar("sal", 3)
		estado.sumar("brea", 3)
		local mesa = buscar("Mesa de brujería")
		for _ = 1, 4 do
			p.energia = 100
			w.interactuar(mesa)
		end
		local fs = w.finaos()
		M.revisar("cuatro Finaos reanimados", #fs == 4)
		M.revisar("el primero es Don Fermín", util.alguno(fs, function(f) return f.nombre == "Don Fermín" end))
		for _, f in ipairs(fs) do
			f.en_cuadrilla = true
		end
		fs[2].trabajo = "muelle"
	end
	if not M.hecho.pesca and n > 20 then
		M.hecho.pesca = true
		w.interactuar(buscar("Muelle"))
		M.revisar("el muelle abre la pesca", estado.peticiones[1] ~= nil and estado.peticiones[1][1] == "pesca")
		pesca.empezar()
		pesca.marca = pesca.centro
		pesca.tirar()
		M.revisar("la pesca da pescado", estado.cantidad("pescado") > 0)
		local ahumadero = buscar("Ahumadero")
		w.interactuar(ahumadero)
		M.revisar("el pescado entra al ahumadero", ahumadero.cola > 0)
	end
	if not M.hecho.tienda and n > 40 and estado.cantidad("pescado_ahumado") > 0 then
		M.hecho.tienda = true
		local antes = estado.cantidad("pesos")
		tienda.vender("pescado_ahumado", tienda.precio_venta(5))
		M.revisar("vender ahumado da pesos", estado.cantidad("pesos") > antes)
		M.revisar("Don Fermín regatea mejor", tienda.precio_venta(5) == 6)
	end
	if not M.hecho.barricadas and estado.dia == 3 then
		M.hecho.barricadas = true
		estado.sumar("madera", 9)
		for _, b in ipairs(w.barricadas) do
			w.interactuar(b)
		end
		M.revisar("tres barricadas construidas", not util.alguno(w.barricadas, function(b) return b.hp <= 0 end))
	end
	if estado.es_noche() and M.noche_lista ~= estado.dia then
		M.noche_lista = estado.dia
		-- Abdón espera a los entes con la cuadrilla, en el monte o en la playa según la noche.
		p.hp = p.max_hp
		if estado.es_horda() then
			p.x, p.y = 2250, 1300
		else
			p.x, p.y = 1500, 650
		end
		w.dar_orden(finao.ATACAR)
	end
	if estado.es_noche() then
		local entes = w.entes_vivos()
		if #entes > 0 then
			M.vio_ente = true
			for _, e in ipairs(entes) do
				if e.jefe then
					M.jefes[e.tipo] = true
				end
			end
			if estado.es_horda() then
				M.vio_horda = true
			end
			-- El jugador ataca solo al ente más cercano, para probar el combate.
			local e = w.ente_cercano(p.x, p.y, 2000)
			if e and n % 6 == 0 then
				local dx, dy = e.x - p.x, e.y - p.y
				if util.largo(dx, dy) > 90 then
					local nx, ny = util.norm(dx, dy)
					p.x, p.y = p.x + nx * 12, p.y + ny * 12
				else
					p.frente_x, p.frente_y = util.norm(dx, dy)
					require("juego.jugador").atacar(p, w)
				end
			end
		end
	end
	if n == 3000 then
		M.revisar("guardar y cargar", ida_y_vuelta())
	end
end

local function terminar()
	M.revisar("la demo llega al final del día 3", estado.demo_terminada)
	M.revisar("aparecieron entes de noche", M.vio_ente)
	M.revisar("hubo horda en la tercera noche", M.vio_horda)
	M.revisar("apareció el Chonchón", M.jefes.chonchon == true)
	M.revisar("apareció el Invunche", M.jefes.invunche == true)
	local r = {}
	for _, k in ipairs(estado.RECURSOS) do
		r[#r + 1] = k .. "=" .. estado.cantidad(k)
	end
	print(string.format("SMOKE resumen: día %d, finaos %d, recursos %s, marea %d, cerro %d, juicio %d, quicaví %d, cuadros %d",
		estado.dia, #mundo.finaos(), table.concat(r, " "), estado.marea, estado.cerro, estado.juicio, estado.aldea, M.cuadros))
	local fallas = 0
	for _, res in ipairs(M.resultados) do
		if not res[2] then
			fallas = fallas + 1
		end
	end
	print(fallas == 0 and "SMOKE TODO OK" or string.format("SMOKE %d FALLAS", fallas))
	return fallas == 0
end

-- Un cuadro de la prueba. Devuelve true (y si salió bien) cuando terminó.
function M.paso(dt)
	M.cuadros = M.cuadros + 1
	-- Los diálogos y ventanas se saltan solos.
	estado.dialogos = {}
	estado.sonidos = {}
	estado.avisos = {}
	jugar(M.cuadros)
	estado.peticiones = {}
	estado.tick(dt)
	mundo.tick(dt)
	if estado.demo_terminada or M.cuadros > M.MAX_CUADROS then
		return true, terminar()
	end
	return false
end

return M
