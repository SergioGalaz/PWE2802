-- Estado global de la partida: calendario de mareas, recursos, medidores y guardado.
-- No usa nada de Defold salvo para guardar, así la prueba automática corre también
-- con LuaJIT a secas (tools/prueba.lua).
local M = {}

M.DIA, M.ATARDECER, M.NOCHE = 1, 2, 3
-- Duración de cada fase en segundos reales (diseño: 12, 2 y 6 minutos).
M.DURACION = {720, 120, 360}
M.NOMBRE_FASE = {"Día", "Atardecer", "Noche"}
-- En la demo la tercera noche es de Marea Bruja. En el juego completo será una de cada siete.
M.HORDA_CADA = 3
M.ULTIMO_DIA = 3
M.INICIO = {
	pescado = 0, pescado_ahumado = 0, sal = 4, brea = 2, madera = 6,
	cuerpo = 1, pesos = 20, trofeo = 0, chicha = 1,
}
M.RECURSOS = {"pescado", "pescado_ahumado", "sal", "brea", "madera", "cuerpo", "pesos", "trofeo", "chicha"}
M.NOMBRES = {
	pescado = "Pescado", pescado_ahumado = "Ahumado", sal = "Sal", brea = "Brea",
	madera = "Madera", cuerpo = "Cuerpos", pesos = "Pesos", trofeo = "Trofeos", chicha = "Chicha",
}
M.UNIDADES = {
	pescado = {"pescado", "pescados"}, pescado_ahumado = {"ahumado", "ahumados"},
	sal = {"saco de sal", "sacos de sal"}, brea = {"tarro de brea", "tarros de brea"},
	madera = {"tabla", "tablas"}, cuerpo = {"cuerpo", "cuerpos"}, pesos = {"peso", "pesos"},
	trofeo = {"trofeo", "trofeos"}, chicha = {"botella de chicha", "botellas de chicha"},
}

-- Multiplicador del reloj, solo para pruebas.
M.escala = 1
M.corriendo = false
-- La interfaz lo prende mientras hay un menú o un diálogo: el mundo se detiene.
M.pausa = false
-- La rueda de órdenes bloquea al jugador sin detener el mundo.
M.bloqueo = false
-- Pausa breve de la entrada al cerrar un menú, para que el mismo botón no vuelva a abrirlo.
M.espera_ui = 0

-- Colas que lee la interfaz y el script principal en su propio contexto.
M.avisos = {}
M.dialogos = {}
M.sonidos = {}
M.peticiones = {}

local oyentes = {}

-- Avisa a quien escuche: "fase", "dia" y "fin".
function M.al(evento, fn)
	oyentes[evento] = oyentes[evento] or {}
	table.insert(oyentes[evento], fn)
end

function M.olvidar_oyentes()
	oyentes = {}
end

local function emitir(evento, ...)
	for _, fn in ipairs(oyentes[evento] or {}) do
		fn(...)
	end
end

function M.reiniciar()
	M.dia = 1
	M.fase = M.DIA
	M.tiempo = 0
	M.recursos = {}
	for k, v in pairs(M.INICIO) do
		M.recursos[k] = v
	end
	M.marea = 10
	M.cerro = 10
	M.juicio = 100
	M.aldea = 100
	M.banderas = {}
	M.finaos_guardados = {}
	M.demo_terminada = false
	M.avisos = {}
	M.dialogos = {}
	M.sonidos = {}
	M.peticiones = {}
end

function M.set_bloqueo(b)
	M.bloqueo = b
	if not b then
		M.espera_ui = 0.25
	end
end

function M.tick(dt)
	M.espera_ui = math.max(0, M.espera_ui - dt)
	if not M.corriendo then
		return
	end
	M.tiempo = M.tiempo + dt * M.escala
	if M.tiempo >= M.DURACION[M.fase] then
		M.avanzar_fase()
	end
end

local function empezar_dia()
	if M.dia >= M.ULTIMO_DIA and not M.demo_terminada then
		M.demo_terminada = true
		emitir("fin")
	end
	M.dia = M.dia + 1
	M.fase = M.DIA
	M.tiempo = 0
	M.medidor("juicio", 5)
	emitir("fase", M.fase)
	emitir("dia", M.dia)
end

function M.avanzar_fase()
	M.tiempo = 0
	if M.fase == M.DIA then
		M.fase = M.ATARDECER
	elseif M.fase == M.ATARDECER then
		M.fase = M.NOCHE
		M.medidor("marea", M.es_horda() and 10 or 4)
	else
		empezar_dia()
		return
	end
	emitir("fase", M.fase)
end

function M.es_noche()
	return M.fase == M.NOCHE
end

function M.es_horda()
	return M.dia % M.HORDA_CADA == 0
end

function M.bajamar()
	return M.dia % 2 == 0
end

function M.nombre_marea()
	return M.bajamar() and "Bajamar" or "Pleamar"
end

-- Hora del día como texto. El día va de 6:00 a 18:00, el atardecer hasta las 20:00 y la noche hasta las 6:00.
function M.reloj()
	local t = M.tiempo / M.DURACION[M.fase]
	local horas
	if M.fase == M.DIA then
		horas = 6 + t * 12
	elseif M.fase == M.ATARDECER then
		horas = 18 + t * 2
	else
		horas = (20 + t * 10) % 24
	end
	local h = math.floor(horas)
	local m = math.floor((horas - h) * 6) * 10
	return string.format("%02d:%02d", h, m)
end

-- Fracción de oscuridad, de 0 (mediodía) a 1 (noche cerrada).
function M.oscuridad()
	local t = M.tiempo / M.DURACION[M.fase]
	if M.fase == M.DIA then
		return math.max(0, math.min(1, 1 - t * 8)) * 0.5
	elseif M.fase == M.ATARDECER then
		return t
	end
	return 1
end

-- --- Recursos ---

function M.cantidad(res)
	return M.recursos[res] or 0
end

function M.sumar(res, n)
	M.recursos[res] = M.cantidad(res) + n
end

function M.alcanza(costos)
	for res, n in pairs(costos) do
		if M.cantidad(res) < n then
			return false
		end
	end
	return true
end

function M.gastar(costos)
	if not M.alcanza(costos) then
		return false
	end
	for res, n in pairs(costos) do
		M.recursos[res] = M.cantidad(res) - n
	end
	return true
end

-- Cantidad con el nombre del recurso en singular o plural: "1 cuerpo", "3 cuerpos".
function M.cuanto(res, n)
	local formas = M.UNIDADES[res] or {res, res}
	return string.format("%d %s", n, n == 1 and formas[1] or formas[2])
end

-- Los costos van como lista de pares, para que el texto salga siempre en el mismo orden.
function M.texto_costos(costos)
	local partes = {}
	for _, res in ipairs(M.RECURSOS) do
		if costos[res] then
			partes[#partes + 1] = M.cuanto(res, costos[res])
		end
	end
	return table.concat(partes, ", ")
end

-- --- Medidores ---

function M.medidor(nombre, d)
	local function c(v)
		return math.max(0, math.min(100, v + d))
	end
	if nombre == "marea" then
		M.marea = c(M.marea)
	elseif nombre == "cerro" then
		M.cerro = c(M.cerro)
	elseif nombre == "juicio" then
		M.juicio = c(M.juicio)
	elseif nombre == "aldea" then
		M.aldea = c(M.aldea)
	end
end

-- --- Historia, avisos y sonidos ---

-- Cada línea es {quién habla, texto}.
function M.dialogo(lineas)
	for _, l in ipairs(lineas) do
		table.insert(M.dialogos, l)
	end
end

-- Muestra un diálogo una sola vez por partida.
function M.historia(bandera, lineas)
	if M.banderas[bandera] then
		return
	end
	M.banderas[bandera] = true
	M.dialogo(lineas)
end

function M.decir(texto)
	table.insert(M.avisos, texto)
end

-- Un efecto de sonido, con volumen en decibeles y una variación de tono.
function M.sonar(nombre, db, variacion)
	table.insert(M.sonidos, {nombre, db or 0, variacion or 0.08})
end

-- Pide a la interfaz que abra una ventana: "tienda", "pesca" o "finao".
function M.pedir(ventana, dato)
	table.insert(M.peticiones, {ventana, dato})
end

-- --- Guardado ---

local memoria = nil

local function copia_honda(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = copia_honda(v)
	end
	return c
end

local function archivo()
	return sys.get_save_file("marea_bruja", "partida")
end

function M.hay_guardado()
	if sys then
		local t = sys.load(archivo())
		return t ~= nil and t.version ~= nil
	end
	return memoria ~= nil
end

function M.borrar_guardado()
	if sys then
		os.remove(archivo())
	end
	memoria = nil
end

function M.guardar(finaos)
	local datos = {
		version = 1, dia = M.dia, recursos = M.recursos, marea = M.marea, cerro = M.cerro,
		juicio = M.juicio, aldea = M.aldea, banderas = M.banderas, finaos = finaos,
		demo_terminada = M.demo_terminada,
	}
	if sys then
		if not sys.save(archivo(), datos) then
			print("No se pudo guardar la partida")
		end
	else
		memoria = copia_honda(datos)
	end
end

function M.cargar()
	local d
	if sys then
		d = sys.load(archivo())
	else
		d = copia_honda(memoria)
	end
	if d == nil or d.version == nil then
		return false
	end
	M.reiniciar()
	M.dia = d.dia or 1
	for res, n in pairs(d.recursos or {}) do
		M.recursos[res] = n
	end
	M.marea = d.marea or 10
	M.cerro = d.cerro or 10
	M.juicio = d.juicio or 100
	M.aldea = d.aldea or 100
	M.banderas = {}
	for k, v in pairs(d.banderas or {}) do
		M.banderas[k] = v
	end
	M.finaos_guardados = {}
	for i, f in ipairs(d.finaos or {}) do
		M.finaos_guardados[i] = f
	end
	M.demo_terminada = d.demo_terminada or false
	return true
end

M.reiniciar()

return M
