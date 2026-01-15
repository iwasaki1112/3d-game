class_name AnimationFallback
extends RefCounted

## アニメーションフォールバックヘルパー
## 複数の候補アニメーション名から存在するものを検索


## 候補リストから最初に見つかったアニメーション名を返す
## @param anim_player: AnimationPlayer
## @param candidates: アニメーション名の候補配列
## @param default: 見つからない場合のデフォルト値
## @return: 見つかったアニメーション名、なければデフォルト
static func find_animation(
	anim_player: AnimationPlayer,
	candidates: Array[String],
	default: String = ""
) -> String:
	for candidate in candidates:
		if anim_player.has_animation(candidate):
			return candidate
	return default


## 武器タイプとベース名からアニメーション名の候補リストを生成
## @param weapon_type_name: 武器タイプ名（"rifle", "pistol", "none"）
## @param base_name: ベースアニメーション名（"idle", "walking", etc.）
## @return: 候補アニメーション名の配列
static func get_weapon_anim_candidates(
	weapon_type_name: String,
	base_name: String
) -> Array[String]:
	var candidates: Array[String] = []

	# 武器タイプ付きアニメーション名を優先
	candidates.append("%s_%s" % [weapon_type_name, base_name])

	# フォールバック：rifle版
	if weapon_type_name != "rifle":
		candidates.append("rifle_%s" % base_name)

	# フォールバック：素のベース名
	candidates.append(base_name)

	# 最終フォールバック
	candidates.append("idle_none")

	return candidates


## 移動アニメーション名を取得（フォールバック付き）
## @param anim_player: AnimationPlayer
## @param weapon_type_name: 武器タイプ名
## @param locomotion_base: 移動状態の基本名（"idle", "walking", "sprint"）
## @return: アニメーション名
static func get_locomotion_animation(
	anim_player: AnimationPlayer,
	weapon_type_name: String,
	locomotion_base: String
) -> String:
	var candidates := get_weapon_anim_candidates(weapon_type_name, locomotion_base)

	# walking をフォールバックとして追加
	if locomotion_base != "walking":
		var walking_candidates := get_weapon_anim_candidates(weapon_type_name, "walking")
		for candidate in walking_candidates:
			if candidate not in candidates:
				candidates.append(candidate)

	return find_animation(anim_player, candidates, "idle_none")


## 射撃/エイミングアニメーション名を取得（フォールバック付き）
## @param anim_player: AnimationPlayer
## @param weapon_type_name: 武器タイプ名
## @return: アニメーション名
static func get_shoot_animation(
	anim_player: AnimationPlayer,
	weapon_type_name: String
) -> String:
	var candidates: Array[String] = [
		"%s_idle_aiming" % weapon_type_name,
		"%s_shoot" % weapon_type_name,
		"%s_walking" % weapon_type_name,
		"%s_idle" % weapon_type_name,
		"rifle_idle_aiming",
		"rifle_walking",
		"idle_none",
	]
	return find_animation(anim_player, candidates, "idle_none")


## 死亡アニメーション名を取得（フォールバック付き）
## @param anim_player: AnimationPlayer
## @param weapon_type_name: 武器タイプ名
## @return: アニメーション名（空文字列なら見つからない）
static func get_death_animation(
	anim_player: AnimationPlayer,
	weapon_type_name: String
) -> String:
	var candidates: Array[String] = [
		"%s_dying" % weapon_type_name,
		"%s_death" % weapon_type_name,
		"rifle_dying",
		"rifle_death",
		"dying",
		"death",
	]
	return find_animation(anim_player, candidates, "")
