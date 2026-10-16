extends Node
## Estado global de la partida: calendario de mareas, recursos, medidores y guardado.

signal phase_changed(phase: int)
signal day_started(day: int)
signal resources_changed
signal meters_changed
signal notify(text: String)
signal dialogue_requested(lines: Array)
signal demo_finished

enum Phase { DIA, ATARDECER, NOCHE }

const SAVE_PATH := "user://partida.json"
## Duración de cada fase en segundos reales (diseño: 12, 2 y 6 minutos).
const PHASE_DURATION := {Phase.DIA: 720.0, Phase.ATARDECER: 120.0, Phase.NOCHE: 360.0}
const PHASE_NAMES := {Phase.DIA: "Día", Phase.ATARDECER: "Atardecer", Phase.NOCHE: "Noche"}
## En la demo la tercera noche es de Marea Bruja. En el juego completo será una de cada siete.
const HORDE_EVERY := 3
const DEMO_LAST_DAY := 3
const START_RESOURCES := {
	"pescado": 0, "pescado_ahumado": 0, "sal": 4, "brea": 2, "madera": 6,
	"cuerpo": 1, "pesos": 20, "trofeo": 0, "chicha": 1,
}
const RESOURCE_NAMES := {
	"pescado": "Pescado", "pescado_ahumado": "Ahumado", "sal": "Sal", "brea": "Brea",
	"madera": "Madera", "cuerpo": "Cuerpos", "pesos": "Pesos", "trofeo": "Trofeos", "chicha": "Chicha",
}

const UNIT_NAMES := {
	"pescado": ["pescado", "pescados"], "pescado_ahumado": ["ahumado", "ahumados"],
	"sal": ["saco de sal", "sacos de sal"], "brea": ["tarro de brea", "tarros de brea"],
	"madera": ["tabla", "tablas"], "cuerpo": ["cuerpo", "cuerpos"], "pesos": ["peso", "pesos"],
	"trofeo": ["trofeo", "trofeos"], "chicha": ["botella de chicha", "botellas de chicha"],
}

var day := 1
var phase: int = Phase.DIA
var phase_time := 0.0
## Multiplicador del reloj, solo para pruebas.
var time_scale := 1.0
var running := false
var demo_done := false

var resources: Dictionary = {}
var marea := 10.0
var cerro := 10.0
var juicio := 100.0
var village_hp := 100.0
## Eventos de historia ya vistos.
var flags: Dictionary = {}
## Finaos guardados, para reconstruirlos al cargar.
var saved_finaos: Array = []
## Lo usa la interfaz para bloquear el movimiento mientras hay un menú abierto.
var ui_blocking := false
## Pausa breve de la entrada al cerrar un menú, para que el mismo botón no vuelva a abrirlo.
var ui_cooldown := 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	day = 1
	phase = Phase.DIA
	phase_time = 0.0
	resources = START_RESOURCES.duplicate()
	marea = 10.0
	cerro = 10.0
	juicio = 100.0
	village_hp = 100.0
	flags = {}
	saved_finaos = []
	demo_done = false


func set_ui_blocking(blocking: bool) -> void:
	ui_blocking = blocking
	if not blocking:
		ui_cooldown = 0.25


func _process(delta: float) -> void:
	ui_cooldown = maxf(0.0, ui_cooldown - delta)
	if not running:
		return
	phase_time += delta * time_scale
	if phase_time >= PHASE_DURATION[phase]:
		advance_phase()


func advance_phase() -> void:
	phase_time = 0.0
	match phase:
		Phase.DIA:
			phase = Phase.ATARDECER
		Phase.ATARDECER:
			phase = Phase.NOCHE
			change_meter("marea", 10.0 if is_horde_night() else 4.0)
		Phase.NOCHE:
			_start_new_day()
			return
	phase_changed.emit(phase)


func _start_new_day() -> void:
	if day >= DEMO_LAST_DAY and not demo_done:
		demo_done = true
		demo_finished.emit()
	day += 1
	phase = Phase.DIA
	phase_time = 0.0
	change_meter("juicio", 5.0)
	phase_changed.emit(phase)
	day_started.emit(day)


func is_night() -> bool:
	return phase == Phase.NOCHE


func is_horde_night() -> bool:
	return day % HORDE_EVERY == 0


func is_low_tide() -> bool:
	return day % 2 == 0


func tide_name() -> String:
	return "Bajamar" if is_low_tide() else "Pleamar"


## Hora del día como texto. El día va de 6:00 a 18:00, el atardecer hasta las 20:00 y la noche hasta las 6:00.
func clock_text() -> String:
	var t: float = phase_time / PHASE_DURATION[phase]
	var hours := 0.0
	match phase:
		Phase.DIA:
			hours = 6.0 + t * 12.0
		Phase.ATARDECER:
			hours = 18.0 + t * 2.0
		Phase.NOCHE:
			hours = fmod(20.0 + t * 10.0, 24.0)
	var h := int(hours)
	var m := int((hours - h) * 60.0) / 10 * 10
	return "%02d:%02d" % [h, m]


## Fracción de oscuridad, de 0 (mediodía) a 1 (noche cerrada).
func darkness() -> float:
	var t: float = phase_time / PHASE_DURATION[phase]
	match phase:
		Phase.DIA:
			return clampf(1.0 - t * 8.0, 0.0, 1.0) * 0.5
		Phase.ATARDECER:
			return t
	return 1.0


# --- Recursos ---

func amount(res: String) -> int:
	return int(resources.get(res, 0))


func add(res: String, n: int) -> void:
	resources[res] = amount(res) + n
	resources_changed.emit()


func has_all(costs: Dictionary) -> bool:
	for res in costs:
		if amount(res) < int(costs[res]):
			return false
	return true


func spend(costs: Dictionary) -> bool:
	if not has_all(costs):
		return false
	for res in costs:
		resources[res] = amount(res) - int(costs[res])
	resources_changed.emit()
	return true


## Cantidad con el nombre del recurso en singular o plural: "1 cuerpo", "3 cuerpos".
static func quantity(res: String, n: int) -> String:
	var forms: Array = UNIT_NAMES.get(res, [res, res])
	return "%d %s" % [n, forms[0] if n == 1 else forms[1]]


static func costs_text(costs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in costs:
		parts.append(quantity(res, int(costs[res])))
	return ", ".join(parts)


# --- Medidores ---

func change_meter(meter: String, delta: float) -> void:
	match meter:
		"marea":
			marea = clampf(marea + delta, 0.0, 100.0)
		"cerro":
			cerro = clampf(cerro + delta, 0.0, 100.0)
		"juicio":
			juicio = clampf(juicio + delta, 0.0, 100.0)
		"aldea":
			village_hp = clampf(village_hp + delta, 0.0, 100.0)
	meters_changed.emit()


# --- Historia ---

## Muestra un diálogo una sola vez por partida.
func story(flag: String, lines: Array) -> void:
	if flags.get(flag, false):
		return
	flags[flag] = true
	dialogue_requested.emit(lines)


func say(text: String) -> void:
	notify.emit(text)


# --- Guardado ---

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(finaos: Array) -> void:
	var data := {
		"version": 1, "day": day, "resources": resources, "marea": marea, "cerro": cerro,
		"juicio": juicio, "village_hp": village_hp, "flags": flags, "finaos": finaos,
		"demo_done": demo_done,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar la partida: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	reset()
	day = int(data.get("day", 1))
	for res in data.get("resources", {}):
		resources[res] = int(data["resources"][res])
	marea = float(data.get("marea", 10.0))
	cerro = float(data.get("cerro", 10.0))
	juicio = float(data.get("juicio", 100.0))
	village_hp = float(data.get("village_hp", 100.0))
	flags = data.get("flags", {})
	saved_finaos = data.get("finaos", [])
	demo_done = bool(data.get("demo_done", false))
	return true
