extends Node2D
class_name InfiniteMapManager

signal chunk_created(chunk: Node2D, chunk_x_index: int)
signal chunk_destroyed(chunk: Node2D, chunk_x_index: int)

## ------------------------------------------------------------------
## EXPORT DEĞİŞKENLERİ
## ------------------------------------------------------------------
@export var player: NodePath
@export var chunk_width: float = 3840.0   
@export var map_scale: float = 3.0        
@export var ocean_height_multiplier: float = 2.0 
@export var surface_offset_y: float = 120.0 # Çizgiyi aşağı kaydırmak için piksel ayarı (Inspector'dan oynayabilirsin)
@export var sky_texture: Texture2D
@export var ocean_textures: Array[Texture2D] = []
@export var ground_texture: Texture2D
@export var safety_buffer_chunks: int = 2

## ------------------------------------------------------------------
## INTERNAL STATE
## ------------------------------------------------------------------
@onready var _player_node: Node2D = get_node_or_null(player) as Node2D
@export var _active_chunks: Dictionary = {}
var _bottom_y: float = 0.0

# lvl0'ın sonu + offset (Gerçek Su Yüzeyi Y Koordinatı)
static var water_surface_y: float = 0.0


func _ready() -> void:
	if sky_texture == null or ground_texture == null or ocean_textures.is_empty():
		push_error("InfiniteMapManager: Eksik texture tanımlamaları var!")
		return

	_calculate_map_dimensions()
	_setup_static_collisions()
	_update_chunks()


func _process(_delta: float) -> void:
	if chunk_width <= 0.0:
		return
	_update_chunks()


## ------------------------------------------------------------------
## HARİTA BOYUTLARI VE YÜZEY HESABI
## ------------------------------------------------------------------
func _calculate_map_dimensions() -> void:
	if ocean_textures.size() > 0 and ocean_textures[0]:
		var lvl0_height = ocean_textures[0].get_height() * map_scale * ocean_height_multiplier
		# Çizgiyi istediğin kadar aşağı çekmek için offset ekledik
		water_surface_y = lvl0_height + surface_offset_y

	var total_ocean_height := 0.0
	for i in range(ocean_textures.size()):
		var tex = ocean_textures[i]
		if tex:
			var depth_scaling = 1.0 + (float(i) * 0.35)
			total_ocean_height += tex.get_height() * map_scale * ocean_height_multiplier * depth_scaling

	var ground_height: float = float(ground_texture.get_height()) * map_scale if ground_texture else 0.0
	_bottom_y = total_ocean_height + ground_height


func generate_chunk(chunk_x_index: int) -> Node2D:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d" % chunk_x_index
	chunk.position = Vector2(chunk_x_index * chunk_width, 0.0)
	add_child(chunk)

	var create_stretched_sprite = func(tex: Texture2D, y_pos: float, target_height: float) -> Sprite2D:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		var scale_x = chunk_width / tex.get_width()
		var scale_y = target_height / tex.get_height()
		sprite.scale = Vector2(scale_x, scale_y)
		sprite.position = Vector2(0.0, y_pos)
		return sprite

	# 1. Gökyüzü (Sky)
	var sky_h = sky_texture.get_height() * map_scale
	var sky_sprite = create_stretched_sprite.call(sky_texture, -sky_h, sky_h)
	chunk.add_child(sky_sprite)

	# 2. Okyanus Katmanları
	var y_cursor := 0.0
	var chunk_layers_meta: Array = []

	for i in range(ocean_textures.size()):
		var tex = ocean_textures[i]
		if tex == null:
			continue
		
		var depth_scaling = 1.0 + (float(i) * 0.35)
		var layer_height = tex.get_height() * map_scale * ocean_height_multiplier * depth_scaling
		
		var ocean_sprite = create_stretched_sprite.call(tex, y_cursor, layer_height)
		chunk.add_child(ocean_sprite)

		var world_min_y = chunk.position.y + y_cursor
		var world_max_y = world_min_y + layer_height
		
		chunk_layers_meta.append({
			"layer_index": i,
			"min_y": world_min_y,
			"max_y": world_max_y
		})

		y_cursor += layer_height

	chunk.set_meta("layer_bounds", chunk_layers_meta)

	# 3. Zemin
	var ground_h = ground_texture.get_height() * map_scale
	var ground_sprite = create_stretched_sprite.call(ground_texture, y_cursor, ground_h)
	chunk.add_child(ground_sprite)

	emit_signal("chunk_created", chunk, chunk_x_index)
	return chunk


func _update_chunks() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var screen_size = get_viewport().get_visible_rect().size
	var cam_pos = cam.global_position

	# Chunk simülasyon zarfı: Kameranın anlık zoom'u ne olursa olsun,
	# maksimum gözlük unzoom'u (0.08) referans alınır.
	# Böylece oyuncu zoom in/out yaptığında chunk'lar asla silinip yeniden üretilmez.
	const MAX_UNZOOM_REF: float = 0.08
	var sim_zoom: float = min(cam.zoom.x, MAX_UNZOOM_REF) if cam.zoom.x > 0.0 else MAX_UNZOOM_REF
	var half_screen_w: float = (screen_size.x * 0.5) / sim_zoom
	var min_visible_x: float = cam_pos.x - half_screen_w
	var max_visible_x: float = cam_pos.x + half_screen_w

	var min_chunk_idx: int = int(floor((min_visible_x - (chunk_width * safety_buffer_chunks)) / chunk_width))
	var max_chunk_idx: int = int(floor((max_visible_x + (chunk_width * safety_buffer_chunks)) / chunk_width))

	var needed_indices: Dictionary = {}
	for i in range(min_chunk_idx, max_chunk_idx + 1):
		needed_indices[i] = true
		if not _active_chunks.has(i):
			_active_chunks[i] = generate_chunk(i)

	var keys_to_remove: Array = []
	for existing_index in _active_chunks.keys():
		if not needed_indices.has(existing_index):
			keys_to_remove.append(existing_index)

	for key in keys_to_remove:
		var chunk_node: Node2D = _active_chunks[key]
		if is_instance_valid(chunk_node):
			emit_signal("chunk_destroyed", chunk_node, int(key))
			chunk_node.queue_free()
		_active_chunks.erase(key)


func _setup_static_collisions() -> void:
	var static_body := StaticBody2D.new()
	static_body.name = "WorldBounds"
	add_child(static_body)

	var floor_shape := WorldBoundaryShape2D.new()
	floor_shape.normal = Vector2.UP
	floor_shape.distance = -_bottom_y
	var floor_collision := CollisionShape2D.new()
	floor_collision.shape = floor_shape
	static_body.add_child(floor_collision)
