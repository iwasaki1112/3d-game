class_name BoneNameRegistry
extends RefCounted

## 骨名レジストリ
## 複数のスケルトン規約（Humanoid、ARP、Blender Rigify等）をサポート

## 右手骨名の候補リスト
const RIGHT_HAND_BONES: Array[String] = [
	"RightHand",      # Humanoid/Mixamo
	"c_hand_ik.r",    # Auto-Rig Pro IK
	"hand.r",         # Blender Rigify
	"c_hand_fk.r",    # Auto-Rig Pro FK
	"Hand.R",         # Unity Humanoid
]

## 左手骨名の候補リスト
const LEFT_HAND_BONES: Array[String] = [
	"LeftHand",       # Humanoid/Mixamo
	"hand.l",         # Blender Rigify
	"c_hand_ik.l",    # Auto-Rig Pro IK
	"c_hand_fk.l",    # Auto-Rig Pro FK
	"Hand.L",         # Unity Humanoid
]

## 左上腕（IKルート）骨名の候補リスト
const LEFT_UPPER_ARM_BONES: Array[String] = [
	"LeftUpperArm",   # Humanoid/Mixamo
	"arm.l",          # Blender Rigify
	"upperarm.l",     # Blender alternative
	"arm_stretch.l",  # Auto-Rig Pro
	"c_arm_ik.l",     # Auto-Rig Pro IK
	"shoulder.l",     # Fallback
	"UpperArm.L",     # Unity Humanoid
]

## 上半身骨のキーワード（大文字小文字区別なし）
const UPPER_BODY_KEYWORDS: Array[String] = [
	"spine",
	"neck",
	"head",
	"shoulder",
	"arm",
	"hand",
	"thumb",
	"index",
	"middle",
	"ring",
	"pinky",
]

## スパイン骨のキーワード
const SPINE_KEYWORDS: Array[String] = [
	"spine",
	"chest",
]


## 骨名候補リストからスケルトン内の骨を検索
## @param skeleton: 検索対象のスケルトン
## @param candidates: 骨名候補の配列
## @return: 見つかった骨のインデックス、見つからない場合は-1
static func find_bone(skeleton: Skeleton3D, candidates: Array[String]) -> int:
	for bone_name in candidates:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			return idx
	return -1


## 骨名候補リストからスケルトン内の骨名を検索
## @param skeleton: 検索対象のスケルトン
## @param candidates: 骨名候補の配列
## @return: 見つかった骨名、見つからない場合は空文字列
static func find_bone_name(skeleton: Skeleton3D, candidates: Array[String]) -> String:
	for bone_name in candidates:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			return bone_name
	return ""


## スケルトンから右手骨のインデックスを検索
## @param skeleton: 検索対象のスケルトン
## @return: 骨のインデックス、見つからない場合は-1
static func find_right_hand_bone(skeleton: Skeleton3D) -> int:
	return find_bone(skeleton, RIGHT_HAND_BONES)


## スケルトンから左手骨のインデックスを検索
## @param skeleton: 検索対象のスケルトン
## @return: 骨のインデックス、見つからない場合は-1
static func find_left_hand_bone(skeleton: Skeleton3D) -> int:
	return find_bone(skeleton, LEFT_HAND_BONES)


## スケルトンから左手骨名を検索
## @param skeleton: 検索対象のスケルトン
## @return: 骨名、見つからない場合は空文字列
static func find_left_hand_bone_name(skeleton: Skeleton3D) -> String:
	return find_bone_name(skeleton, LEFT_HAND_BONES)


## スケルトンから左上腕骨名を検索
## @param skeleton: 検索対象のスケルトン
## @return: 骨名、見つからない場合は空文字列
static func find_left_upper_arm_bone_name(skeleton: Skeleton3D) -> String:
	return find_bone_name(skeleton, LEFT_UPPER_ARM_BONES)


## 骨名が上半身に属するかどうかを判定
## @param bone_name: 骨名
## @return: 上半身の骨ならtrue
static func is_upper_body_bone(bone_name: String) -> bool:
	var lower_name := bone_name.to_lower()
	for keyword in UPPER_BODY_KEYWORDS:
		if keyword in lower_name:
			return true
	return false


## スケルトンから上半身骨名のリストを取得
## @param skeleton: 検索対象のスケルトン
## @return: 上半身骨名の配列
static func get_upper_body_bones(skeleton: Skeleton3D) -> Array[String]:
	var bones: Array[String] = []
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		if is_upper_body_bone(bone_name):
			bones.append(bone_name)
	return bones


## 骨名がスパイン系に属するかどうかを判定
## @param bone_name: 骨名
## @return: スパイン系の骨ならtrue
static func is_spine_bone(bone_name: String) -> bool:
	var lower_name := bone_name.to_lower()
	for keyword in SPINE_KEYWORDS:
		if keyword in lower_name:
			return true
	return false
