@tool
class_name CopilotMd3Tokens
extends RefCounted
# Material 3 design tokens (baseline scheme) for the plugin's own component
# library. Raw data only: color roles, type scale, shape, elevation,
# interaction states, motion, spacing.
# Reference: docs/MATERIAL3.md. Components read these values through
# CopilotMd3Scheme / CopilotMd3Motion; raw values stay in this file.

# --- Color roles -------------------------------------------------------------
# Baseline M3 palette mapped to roles, plus plugin-only "status-*" roles for
# ready/notice/error accents. Roles shared by both schemes live in ROLES_FIXED
# and are merged by CopilotMd3Scheme.

const ROLES_LIGHT := {
	"primary": "#6750a4",
	"on-primary": "#ffffff",
	"primary-container": "#eaddff",
	"on-primary-container": "#21005d",
	"secondary": "#625b71",
	"on-secondary": "#ffffff",
	"secondary-container": "#e8def8",
	"on-secondary-container": "#1d192b",
	"tertiary": "#7d5260",
	"on-tertiary": "#ffffff",
	"tertiary-container": "#ffd8e4",
	"on-tertiary-container": "#31111d",
	"error": "#b3261e",
	"on-error": "#ffffff",
	"error-container": "#f9dedc",
	"on-error-container": "#410e0b",
	"background": "#fef7ff",
	"on-background": "#1d1b20",
	"surface": "#fef7ff",
	"on-surface": "#1d1b20",
	"surface-variant": "#e7e0ec",
	"on-surface-variant": "#49454f",
	"outline": "#79747e",
	"outline-variant": "#cac4d0",
	"surface-dim": "#ded8e1",
	"surface-bright": "#fef7ff",
	"surface-container-lowest": "#ffffff",
	"surface-container-low": "#f7f2fa",
	"surface-container": "#f3edf7",
	"surface-container-high": "#ece6f0",
	"surface-container-highest": "#e6e0e9",
	"inverse-surface": "#322f35",
	"inverse-on-surface": "#f5eff7",
	"inverse-primary": "#d0bcff",
	"surface-tint": "#6750a4",
	"shadow": "#000000",
	"scrim": "#000000",
	"status-success": "#3b6939",
	"on-status-success": "#ffffff",
	"status-success-container": "#bcf0b4",
	"on-status-success-container": "#002105",
	"status-warning": "#7a5900",
	"on-status-warning": "#ffffff",
	"status-warning-container": "#ffdf9e",
	"on-status-warning-container": "#271900",
	"status-info": "#00639b",
	"on-status-info": "#ffffff",
	"status-info-container": "#d0e4ff",
	"on-status-info-container": "#001d36",
}

const ROLES_DARK := {
	"primary": "#d0bcff",
	"on-primary": "#381e72",
	"primary-container": "#4f378b",
	"on-primary-container": "#eaddff",
	"secondary": "#ccc2dc",
	"on-secondary": "#332d41",
	"secondary-container": "#4a4458",
	"on-secondary-container": "#e8def8",
	"tertiary": "#efb8c8",
	"on-tertiary": "#492532",
	"tertiary-container": "#633b48",
	"on-tertiary-container": "#ffd8e4",
	"error": "#f2b8b5",
	"on-error": "#601410",
	"error-container": "#8c1d18",
	"on-error-container": "#f9dedc",
	"background": "#141218",
	"on-background": "#e6e0e9",
	"surface": "#141218",
	"on-surface": "#e6e0e9",
	"surface-variant": "#49454f",
	"on-surface-variant": "#cac4d0",
	"outline": "#938f99",
	"outline-variant": "#49454f",
	"surface-dim": "#141218",
	"surface-bright": "#3b383e",
	"surface-container-lowest": "#0f0d13",
	"surface-container-low": "#1d1b20",
	"surface-container": "#211f26",
	"surface-container-high": "#2b2930",
	"surface-container-highest": "#36343b",
	"inverse-surface": "#e6e0e9",
	"inverse-on-surface": "#322f35",
	"inverse-primary": "#6750a4",
	"surface-tint": "#d0bcff",
	"shadow": "#000000",
	"scrim": "#000000",
	"status-success": "#a1d39a",
	"on-status-success": "#003908",
	"status-success-container": "#215123",
	"on-status-success-container": "#bcf0b4",
	"status-warning": "#f2bf4a",
	"on-status-warning": "#412d00",
	"status-warning-container": "#5d4200",
	"on-status-warning-container": "#ffdf9e",
	"status-info": "#9ccaff",
	"on-status-info": "#003258",
	"status-info-container": "#004a77",
	"on-status-info-container": "#d0e4ff",
}

const ROLES_FIXED := {
	"primary-fixed": "#eaddff",
	"primary-fixed-dim": "#d0bcff",
	"on-primary-fixed": "#21005d",
	"on-primary-fixed-variant": "#4f378b",
	"secondary-fixed": "#e8def8",
	"secondary-fixed-dim": "#ccc2dc",
	"on-secondary-fixed": "#1d192b",
	"on-secondary-fixed-variant": "#4a4458",
	"tertiary-fixed": "#ffd8e4",
	"tertiary-fixed-dim": "#efb8c8",
	"on-tertiary-fixed": "#31111d",
	"on-tertiary-fixed-variant": "#633b48",
}

# --- Typography --------------------------------------------------------------
# Type scale in points: size, line height, weight, letter spacing in px.

const TYPESCALE := {
	"display-large": {"size": 57, "line_height": 64, "weight": 400, "tracking": -0.25},
	"display-medium": {"size": 45, "line_height": 52, "weight": 400, "tracking": 0.0},
	"display-small": {"size": 36, "line_height": 44, "weight": 400, "tracking": 0.0},
	"headline-large": {"size": 32, "line_height": 40, "weight": 400, "tracking": 0.0},
	"headline-medium": {"size": 28, "line_height": 36, "weight": 400, "tracking": 0.0},
	"headline-small": {"size": 24, "line_height": 32, "weight": 400, "tracking": 0.0},
	"title-large": {"size": 22, "line_height": 28, "weight": 400, "tracking": 0.0},
	"title-medium": {"size": 16, "line_height": 24, "weight": 500, "tracking": 0.15},
	"title-small": {"size": 14, "line_height": 20, "weight": 500, "tracking": 0.1},
	"body-large": {"size": 16, "line_height": 24, "weight": 400, "tracking": 0.5},
	"body-medium": {"size": 14, "line_height": 20, "weight": 400, "tracking": 0.25},
	"body-small": {"size": 12, "line_height": 16, "weight": 400, "tracking": 0.4},
	"label-large": {"size": 14, "line_height": 20, "weight": 500, "tracking": 0.1},
	"label-medium": {"size": 12, "line_height": 16, "weight": 500, "tracking": 0.5},
	"label-small": {"size": 11, "line_height": 16, "weight": 500, "tracking": 0.5},
}

# --- Shape -------------------------------------------------------------------

const CORNER := {
	"none": 0,
	"extra-small": 4,
	"small": 8,
	"medium": 12,
	"large": 16,
	"large-increased": 20,
	"extra-large": 28,
	"extra-large-increased": 32,
	"extra-extra-large": 48,
	"full": -1,  # fully rounded: radius is half of the smaller side
}

# --- Elevation ---------------------------------------------------------------
# Base levels in dp plus StyleBoxFlat shadow approximations (offset y, blur
# size, alpha).

const ELEVATION_LEVELS := {
	"level0": 0,
	"level1": 1,
	"level2": 3,
	"level3": 6,
	"level4": 8,
	"level5": 12,
}

const ELEVATION_SHADOW := {
	0: {"offset": 0, "size": 0, "alpha": 0.0},
	1: {"offset": 1, "size": 2, "alpha": 0.14},
	2: {"offset": 2, "size": 4, "alpha": 0.14},
	3: {"offset": 3, "size": 8, "alpha": 0.16},
	4: {"offset": 4, "size": 12, "alpha": 0.16},
	5: {"offset": 6, "size": 18, "alpha": 0.18},
}

# --- Interaction states ------------------------------------------------------

const STATE_OPACITY := {
	"hover": 0.08,
	"focus": 0.10,
	"pressed": 0.10,
	"dragged": 0.16,
}

const DISABLED_CONTENT_OPACITY := 0.38
const DISABLED_CONTAINER_OPACITY := 0.12
const FOCUS_RING_WIDTH := 2
const FOCUS_RING_OFFSET := 2

# --- Motion ------------------------------------------------------------------
# Durations in milliseconds; easings as cubic-bezier control points; springs
# follow the M3 Expressive naming ("spatial" for size/position changes,
# "effects" for color/opacity).

const DURATION_MS := {
	"short1": 50,
	"short2": 100,
	"short3": 150,
	"short4": 200,
	"medium1": 250,
	"medium2": 300,
	"medium3": 350,
	"medium4": 400,
	"long1": 450,
	"long2": 500,
	"long3": 550,
	"long4": 600,
	"extra-long1": 700,
	"extra-long2": 800,
	"extra-long3": 900,
	"extra-long4": 1000,
}

const EASING := {
	"standard": [0.2, 0.0, 0.0, 1.0],
	"standard-decelerate": [0.0, 0.0, 0.0, 1.0],
	"standard-accelerate": [0.3, 0.0, 1.0, 1.0],
	"emphasized": [0.2, 0.0, 0.0, 1.0],  # web fallback for the M3 curve
	"emphasized-decelerate": [0.05, 0.7, 0.1, 1.0],
	"emphasized-accelerate": [0.3, 0.0, 0.8, 0.15],
}

const SPRING := {
	"fast-spatial": {"bezier": [0.42, 1.67, 0.21, 0.9], "duration": 350},
	"default-spatial": {"bezier": [0.38, 1.21, 0.22, 1.0], "duration": 500},
	"slow-spatial": {"bezier": [0.39, 1.29, 0.35, 0.98], "duration": 650},
	"fast-effects": {"bezier": [0.31, 0.94, 0.34, 1.0], "duration": 150},
	"default-effects": {"bezier": [0.34, 0.80, 0.34, 1.0], "duration": 200},
	"slow-effects": {"bezier": [0.34, 0.88, 0.34, 1.0], "duration": 300},
}

# --- Spacing and target sizes ------------------------------------------------
# Spacing follows a 4dp rhythm. Targets: dock-focused controls vs
# dialog-accurate controls.

const SPACING := {"xs": 4, "s": 8, "m": 12, "l": 16, "xl": 24, "xxl": 32}
const TARGET_DOCK := 40
const TARGET_DIALOG := 48

# --- Fonts -------------------------------------------------------------------

static var _font_cache: Dictionary = {}

static func font_regular() -> Font:
	return _load_font(CopilotPaths.FONTS_REGULAR)

static func font_medium() -> Font:
	return _load_font(CopilotPaths.FONTS_MEDIUM)

static var _mono_font_cache: Font = null

static func font_mono() -> Font:
	# The editor's configured code font. Deliberately no EditorFonts theme
	# lookup: EditorTheme warns when its mono_font entry has an invalid Ref
	# during startup, so querying the theme would spam warnings.
	if _mono_font_cache != null:
		return _mono_font_cache
	var settings := EditorInterface.get_editor_settings()
	if settings != null:
		var configured: Variant = settings.get_setting("interface/editor/code_font")
		if configured is Font:
			_mono_font_cache = configured as Font
		elif configured is String and not (configured as String).is_empty() and ResourceLoader.exists(configured as String):
			_mono_font_cache = load(configured as String) as Font
	return _mono_font_cache

static func font_for_weight(weight: int) -> Font:
	var path: String = CopilotPaths.FONTS_MEDIUM if weight >= 500 else CopilotPaths.FONTS_REGULAR
	return _load_font(path)

static func apply_text(control: Control, style: String) -> void:
	# Applies font and size overrides for a type-scale style; controls whose
	# font override keys differ handle their own overrides.
	var font := font_for_weight(type_weight(style))
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", type_size(style))

# --- Token accessors ---------------------------------------------------------

static func type_size(style: String) -> int:
	return int(_type_entry(style).get("size", 14))

static func type_line_height(style: String) -> int:
	return int(_type_entry(style).get("line_height", 20))

static func type_weight(style: String) -> int:
	return int(_type_entry(style).get("weight", 400))

static func type_tracking(style: String) -> float:
	return float(_type_entry(style).get("tracking", 0.0))

static func corner_radius(shape: String, size: Vector2) -> int:
	var value: int = int(CORNER.get(shape, 0))
	if value < 0:
		return int(minf(size.x, size.y) * 0.5)
	return value

static func spacing(name: String) -> int:
	return int(SPACING.get(name, 0))

static func apply_shadow(sb: StyleBoxFlat, level: int) -> void:
	var cfg: Dictionary = ELEVATION_SHADOW.get(clampi(level, 0, 5), {})
	if cfg.is_empty():
		return
	sb.shadow_color = Color(0.0, 0.0, 0.0, float(cfg.get("alpha", 0.0)))
	sb.shadow_size = int(cfg.get("size", 0))
	sb.shadow_offset = Vector2(0.0, float(cfg.get("offset", 0)))

static func _load_font(path: String) -> Font:
	if _font_cache.has(path):
		return _font_cache[path] as Font
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path) as Font
	_font_cache[path] = font
	return font

static func _type_entry(style: String) -> Dictionary:
	if TYPESCALE.has(style):
		return TYPESCALE[style]
	return TYPESCALE["body-medium"]
