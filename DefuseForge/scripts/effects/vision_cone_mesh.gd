class_name VisionConeMesh
extends MeshInstance3D

## 視界コーンメッシュ生成
## フォグの「穴」として描画し、視界内をクリアにする

@export var cone_height: float = 0.15  # フォグより少し上に配置

var _array_mesh: ArrayMesh
var _material: ShaderMaterial


func _ready() -> void:
	_setup_mesh()


func _setup_mesh() -> void:
	_array_mesh = ArrayMesh.new()
	mesh = _array_mesh

	# フォグを「消す」シェーダー
	var shader_code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
"""
	var shader = Shader.new()
	shader.code = shader_code

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.render_priority = 1  # フォグより後に描画
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

	# 三角形ファンでインデックスを生成（扇形なので閉じない）
	for i in range(1, polygon.size() - 1):
		indices.append(0)      # 原点
		indices.append(i)      # 現在の点
		indices.append(i + 1)  # 次の点

	# メッシュを構築
	_array_mesh.clear_surfaces()

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_array_mesh.surface_set_material(0, _material)
