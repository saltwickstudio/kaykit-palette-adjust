@tool
class_name PaletteAdjustMaterial
extends ShaderMaterial
## per swatch colour tweaks for KayKit models
## KayKit by Kay Lousberg - https://kaylousberg.com

const SHADER_FILE := "palette_adjust.gdshader"
const MAX_SLOTS := 64

# xyzw order
const COLOR_SETTINGS: Array[String] = ["hue", "saturation", "contrast", "brightness"]
const SURFACE_SETTINGS: Array[String] = ["metallic", "roughness", "emission"]

const SLIDER_RANGES := {
	"hue": "-0.5,0.5,0.01",
	"saturation": "-1,1,0.01",
	"contrast": "-1,1,0.01",
	"brightness": "-1,1,0.01",
	"metallic": "-1,1,0.01",
	"roughness": "-1,1,0.01",
	"emission": "0,8,0.01,or_greater",
}


@export var palette_texture: Texture2D:
	set(value):
		palette_texture = value
		set_shader_parameter("palette_texture", value)
		_swatch_colors.clear()
		notify_property_list_changed()

## KayKit is 8 x 4
@export_range(1, 16) var columns: int = 8:
	set(value):
		columns = value
		_on_grid_changed()

@export_range(1, 16) var rows: int = 4:
	set(value):
		rows = value
		_on_grid_changed()

## slot metallic/roughness get added on to these
@export_range(0.0, 1.0, 0.01) var base_metallic: float = 0.0:
	set(value):
		base_metallic = value
		set_shader_parameter("base_metallic", value)

@export_range(0.0, 1.0, 0.01) var base_roughness: float = 0.5:
	set(value):
		base_roughness = value
		set_shader_parameter("base_roughness", value)

@export var show_all_slots: bool = false:
	set(value):
		show_all_slots = value
		notify_property_list_changed()

## select the mesh using this material first
@export_tool_button("Detect Slots Used By Selected Mesh", "Search")
var detect_slots_button := _on_detect_slots_pressed


# matches shader uniforms
@export_storage var color_changes := PackedVector4Array():
	set(value):
		color_changes = value
		color_changes.resize(MAX_SLOTS)
		set_shader_parameter("color_changes", color_changes)

@export_storage var surface_changes := PackedVector4Array():
	set(value):
		surface_changes = value
		surface_changes.resize(MAX_SLOTS)
		set_shader_parameter("surface_changes", surface_changes)

@export_storage var emission_colors := PackedColorArray():
	set(value):
		emission_colors = value
		while emission_colors.size() < MAX_SLOTS:
			emission_colors.append(Color.WHITE)
		set_shader_parameter("emission_colors", emission_colors)

@export_storage var used_slots := PackedInt32Array()

var _swatch_colors := PackedColorArray()


func _init() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	shader = load(folder.path_join(SHADER_FILE))

	# push defaults to shader
	color_changes = color_changes
	surface_changes = surface_changes
	emission_colors = emission_colors
	base_metallic = base_metallic
	base_roughness = base_roughness
	columns = columns


func slot_count() -> int:
	return mini(columns * rows, MAX_SLOTS)


## 0 based
func find_slots_used_by(mesh: Mesh) -> PackedInt32Array:
	var slots := {}
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var corner_count := indices.size() if not indices.is_empty() else uvs.size()

		# tri centre
		for first_corner in range(0, corner_count - 2, 3):
			var middle := Vector2.ZERO
			for corner in range(first_corner, first_corner + 3):
				var vertex: int = indices[corner] if not indices.is_empty() else corner
				middle += uvs[vertex] / 3.0
			slots[_slot_at(middle)] = true

	var sorted := slots.keys()
	sorted.sort()
	return PackedInt32Array(sorted)


func _slot_at(uv: Vector2) -> int:
	uv = uv.clamp(Vector2.ZERO, Vector2(0.9999, 0.9999))
	return int(uv.y * rows) * columns + int(uv.x * columns)


func _on_grid_changed() -> void:
	set_shader_parameter("columns", columns)
	set_shader_parameter("rows", rows)
	_swatch_colors.clear()
	used_slots.clear()
	notify_property_list_changed()


func _on_detect_slots_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	# not in exports
	var editor := Engine.get_singleton("EditorInterface")

	var found := {}
	for node: Node in editor.get_selection().get_selected_nodes():
		var mesh_instance := node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			for slot in find_slots_used_by(mesh_instance.mesh):
				found[slot] = true

	if found.is_empty():
		push_warning("Palette Adjust: select the MeshInstance3D that uses this material first.")
		return

	var sorted := found.keys()
	sorted.sort()
	used_slots = PackedInt32Array(sorted)
	notify_property_list_changed()


func _swatch_color(slot: int) -> Color:
	if _swatch_colors.is_empty() and palette_texture:
		var image := palette_texture.get_image()
		if image:
			if image.is_compressed():
				image.decompress()
			var cell_size := Vector2(image.get_size()) / Vector2(columns, rows)
			for i in slot_count():
				var cell := Vector2(i % columns, i / columns)
				var middle := Vector2i((cell + Vector2(0.5, 0.5)) * cell_size)
				_swatch_colors.append(image.get_pixelv(middle))
	return _swatch_colors[slot] if slot < _swatch_colors.size() else Color.BLACK


# --- inspector ---

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for slot in slot_count():
		var is_used := used_slots.has(slot)
		var hide_unused := not show_all_slots and not used_slots.is_empty()
		if hide_unused and not is_used:
			continue

		var prefix := "slot_%d/" % (slot + 1)
		var title := "Slot %d" % (slot + 1)
		if is_used:
			title += "  (used)"
		properties.append({
			"name": title, "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": prefix,
		})
		properties.append({
			"name": prefix + "swatch", "type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
		})
		for setting in COLOR_SETTINGS + SURFACE_SETTINGS:
			properties.append({
				"name": prefix + setting, "type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_EDITOR,
				"hint": PROPERTY_HINT_RANGE, "hint_string": SLIDER_RANGES[setting],
			})
		properties.append({
			"name": prefix + "emission_color", "type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_EDITOR, "hint": PROPERTY_HINT_COLOR_NO_ALPHA,
		})
	return properties


func _get(property: StringName) -> Variant:
	var target := SlotProperty.parse(property)
	if target == null:
		return null

	if target.setting == "swatch":
		return _swatch_color(target.slot)
	if target.setting == "emission_color":
		return emission_colors[target.slot]
	if target.setting in COLOR_SETTINGS:
		return color_changes[target.slot][COLOR_SETTINGS.find(target.setting)]
	return surface_changes[target.slot][SURFACE_SETTINGS.find(target.setting)]


func _set(property: StringName, value: Variant) -> bool:
	var target := SlotProperty.parse(property)
	if target == null or target.setting == "swatch":
		return false

	var slot := target.slot
	if target.setting == "emission_color":
		emission_colors[slot] = value
		emission_colors = emission_colors
	elif target.setting in COLOR_SETTINGS:
		color_changes[slot][COLOR_SETTINGS.find(target.setting)] = value
		color_changes = color_changes
	else:
		surface_changes[slot][SURFACE_SETTINGS.find(target.setting)] = value
		surface_changes = surface_changes
	emit_changed()
	return true


func _property_can_revert(property: StringName) -> bool:
	var target := SlotProperty.parse(property)
	return target != null and target.setting != "swatch"


func _property_get_revert(property: StringName) -> Variant:
	if String(property).ends_with("/emission_color"):
		return Color.WHITE
	return 0.0


# "slot_6/hue" -> slot 5, "hue"
class SlotProperty:
	const ALL_SETTINGS: Array[String] = [
		"swatch", "hue", "saturation", "contrast", "brightness",
		"metallic", "roughness", "emission", "emission_color",
	]

	var slot: int
	var setting: String

	static func parse(property: StringName) -> SlotProperty:
		var parts := String(property).trim_prefix("slot_").split("/")
		if not String(property).begins_with("slot_") or parts.size() != 2:
			return null
		if not parts[0].is_valid_int() or parts[1] not in ALL_SETTINGS:
			return null

		var slot_number := parts[0].to_int()
		if slot_number < 1 or slot_number > MAX_SLOTS:
			return null

		var result := SlotProperty.new()
		result.slot = slot_number - 1
		result.setting = parts[1]
		return result
