-- Dibuja el mundo en Defold: crea y mueve los objetos que muestran cada unidad,
-- estación y efecto. Corre en main.script. El mundo usa y hacia abajo; Defold, hacia arriba.
local estado = require "juego.estado"
local mundo = require "juego.mundo"
local finao = require "juego.finao"
local estaciones = require "juego.estaciones"
local tamanos = require "juego.tamanos"
local util = require "juego.util"

local M = {}

local ALTO = 2000
-- Profundidad: el suelo atrás, después las sombras, lo que se ordena por altura y encima las barras y textos.
local Z_SUELO, Z_PISO, Z_SOMBRA, Z_FX_SUELO = -0.9, -0.8, -0.7, -0.6
local Z_FX, Z_BARRA, Z_TEXTO = 0.5, 0.6, 0.9
local ESCALA_SUELO = 2

-- La cámara que se manda al render: centro en coordenadas de Defold y zoom en píxeles de pantalla.
M.camara = {x = 960, y = 1000, zoom = 1.15, ancho = 1920, alto = 1200}
M.ZOOM = 1.15

local function zy(y)
	return y / 2500 - 0.4
end

local function pos(x, y, z)
	return vmath.vector3(x, ALTO - y, z)
end

local registro = {}
local estaticos = {}
local visto = {}

-- --- Objetos sueltos ---

local function crear(fabrica, x, y, z, escala)
	local id = factory.create("#" .. fabrica, pos(x, y, z))
	if escala then
		go.set_scale(escala, id)
	end
	return id
end

local function url(id, comp)
	return msg.url(nil, id, comp or "sprite")
end

-- Un sprite de la interfaz (rectángulo, círculo o anillo) en el mundo.
local Pieza = {}
Pieza.__index = Pieza

local function pieza(imagen)
	local p = setmetatable({id = crear("ui", 0, 0, 0), imagen = "blanco", visible = true}, Pieza)
	p.url = url(p.id)
	if imagen ~= "blanco" then
		sprite.play_flipbook(p.url, imagen)
		p.imagen = imagen
	end
	return p
end

-- Ubica la pieza con su centro en (x, y) del mundo y la estira a w por h.
function Pieza:poner(x, y, z, w, h, color, angulo)
	local base = self.imagen == "blanco" and 8 or (self.imagen == "flecha" and 16 or (self.imagen == "arco" and 192 or 128))
	go.set_position(pos(x, y, z), self.id)
	go.set_scale(vmath.vector3(w / base, h / base, 1), self.id)
	go.set_rotation(vmath.quat_rotation_z(angulo or 0), self.id)
	go.set(self.url, "tint", vmath.vector4(color[1], color[2], color[3], color[4] or 1))
	if not self.visible then
		self.visible = true
		msg.post(self.url, "enable")
	end
end

function Pieza:ocultar()
	if self.visible then
		self.visible = false
		msg.post(self.url, "disable")
	end
end

function Pieza:borrar()
	go.delete(self.id)
end

-- Un texto del mundo (los nombres y los títulos de las estaciones).
local Texto = {}
Texto.__index = Texto

local function texto(escala)
	local t = setmetatable({id = crear("texto", 0, 0, Z_TEXTO), texto = nil, visible = true}, Texto)
	t.url = url(t.id, "label")
	if escala then
		go.set_scale(escala, t.id)
	end
	return t
end

function Texto:poner(x, y, s, color)
	go.set_position(pos(x, y, Z_TEXTO), self.id)
	if s ~= self.texto then
		self.texto = s
		label.set_text(self.url, s)
	end
	if color then
		go.set(self.url, "color", vmath.vector4(color[1], color[2], color[3], color[4] or 1))
	end
	if not self.visible then
		self.visible = true
		msg.post(self.url, "enable")
	end
end

function Texto:ocultar()
	if self.visible then
		self.visible = false
		msg.post(self.url, "disable")
	end
end

function Texto:borrar()
	go.delete(self.id)
end

-- Un sprite pixel art, apoyado por los pies o por el centro.
local Figura = {}
Figura.__index = Figura

local function figura(fabrica, anim)
	local f = setmetatable({id = crear(fabrica or "figura", 0, 0, 0), anim = nil, visible = true}, Figura)
	f.url = url(f.id)
	if anim then
		f:animar(anim)
	end
	return f
end

function Figura:animar(anim)
	if anim ~= self.anim then
		self.anim = anim
		sprite.play_flipbook(self.url, anim)
	end
end

function Figura:poner(x, y, z, escala, voltear, angulo, color)
	go.set_position(pos(x, y, z), self.id)
	go.set_scale(escala, self.id)
	go.set_rotation(vmath.quat_rotation_z(angulo or 0), self.id)
	sprite.set_hflip(self.url, voltear or false)
	local c = color or {1, 1, 1, 1}
	go.set(self.url, "tint", vmath.vector4(c[1], c[2], c[3], c[4] or 1))
end

function Figura:borrar()
	go.delete(self.id)
end

-- Altura en pantalla de un sprite a cierta escala.
local function alto_sprite(nombre, escala)
	local t = tamanos[nombre]
	return t and t[2] * escala or 0, t and t[1] * escala or 0
end

-- --- El escenario fijo ---

local function armar_escenario()
	local function suelo(nombre, cx, cy, z)
		local f = figura("mapa", nombre)
		f:poner(cx, cy, z, ESCALA_SUELO)
		table.insert(estaticos, f)
		return f
	end
	suelo("suelo", mundo.ANCHO / 2, mundo.MAR / 2, Z_SUELO)
	M.mar = suelo("mar_0", mundo.ANCHO / 2, (mundo.MAR + mundo.ALTO) / 2, Z_SUELO)
	suelo("piso", 648 + 312, 976 + 168, Z_PISO)
	suelo("muelle", 1000, 1510, Z_PISO)
	-- Sprites apoyados por la base, en orden de altura con todo lo demás.
	local function apoyado(nombre, bx, by, z)
		local h = alto_sprite(nombre, 1.5)
		local f = figura("figura", nombre)
		f:poner(bx, by - h / 2, z or zy(by), 1.5)
		table.insert(estaticos, f)
		return f
	end
	-- El palafito de Abdón: piso de tablas sobre pilotes.
	for x = 680, 1259, 80 do
		apoyado("pilote", x, 1392, Z_PISO - 0.02)
	end
	-- El Santa Rosita, amarrado junto al muelle; se mece con el agua.
	M.bote = apoyado("bote", 1200, 1650, Z_PISO - 0.01)
	for _, c in ipairs(mundo.CASAS) do
		apoyado(c[1], c[2], c[3])
	end
	apoyado("iglesia", mundo.IGLESIA_X, mundo.IGLESIA_Y + 110)
	for i, a in ipairs(mundo.ARBOLES) do
		apoyado("arbol_" .. ((i - 1) % 2), a[1], a[2] + 50)
	end
	for _, zona in ipairs(mundo.ZONAS) do
		local t = texto(1.6)
		t:poner(zona[2], zona[3] + 25, zona[1], {1, 1, 1, 0.55})
		table.insert(estaticos, t)
	end
end

function M.armar()
	M.limpiar()
	armar_escenario()
	M.t_agua = 0
	M.cuadro_agua = 0
	local p = mundo.jugador
	M.camara.x, M.camara.y = p.x, ALTO - p.y
end

function M.limpiar()
	for _, o in ipairs(estaticos) do
		o:borrar()
	end
	estaticos = {}
	for _, r in pairs(registro) do
		for _, o in pairs(r) do
			if type(o) == "table" and o.borrar then
				o:borrar()
			end
		end
	end
	registro = {}
end

-- --- Unidades ---

local function anim_unidad(u)
	local base = u.sprite .. "_" .. u.vista
	if not tamanos[base] then
		base = u.sprite .. "_frente"
	end
	local paso = math.floor(u.paso * 7) % 2
	if u.pose_ataque > 0 and tamanos[base .. "_ataque"] then
		return base .. "_ataque", 0
	end
	if paso == 1 and tamanos[base .. "_paso"] then
		return base .. "_paso", 1
	end
	return base, 0
end

local function dibujar_unidad(u, r, t)
	if not r.cuerpo then
		r.sombra = pieza("circulo")
		r.cuerpo = figura("figura")
		r.barra_fondo = pieza("blanco")
		r.barra = pieza("blanco")
		r.anillo = pieza("anillo")
		r.nombre = texto()
		if u.clase == "finao" then
			r.franja = pieza("blanco")
		elseif u.clase == "jugador" then
			r.flecha = pieza("flecha")
			r.arco = pieza("arco")
		else
			r.pulso = pieza("circulo")
		end
	end
	local esc = u.escala
	local anim, paso = anim_unidad(u)
	local h = alto_sprite(anim, esc)
	local alfa, angulo = 1, 0
	if u.caida then
		-- La caída al morir: se ladea hacia donde miraba y se apaga.
		local lado = u.izquierda and 1 or -1
		local c = math.min(1, u.caida / 0.35)
		angulo = lado * math.pi / 2 * c * c
		alfa = 1 - util.clamp((u.caida - 0.35) / 0.6, 0, 1)
	end
	local pie_y = u.y + u.radio
	r.sombra:poner(u.x, pie_y - 2, Z_SOMBRA, u.radio * 2.2, u.radio * 0.77, {0, 0, 0, 0.3 * alfa})
	local sube = paso == 1 and -esc or 0
	if u.altura > 0 then
		sube = -u.altura + math.sin(u.t_vuelo * 4) * 4
	end
	-- El centro del sprite, girado alrededor de los pies cuando se cae.
	local base_y = pie_y + sube
	local cx = u.x - math.sin(angulo) * h / 2
	local cy = base_y - math.cos(angulo) * h / 2
	r.cuerpo:animar(anim)
	local brillo = u.destello > 0 and 2.5 or 1
	r.cuerpo:poner(cx, cy, zy(u.y), esc, u.izquierda and u.vista == "lado", angulo, {brillo, brillo, brillo, alfa})
	local arriba = base_y - h
	local vivo = not u.muerto
	if vivo and u.hp < u.max_hp then
		local w = u.radio * 2.4
		r.barra_fondo:poner(u.x, arriba - 9, Z_BARRA, w, 6, {0, 0, 0, 0.7})
		local fw = w * u.hp / u.max_hp
		r.barra:poner(u.x - w / 2 + fw / 2, arriba - 9, Z_BARRA + 0.001, fw, 6, {0.85, 0.2, 0.2})
	else
		r.barra_fondo:ocultar()
		r.barra:ocultar()
	end
	if vivo and u.aturdido > 0 then
		local d = (u.radio + 6) * 2
		r.anillo:poner(u.x, u.y, Z_BARRA, d, d, {1, 0.9, 0.2, 0.9})
	else
		r.anillo:ocultar()
	end
	if vivo and (u.con_nombre ~= false) then
		r.nombre:poner(u.x, arriba - 24, u.nombre)
	else
		r.nombre:ocultar()
	end
	if r.franja then
		-- Una franja del color del rol a los pies, para distinguir la cuadrilla.
		local c = finao.ROLES[u.rol].color
		r.franja:poner(u.x, pie_y + 4.5, Z_SOMBRA + 0.01, 28, 5, {c[1], c[2], c[3], alfa})
	end
	if r.flecha then
		-- Marca de hacia dónde apunta el arpón, y el arco del golpe.
		local ang = -math.atan2(u.frente_y, u.frente_x)
		local d = u.radio + 23
		r.flecha:poner(u.x + u.frente_x * d, u.y + u.frente_y * d, Z_BARRA, 16, 14, {0.95, 0.95, 1, 0.8}, ang)
		if u.golpe > 0 then
			r.arco:poner(u.x, u.y, Z_FX, 192, 192, {1, 1, 1, u.golpe * 4}, ang)
		else
			r.arco:ocultar()
		end
	end
	if r.pulso then
		if u.pulso > 0 then
			local d = u.pulso_radio * (1 - u.pulso) * 2
			local c = u.pulso_color
			r.pulso:poner(u.x, u.y, Z_FX_SUELO, d, d, c)
		else
			r.pulso:ocultar()
		end
	end
end

-- --- Estaciones ---

local function dibujar_estacion(s, r, t)
	if not r.titulo then
		r.titulo = texto()
		if s.sprite then
			r.sombra = pieza("circulo")
			r.cuerpo = figura("figura", s.sprite)
		end
		if s.tipo == "ahumadero" then
			r.barra = pieza("blanco")
			r.humo = {pieza("circulo"), pieza("circulo"), pieza("circulo")}
		elseif s.tipo == "mesa" then
			r.brillo = pieza("circulo")
		elseif s.tipo == "barricada" then
			r.barra_fondo = pieza("blanco")
			r.barra = pieza("blanco")
		end
	end
	local alto = s.h
	if r.cuerpo then
		local h, w = alto_sprite(s.sprite, 1.5)
		local alfa = 1
		if s.tipo == "barricada" and s.hp <= 0 then
			alfa = 0.3
		end
		r.sombra:poner(s.x, s.y + h / 2 - 4, Z_SOMBRA, w * 0.9, w * 0.27, {0, 0, 0, 0.25 * alfa})
		r.cuerpo:poner(s.x, s.y, zy(s.y), 1.5, false, 0, {1, 1, 1, alfa})
	end
	local titulo = s.titulo
	if s.tipo == "barricada" and s.hp <= 0 then
		titulo = "Barricada (sin construir)"
	end
	r.titulo:poner(s.x, s.y - alto / 2 - 25, titulo)
	if s.tipo == "ahumadero" then
		if s.cola > 0 then
			local w = 110 * s.avance / estaciones.T_AHUMADO
			r.barra:poner(s.x - 55 + w / 2, s.y + 45, Z_BARRA, math.max(w, 0.1), 10, {0.95, 0.6, 0.2})
			for i, h in ipairs(r.humo) do
				local sube = (t * 50 + (i - 1) * 30) % 60
				h:poner(s.x - 20 + (i - 1) * 20, s.y - 70 - sube, Z_FX, 20, 20, {0.8, 0.8, 0.8, 0.4})
			end
		else
			r.barra:ocultar()
			for _, h in ipairs(r.humo) do
				h:ocultar()
			end
		end
	elseif s.tipo == "mesa" then
		r.brillo:poner(s.x, s.y - 22, Z_FX, 52, 52, {0.55, 0.2, 0.7, 0.15 + 0.1 * math.sin(t * 1000 / 300)})
	elseif s.tipo == "barricada" then
		if s.hp > 0 then
			r.barra_fondo:poner(s.x, s.y + 33, Z_BARRA, 180, 6, {0, 0, 0, 0.6})
			local w = 180 * s.hp / estaciones.HP_BARRICADA
			r.barra:poner(s.x - 90 + w / 2, s.y + 33, Z_BARRA + 0.001, w, 6, {0.9, 0.7, 0.2})
		else
			r.barra_fondo:ocultar()
			r.barra:ocultar()
		end
	end
end

-- --- Efectos ---

local function dibujar_efecto(fx, r)
	if not r.pieza then
		r.pieza = pieza(fx.clase == "disparo" and "blanco" or "circulo")
	end
	if fx.clase == "disparo" then
		local dx, dy = fx.x1 - fx.x, fx.y1 - fx.y
		local largo = util.largo(dx, dy)
		r.pieza:poner((fx.x + fx.x1) / 2, (fx.y + fx.y1) / 2, Z_FX, largo, 4, {0.95, 0.95, 0.85}, -math.atan2(dy, dx))
	else
		local c = fx.color
		local d = fx.radio * (1.2 - fx.vida) * 2
		r.pieza:poner(fx.x, fx.y, Z_FX, d, d, {c[1], c[2], c[3], c[4] * fx.vida / 0.35})
	end
end

-- --- Cámara ---

local function mover_camara(dt)
	local w, h = window.get_size()
	if w == 0 or h == 0 then
		w, h = 1920, 1200
	end
	local zoom = M.ZOOM * math.min(w / 1920, h / 1200)
	local mw, mh = w / 2 / zoom, h / 2 / zoom
	local p = mundo.jugador
	local c = M.camara
	local k = math.min(1, 8 * dt)
	c.x = c.x + (p.x - c.x) * k
	c.y = c.y + ((ALTO - p.y) - c.y) * k
	c.x = util.clamp(c.x, mw, math.max(mw, mundo.ANCHO - mw))
	c.y = util.clamp(c.y, mh, math.max(mh, ALTO - mh))
	c.zoom, c.ancho, c.alto = zoom, w, h
	msg.post("@render:", "camara", {x = c.x, y = c.y, zoom = zoom})
end

-- Dónde está un punto del mundo en la pantalla, de 0 a 1 desde la esquina de abajo a la izquierda.
function M.en_pantalla(x, y)
	local c = M.camara
	local sx = (x - c.x) * c.zoom + c.ancho / 2
	local sy = ((ALTO - y) - c.y) * c.zoom + c.alto / 2
	return sx / c.ancho, sy / c.alto
end

-- --- Cada cuadro ---

local function sincronizar(lista, dibujar, t)
	for _, e in ipairs(lista) do
		local r = registro[e.id]
		if not r then
			r = {}
			registro[e.id] = r
		end
		visto[e.id] = true
		dibujar(e, r, t)
	end
end

function M.actualizar(dt)
	if not mundo.jugador then
		return
	end
	M.t_agua = M.t_agua + dt
	if M.t_agua > 0.6 then
		M.t_agua = 0
		M.cuadro_agua = 1 - M.cuadro_agua
		M.mar:animar("mar_" .. M.cuadro_agua)
		local h = alto_sprite("bote", 1.5)
		M.bote:poner(1200, 1650 + M.cuadro_agua * 3 - h / 2, Z_PISO - 0.01, 1.5)
	end
	local t = socket and socket.gettime() or os.clock()
	visto = {}
	sincronizar(mundo.unidades, dibujar_unidad, t)
	sincronizar(mundo.estaciones, dibujar_estacion, t)
	sincronizar(mundo.efectos, dibujar_efecto, t)
	for id, r in pairs(registro) do
		if not visto[id] then
			for _, o in pairs(r) do
				if type(o) == "table" then
					if o.borrar then
						o:borrar()
					else
						for _, h in ipairs(o) do
							h:borrar()
						end
					end
				end
			end
			registro[id] = nil
		end
	end
	mover_camara(dt)
end

return M
