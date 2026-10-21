-- El almacén de Lucio: precios y la compra y venta. La ventana está en main/hud.gui_script.
local estado = require "juego.estado"
local mundo = require "juego.mundo"

local M = {}

M.VENTA = {{"pescado_ahumado", 5}, {"pescado", 2}, {"trofeo", 12}}
M.COMPRA = {{"sal", 4}, {"brea", 5}, {"chicha", 6}}

-- Don Fermín, el contador, regatea mejor.
function M.bono()
	return mundo.hay_rol("contador") and 1.2 or 1
end

function M.precio_venta(base)
	return math.floor(base * M.bono() + 0.5)
end

function M.vender(res, precio)
	local n = estado.cantidad(res)
	estado.gastar({[res] = n})
	estado.sumar("pesos", n * precio)
end

function M.comprar(res, precio)
	if estado.gastar({pesos = precio}) then
		estado.sumar(res, 1)
	end
end

return M
