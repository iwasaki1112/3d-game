class_name MovementMarker
extends MeshInstance3D

## キャラクター移動時に足元に表示するリングマーカー
## 移動中のみ表示され、停止すると非表示になる

@export var ring_radius: float = 0.4  ## リングの半径
@export var ring_thickness: float = 0.03  ## リングの太さ
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.9)  ## リングの色
@export var height_offset: float = 0.02  ## 地面からの高さ
@export var segments: int = 32  ## リングのセグメント数

var _array_mesh: ArrayMesh
var _material: StandardMaterial3D
var _is_visible: bool = false


func _ready() -> void:
	_setup_mesh()
	hide()


func _setup_mesh() -> void:
	_array_mesh = ArrayMesh.new()
	mesh = _array_mesh

	# 発光マテリアル
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = ring_color
	_material.emission_enabled = true
	_material.emission = ring_color
	_material.emission_energy_multiplier = 1.5
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material

	_build_ring_mesh()


func _build_ring_mesh() -> void:
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()

	var inner_radius = ring_radius - ring_thickness
	var outer_radius = ring_radius

	# 内外周の頂点を生成
	for i in range(segments):
		var angle = TAU * i / segments
		var cos_a = cos(angle)
		var sin_a = sin(angle)

		# 内周
		vertices.append(Vector3(
			cos_a * inner_radius,
			0,
			sin_a * inner_radius
		))
		# 外周
		vertices.append(Vector3(
			cos_a * outer_radius,
			0,
			sin_a * outer_radius
		))

	# 三角形でリングを描画
	for i in range(segments):
		var curr_inner = i * 2
		var curr_outer = i * 2 + 1
		var next_inner = ((i + 1) % segments) * 2
		var next_outer = ((i + 1) % segments) * 2 + 1

		# 2三角形で四角形
		indices.append(curr_inner)
		indices.append(curr_outer)
		indices.append(next_inner)
		indices.append(curr_outer)
		indices.append(next_outer)
		indices.append(next_inner)

	# メッシュを構築
	_array_mesh.clear_surfaces()

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_array_mesh.surface_set_material(0, _material)


## マーカーを表示
func show_marker() -> void:
	if _is_visible:
		return
	_is_visible = true
	show()


## マーカーを非表示
func hide_marker() -> void:
	if not _is_visible:
		return
	_is_visible = false
	hide()


## マーカーの位置を更新（キャラクターの足元に配置）
func update_position(character_position: Vector3) -> void:
	global_position = Vector3(
		character_position.x,
		height_offset,
		character_position.z
	)


## 色を変更
func set_ring_color(color: Color) -> void:
	ring_color = color
	if _material:
		_material.albedo_color = color
		_material.emission = color
