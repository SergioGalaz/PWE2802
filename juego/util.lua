-- Ayudas chicas de vectores y azar. Los vectores son pares x, y sueltos,
-- con y hacia abajo, igual que en el mapa.
local M = {}

function M.largo(x, y)
	return math.sqrt(x * x + y * y)
end

function M.dist(ax, ay, bx, by)
	return M.largo(bx - ax, by - ay)
end

-- Vector unitario; (0, 0) si es muy corto.
function M.norm(x, y)
	local l = M.largo(x, y)
	if l < 1e-6 then
		return 0, 0
	end
	return x / l, y / l
end

function M.clamp(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

function M.azar(a, b)
	return a + math.random() * (b - a)
end

function M.elegir(lista)
	return lista[math.random(#lista)]
end

function M.copiar(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

function M.filtrar(lista, f)
	local out = {}
	for _, v in ipairs(lista) do
		if f(v) then
			out[#out + 1] = v
		end
	end
	return out
end

function M.alguno(lista, f)
	for _, v in ipairs(lista) do
		if f(v) then
			return true
		end
	end
	return false
end

-- Mezcla de dos colores {r, g, b}.
function M.mezclar(a, b, t)
	return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t}
end

return M
