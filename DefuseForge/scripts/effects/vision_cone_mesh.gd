class_name VisionConeMesh
extends MeshInstance3D

## 視界コーンメッシュ生成
## VisionComponentの結果を半透明メッシュとして描画

@export var cone_color: Color = Color(1.0, 0.9, 0.5, 0.15)  # 半透明の黄色
@export var cone_height: float = 0.05  # 地面からの高さ

var _array_mesh: ArrayMesh
var _material: StandardMaterial3D


func _ready() -> void:
	_setup_mesh()


func _setup_mesh() -> void:
	_array_mesh = ArrayMesh.new()
	mesh = _array_mesh

	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = cone_color
	_material.no_depth_test = true  # 常に表示
	material_override = _material


## ポリゴンからメッシュを生成
## @param polygon: VisionComponentからの視界ポリゴン（原点 + 外周点）
func update_from_polygon(polygon: PackedVector3Array) -> void:
	# 初期化されていない場合はセットアップ
	if _array_mesh == null:
		_setup_mesh()

	if polygon.size() < 3:
		_array_mesh.clear_surfaces()
		return

	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()

	var origin = polygon[0]
	# 原点を地面レベルに投影
	var origin_flat = Vector3(origin.x, cone_height, origin.z)

	# 全頂点を地面レベルに投影して追加
	vertices.append(origin_flat)
	for i in range(1, polygon.size()):
		var p = polygon[i]
		vertices.append(Vector3(p.x, cone_height, p.z))

	# 三角形ファンでインデックスを生成
	for i in range(1, polygon.size() - 1):
		indices.append(0)      # 原点
		indices.append(i)      # 現在の点
		indices.append(i + 1)  # 次の点

	# 最後の三角形（最後の点と最初の外周点を結ぶ）
	if polygon.size() > 2:
		indices.append(0)
		indices.append(polygon.size() - 1)
		indices.append(1)

	# メッシュを構築
	_array_mesh.clear_surfaces()

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_array_mesh.surface_set_material(0, _material)


## 色を設定
func set_cone_color(color: Color) -> void:
	cone_color = color
	if _material:
		_material.albedo_color = cone_color


## 表示/非表示を切り替え
func set_visible_cone(cone_visible: bool) -> void:
	visible = cone_visible
