-- El mundo de la demo: el palafito de Abdón, Quicaví, el monte y la playa.
-- También dirige la noche: la caza en el monte y las hordas de Cai Cai.
-- Las coordenadas son las del mapa, con y hacia abajo.
local estado = require "juego.estado"
local util = require "juego.util"
local unidad = require "juego.unidad"
local jugador = require "juego.jugador"
local finao = require "juego.finao"
local ente = require "juego.ente"
local estaciones = require "juego.estaciones"

local M = {}

M.ANCHO, M.ALTO = 3200, 2000
M.MONTE = 700
M.PLAYA = 1360
M.MAR = 1520
M.T_OLA = 60
M.T_CAZA = 45
M.MAX_CAZA = 6
M.IGLESIA_X, M.IGLESIA_Y = 2250, 980
M.CAMA_X, M.CAMA_Y = 1170, 1090
M.TRABAJO = {
	ahumadero = {760, 1160},
	muelle = {1000, 1420},
	descanso = {870, 1250},
}
M.CASAS = {
	{"casa_0", 1825, 975}, {"casa_1", 2675, 985}, {"casa_2", 2875, 1115},
	{"casa_1", 1775, 1315}, {"casa_0", 2625, 1315},
}
M.ZONAS = {
	{"Monte de Tepual", 1500, 80}, {"Quicaví", 2250, 740},
	{"Palafito de Abdón", 950, 930}, {"Golfo de Ancud", 1500, 1880},
}

-- Un generador propio para que el monte salga igual en cada partida.
local function plantar_arboles()
	local s = 1960
	local function azar(a, b)
		s = (s * 1103515245 + 12345) % 2147483648
		return a + (s / 2147483648) * (b - a)
	end
	local arboles = {}
	for i = 1, 140 do
		arboles[i] = {azar(40, M.ANCHO - 40), azar(20, M.MONTE - 30)}
	end
	return arboles
end
M.ARBOLES = plantar_arboles()

local siguiente_id = 0

local function con_id(t)
	siguiente_id = siguiente_id + 1
	t.id = siguiente_id
	return t
end

-- --- Armar la partida ---

function M.nuevo()
	estado.olvidar_oyentes()
	M.unidades = {}
	M.estaciones = {}
	M.efectos = {}
	M.barricadas = {}
	M.t_noche = 0
	M.olas = 0
	M.cazados = 0
	M.jefe_salio = false
	local function poner(tipo, x, y)
		local s = con_id(estaciones.nueva(tipo, x, y))
		table.insert(M.estaciones, s)
		return s
	end
	poner("muelle", 1000, 1500)
	poner("ahumadero", 760, 1060)
	poner("mesa", 980, 1050)
	poner("cama", M.CAMA_X, M.CAMA_Y)
	poner("almacen", 1950, 1160)
	M.lena = poner("lena", 520, 760)
	for _, x in ipairs({1900, 2250, 2600}) do
		table.insert(M.barricadas, poner("barricada", x, 1410))
	end
	M.jugador = con_id(jugador.nuevo(1050, 1200))
	table.insert(M.unidades, M.jugador)
	for _, datos in ipairs(estado.finaos_guardados) do
		M.nuevo_finao(datos)
	end
	estado.al("fase", M.cambio_fase)
	estado.al("dia", M.nuevo_dia)
	estado.al("fin", function() estado.pedir("fin") end)
end

function M.nuevo_finao(datos)
	if datos.nombre == nil then
		local usados = {}
		for _, f in ipairs(M.finaos()) do
			usados[f.nombre] = true
		end
		local libres = util.filtrar(finao.NOMBRES, function(n) return not usados[n] end)
		datos = util.copiar(datos)
		datos.nombre = #libres > 0 and util.elegir(libres) or util.elegir(finao.NOMBRES)
	end
	local lx, ly = M.lugar_trabajo("descanso")
	local f = con_id(finao.nuevo(datos, lx + util.azar(-60, 60), ly + util.azar(-30, 30)))
	table.insert(M.unidades, f)
	return f
end

function M.nuevo_ente(tipo, x, y, horda)
	local e = con_id(ente.nuevo(tipo, x, y, horda))
	table.insert(M.unidades, e)
	return e
end

-- --- Consultas ---

function M.finaos()
	return util.filtrar(M.unidades, function(u) return u.clase == "finao" and not u.muerto end)
end

function M.entes_vivos()
	return util.filtrar(M.unidades, function(u) return u.clase == "ente" and not u.muerto end)
end

function M.jefes()
	return util.filtrar(M.unidades, function(u) return u.clase == "ente" and u.jefe and not u.muerto end)
end

function M.a_tablas()
	local out = {}
	for _, f in ipairs(M.finaos()) do
		table.insert(out, finao.a_tabla(f))
	end
	return out
end

function M.ente_cercano(x, y, max)
	local mejor, mejor_d = nil, max
	for _, e in ipairs(M.entes_vivos()) do
		local d = util.dist(x, y, e.x, e.y)
		if d < mejor_d then
			mejor, mejor_d = e, d
		end
	end
	return mejor
end

function M.aliados()
	local lista = M.finaos()
	if not M.jugador.muerto then
		table.insert(lista, M.jugador)
	end
	return lista
end

function M.aliado_cercano(x, y, max)
	local mejor, mejor_d = nil, max
	for _, a in ipairs(M.aliados()) do
		local d = util.dist(x, y, a.x, a.y)
		if d < mejor_d then
			mejor, mejor_d = a, d
		end
	end
	return mejor
end

function M.barricada_delante(x, y)
	for _, b in ipairs(M.barricadas) do
		if b.hp > 0 and math.abs(b.x - x) < 110 and math.abs(b.y - y) < 50 then
			return b
		end
	end
	return nil
end

function M.lugar_trabajo(lugar)
	local p = M.TRABAJO[lugar] or M.TRABAJO.descanso
	return p[1], p[2]
end

-- Cuántos Finaos trabajan en un lugar. Con `presentes`, solo cuenta a los que ya llegaron.
function M.trabajando_en(lugar, presentes)
	local n = 0
	local lx, ly = M.lugar_trabajo(lugar)
	for _, f in ipairs(M.finaos()) do
		if f.trabajo == lugar and not (estado.es_noche() and f.en_cuadrilla) then
			if not presentes or util.dist(f.x, f.y, lx, ly) <= 160 then
				n = n + 1
			end
		end
	end
	return n
end

function M.hay_rol(rol)
	return util.alguno(M.finaos(), function(f) return f.rol == rol end)
end

-- Lo que Abdón puede usar: las estaciones y los Finaos (para hablarles).
function M.interactuables()
	local lista = {}
	for _, s in ipairs(M.estaciones) do
		if not s.borrar then
			table.insert(lista, s)
		end
	end
	for _, f in ipairs(M.finaos()) do
		table.insert(lista, f)
	end
	return lista
end

function M.puede_interactuar(it)
	if it.clase == "finao" then
		return not it.muerto
	end
	return estaciones.puede(it, M)
end

function M.texto_accion(it)
	if it.clase == "finao" then
		return "Hablar con " .. it.nombre
	end
	return estaciones.texto(it, M)
end

function M.interactuar(it)
	if it.clase == "finao" then
		estado.pedir("finao", it)
	else
		estaciones.usar(it, M)
	end
end

-- --- Combate ---

function M.danar(u, n, fuente)
	if u.clase == "jugador" then
		jugador.danar(u, M, n, fuente)
	else
		unidad.danar(u, M, n, fuente)
	end
end

function M.danar_barricada(b, n)
	if b.hp <= 0 then
		return
	end
	b.hp = math.max(0, b.hp - n)
	if b.hp == 0 then
		estado.decir("¡Cayó una barricada!")
	end
end

-- La línea de un arpón lanzado, que se ve un instante.
function M.disparo(x0, y0, x1, y1)
	table.insert(M.efectos, con_id({clase = "disparo", x = x0, y = y0, x1 = x1, y1 = y1, vida = 0.12}))
end

function M.estallido(x, y, r, color)
	table.insert(M.efectos, con_id({clase = "estallido", x = x, y = y, radio = r, color = color, vida = 0.35}))
end

-- --- El paso del tiempo ---

local function enviar_ola(n)
	estado.decir(string.format("¡Suben ahogados del mar! Ola %d de 3.", M.olas + 1))
	estado.sonar("cuerno", 0, 0)
	for _ = 1, n do
		M.nuevo_ente("ahogado", util.azar(1800, 2700), util.azar(1700, 1900), true)
	end
end

local function punto_monte()
	return util.azar(250, M.ANCHO - 250), util.azar(150, M.MONTE - 80)
end

local function dirigir_noche(dt)
	if not estado.es_noche() then
		return
	end
	M.t_noche = M.t_noche + dt * estado.escala
	if estado.es_horda() then
		if M.olas < 3 and M.t_noche >= M.olas * M.T_OLA then
			enviar_ola(4 + 2 * M.olas)
			M.olas = M.olas + 1
		end
		-- Con la última ola sale el Invunche, el guardián de la cueva de los brujos.
		if not M.jefe_salio and M.olas == 3 then
			M.jefe_salio = true
			M.nuevo_ente("invunche", 2950, 1650, true)
			estado.decir("Algo grande sale de la cueva del acantilado. ¡Es el Invunche!")
			estado.historia("jefe_invunche", {
				{"Don Fermín", "¡Patrón! Ese es el Invunche, el que cuida la cueva de los brujos."},
				{"Don Fermín", "Camina en tres patas y embiste derecho. Hágase a un lado cuando agache la cabeza."},
			})
		end
	elseif M.cazados < M.MAX_CAZA and M.t_noche >= M.cazados * M.T_CAZA then
		if #M.entes_vivos() < 5 then
			local x, y = punto_monte()
			M.nuevo_ente(math.random() < 0.55 and "trauco" or "fiura", x, y, false)
		end
		M.cazados = M.cazados + 1
	end
	-- Desde la segunda noche, a medianoche baja el Chonchón.
	if not estado.es_horda() and estado.dia >= 2 and not M.jefe_salio and M.t_noche >= 90 then
		M.jefe_salio = true
		local x, y = punto_monte()
		M.nuevo_ente("chonchon", x, y, false)
		estado.decir("¡Tue, tue! Se oye un pájaro que no es pájaro.")
		estado.historia("jefe_chonchon", {
			{"Don Fermín", "Eso es un Chonchón: la cabeza de un brujo que vuela con las orejas."},
			{"Don Fermín", "Su grito paraliza a la cuadrilla. Péguele rápido, que de lejos no se deja."},
		})
	end
end

-- Un paso del mundo. La interfaz lo detiene mientras hay un menú o un diálogo.
function M.tick(dt)
	for _, u in ipairs(M.unidades) do
		if u.clase == "jugador" then
			jugador.tick(u, M, dt)
		elseif u.clase == "finao" then
			finao.tick(u, M, dt)
		else
			ente.tick(u, M, dt)
		end
	end
	for _, s in ipairs(M.estaciones) do
		estaciones.tick(s, M, dt)
	end
	dirigir_noche(dt)
	for _, fx in ipairs(M.efectos) do
		fx.vida = fx.vida - dt
	end
	-- Saca lo que ya terminó de caerse o se borró.
	M.unidades = util.filtrar(M.unidades, function(u)
		return not u.borrar and not (u.caida and u.caida > 0.95)
	end)
	M.estaciones = util.filtrar(M.estaciones, function(s) return not s.borrar end)
	M.efectos = util.filtrar(M.efectos, function(fx) return fx.vida > 0 end)
end

-- --- Eventos ---

function M.reanimar()
	if not estado.banderas.fermin then
		estado.banderas.fermin = true
		M.nuevo_finao({nombre = "Don Fermín", rol = "contador", oficio = "contador", trabajo = "ahumadero", en_cuadrilla = false})
		estado.dialogo({
			{"Don Fermín", "¿Ya? ¿Y el cigarro que le pedí?"},
			{"Don Fermín", "Fermín Oyarzo, contador en Puerto Montt por treinta años. Ahogado hace tres días. Muerto, pero no tonto."},
			{"Abdón", "¿Y ahora qué hago con usted?"},
			{"Don Fermín", "Póngame en el ahumadero. Y vaya a pescar al muelle, que con pescado ahumado se paga la sal y la brea."},
			{"Don Fermín", "En la playa siempre aparecen más ahogados. Tráigalos, que de noche nos va a hacer falta gente."},
		})
		return
	end
	local f = M.nuevo_finao({})
	estado.decir(string.format("%s volvió a abrir los ojos. Era %s en vida: %s.", f.nombre, f.oficio, finao.nombre_rol(f)))
	estado.historia("segundo_finao", {
		{"Don Fermín", "Cada finao sirve para algo según su oficio. Los carpinteros aguantan, los pescadores tiran arpón y las beatas rezan."},
		{"Don Fermín", "Háblele para mandarlo a trabajar o sacarlo de la cuadrilla de la noche."},
	})
end

function M.cambio_fase(fase)
	if fase == estado.ATARDECER then
		if estado.es_horda() then
			estado.decir("Atardece. Esta noche es de Marea Bruja: construye barricadas en la playa.")
		else
			estado.decir("Atardece. Elige quién sale de noche en la cuadrilla.")
		end
	elseif fase == estado.NOCHE then
		M.t_noche = 0
		M.olas = 0
		M.cazados = 0
		M.jefe_salio = false
		for _, f in ipairs(M.finaos()) do
			f.orden = finao.SEGUIR
		end
		if estado.es_horda() then
			estado.dialogo({
				{"Don Fermín", "Patrón, el mar está raro. Los ahogados de Cai Cai van a subir a la iglesia."},
				{"Don Fermín", "Si entran, el pueblo lo paga. Ponga a la cuadrilla a defender las barricadas."},
			})
		else
			estado.historia("primera_noche", {
				{"Don Fermín", "De noche bajan cosas del monte. Traucos y Fiuras, por lo menos."},
				{"Don Fermín", "El Trauco paraliza a los finaos con la mirada. A usted no, porque está vivo. Por ahora."},
				{"Don Fermín", "La Fiura tiene un aliento que pudre. Pelee lejos de ella si puede."},
				{"Don Fermín", "Cace lo que pueda: los trofeos se venden bien donde Lucio."},
			})
		end
	end
end

local function dejar_cuerpo(x, y)
	local s = con_id(estaciones.nueva("cuerpo", x, math.min(y, M.MAR - 50)))
	table.insert(M.estaciones, s)
end

function M.nuevo_dia()
	for _, u in ipairs(M.unidades) do
		if u.clase == "ente" then
			u.borrar = true
		end
	end
	local perdidos = {}
	for _, f in ipairs(M.finaos()) do
		if not finao.nuevo_dia(f) then
			table.insert(perdidos, f.nombre)
			f.borrar = true
			f.muerto = true
		end
	end
	if #perdidos > 0 then
		estado.decir("Se desarmó: " .. table.concat(perdidos, ", ") .. ". Hacía falta más sal.")
	end
	if estado.aldea <= 0 then
		estado.decir("Los ahogados entraron a la iglesia. Quicaví amaneció de luto y la Marea subió.")
		estado.medidor("marea", 10)
		estado.medidor("aldea", 60)
	end
	M.lena.usos = estaciones.USOS_LENA
	for _ = 1, math.random(1, 2) do
		dejar_cuerpo(util.azar(300, 1700), util.azar(1420, 1480))
	end
	estado.guardar(M.a_tablas())
	if estado.es_horda() then
		estado.decir(string.format("Día %d. Los viejos dicen que esta noche viene la Marea Bruja.", estado.dia))
	else
		estado.decir(string.format("Día %d. La marea dejó ahogados en la playa.", estado.dia))
	end
end

function M.ente_muerto(e, fuente)
	estado.sonar("muere_ente", -2)
	if e.tipo_ente == "mar" then
		estado.medidor("cerro", 1)
		if math.random() < 0.5 then
			dejar_cuerpo(e.x, e.y)
		end
	else
		local n = 1
		if fuente and fuente.rol == "saqueador" then
			n = n + 1
		end
		if e.jefe then
			n = n + 4
			estado.medidor("marea", -5)
			estado.decir(string.format("¡Cayó el %s! Te llevas cinco trofeos y la Marea baja un poco.", e.nombre))
		end
		estado.sumar("trofeo", n)
		estado.historia("primer_trofeo", {
			{"Don Fermín", "Eso es un trofeo. Lucio los compra y no pregunta. El gringo del hotel pagaría más, pero ese es otro cuento."},
		})
	end
end

function M.ente_en_iglesia(e)
	e.muerto = true
	e.borrar = true
	estado.medidor("aldea", -10)
	estado.medidor("marea", 2)
	estado.decir("¡Un ahogado llegó a la iglesia!")
end

function M.finao_cae(f)
	estado.decir(string.format("A %s se le cayó la cabeza en la pelea. El cuerpo quedó tirado.", f.nombre))
	dejar_cuerpo(f.x, f.y)
	unidad.caer(f)
end

function M.jugador_cae()
	local perdidos = math.floor(estado.cantidad("pescado") / 2)
	estado.gastar({pescado = perdidos})
	estado.medidor("juicio", -10)
	jugador.revivir(M.jugador, M.CAMA_X, M.CAMA_Y + 60)
	estado.decir("Abdón despertó en su cama sin saber cómo llegó. Le faltan pescados y algo de Juicio.")
end

function M.dar_orden(orden)
	local cuadrilla = util.filtrar(M.finaos(), function(f) return f.en_cuadrilla end)
	if #cuadrilla == 0 then
		estado.decir("No hay Finaos en la cuadrilla.")
		return
	end
	local negados = {}
	for _, f in ipairs(cuadrilla) do
		if not finao.dar_orden(f, orden, M.jugador.x, M.jugador.y) then
			table.insert(negados, f.nombre)
		end
	end
	local texto = "Orden: " .. finao.NOMBRE_ORDEN[orden] .. "."
	if #negados > 0 then
		texto = texto .. " No obedecen por moral baja: " .. table.concat(negados, ", ") .. "."
	end
	estado.decir(texto)
end

function M.dormir()
	M.jugador.energia = 100
	estado.medidor("juicio", 15)
	if estado.fase == estado.ATARDECER then
		estado.avanzar_fase()
	end
	if estado.es_horda() and M.olas < 3 then
		estado.medidor("aldea", -40)
		estado.medidor("marea", 5)
		estado.decir("Mientras Abdón dormía, la horda golpeó Quicaví.")
	end
	estado.avanzar_fase()
end

return M
