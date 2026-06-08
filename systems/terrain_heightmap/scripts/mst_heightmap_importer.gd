@tool
extends Node
class_name MSTHeightmapImporter

## Bakes a grayscale heightmap image into a MarchingSquaresTerrain by tiling it
## across a grid of chunks. Add this node anywhere in the scene, assign the
## terrain + image in the inspector, then press "Import Heightmap".
##
## A 256x256 image with the default 33-sample chunks maps cleanly onto an 8x8
## chunk grid (8 * 32 + 1 = 257 samples per axis ~= 1 pixel per height sample).

enum Channel { RED, GREEN, BLUE, LUMINANCE }

## The terrain node the heightmap will be baked into.
@export var terrain: MarchingSquaresTerrain

## Grayscale heightmap. Black = lowest, white = highest (unless Invert is on).
@export var heightmap: Texture2D

## How many chunks to tile per axis. 8 matches a 256px image at default chunk
## resolution. Total height samples per axis = chunks * (dimensions - 1) + 1.
@export_range(1, 64, 1) var chunks_per_axis: int = 8

## World-space height that a fully white (1.0) pixel maps to (after normalization).
@export var max_height: float = 64.0

## Stretch the image's actual darkest..brightest pixels to the full 0..1 range
## before scaling. Essential for low-contrast maps that only use a narrow band
## of brightness (otherwise the terrain looks flat).
@export var normalize_contrast: bool = true

## Shapes the height response. 1.0 = linear. >1 pushes detail toward the peaks
## (flatter valleys, sharper mountains); <1 lifts the low ground.
@export_range(0.1, 4.0, 0.05) var height_gamma: float = 1.0

## Quantizes heights into discrete steps (in world units) for crisp pixel-art
## blocks. Set to 0 to disable banding and keep continuous heights.
@export var height_step: float = 2.0

## Which image channel to read the height from.
@export var channel: Channel = Channel.RED

## Flip the mapping so white becomes low and black becomes high.
@export var invert: bool = false

## Force CUBIC merge mode so every height difference becomes a hard vertical
## block wall (best for stepped pixel-art terrain).
@export var force_cubic_blocks: bool = true

## Generate grass on the terrain. Turn off for bare terrain.
@export var generate_grass: bool = true

## Grass density per cell (only applied when Generate Grass is on).
@export_range(0, 8, 1) var grass_subdivisions: int = 3

## Remove any existing chunks before importing.
@export var clear_existing_chunks: bool = true

## Paint ground vertex colors after import. The height brush does this automatically;
## without it every surface (including vertical walls) uses the same default texture.
@export var apply_ground_texture: bool = true

## Ground texture slot (0-15). 0 = Texture 1 (grass) in the MST editor.
@export_range(0, 15, 1) var ground_texture_slot: int = 0

## Paint wall vertex colors after import, matching the terrain brush's side texture.
@export var apply_wall_texture: bool = true

## Wall/side texture slot (0-15). -1 uses MarchingSquaresTerrain.default_wall_texture.
@export_range(-1, 15, 1) var wall_texture_slot: int = -1

@export_tool_button("Import Heightmap") var _import_action = import_heightmap

var _value_min: float = 0.0
var _value_max: float = 1.0


func import_heightmap() -> void:
	if not _validate():
		return

	var image := heightmap.get_image()
	if image == null:
		push_error("[MSTHeightmapImporter] Could not read image from heightmap texture.")
		return
	if image.is_compressed():
		image.decompress()

	var dims: Vector3i = terrain.dimensions
	var samples_x: int = chunks_per_axis * (dims.x - 1) + 1
	var samples_z: int = chunks_per_axis * (dims.z - 1) + 1

	if clear_existing_chunks:
		_clear_chunks()

	var img_w: int = image.get_width()
	var img_h: int = image.get_height()

	_compute_value_range(image)

	for cz in range(chunks_per_axis):
		for cx in range(chunks_per_axis):
			var chunk := _create_chunk(Vector2i(cx, cz))

			for z in range(dims.z):
				var gz: int = cz * (dims.z - 1) + z
				var pz: int = _sample_to_pixel(gz, samples_z, img_h)
				for x in range(dims.x):
					var gx: int = cx * (dims.x - 1) + x
					var px: int = _sample_to_pixel(gx, samples_x, img_w)
					chunk.height_map[z][x] = _height_from_pixel(image.get_pixel(px, pz))

			if apply_ground_texture or apply_wall_texture:
				_apply_texture_maps(chunk)

			chunk.regenerate_all_cells(false)

	# Applied after chunks exist so the terrain setter updates every grass planter
	# (0 subdivisions = no grass). Persists because it is stored terrain data.
	terrain.grass_subdivisions = grass_subdivisions if generate_grass else 0

	print("[MSTHeightmapImporter] Imported '%s' into %d chunks (%dx%d samples). Source brightness range: %.2f..%.2f" % [
		heightmap.resource_path, chunks_per_axis * chunks_per_axis, samples_x, samples_z, _value_min, _value_max
	])


func _validate() -> bool:
	if terrain == null:
		push_error("[MSTHeightmapImporter] No terrain assigned.")
		return false
	if heightmap == null:
		push_error("[MSTHeightmapImporter] No heightmap texture assigned.")
		return false
	if not terrain.is_inside_tree():
		push_error("[MSTHeightmapImporter] Terrain must be inside the scene tree.")
		return false
	return true


func _create_chunk(coords: Vector2i) -> MarchingSquaresTerrainChunk:
	var chunk := MarchingSquaresTerrainChunk.new()
	chunk.name = "Chunk (%d, %d)" % [coords.x, coords.y]
	chunk.terrain_system = terrain
	if force_cubic_blocks:
		chunk.merge_mode = MarchingSquaresTerrainChunk.Mode.CUBIC
		chunk.merge_threshold = MarchingSquaresTerrainChunk.MERGE_MODE[MarchingSquaresTerrainChunk.Mode.CUBIC]
	chunk.mark_dirty()
	# regenerate_mesh = false: we fill the height map ourselves, then regenerate once.
	terrain.add_chunk(coords, chunk, null, false)
	return chunk


func _clear_chunks() -> void:
	var to_remove: Array[Node] = []
	for child in terrain.get_children():
		if child is MarchingSquaresTerrainChunk:
			to_remove.append(child)
	for child in to_remove:
		terrain.chunks.erase((child as MarchingSquaresTerrainChunk).chunk_coords)
		child.free()


func _sample_to_pixel(global_sample: int, total_samples: int, image_size: int) -> int:
	if total_samples <= 1:
		return 0
	var u: float = float(global_sample) / float(total_samples - 1)
	return clampi(int(round(u * (image_size - 1))), 0, image_size - 1)


func _channel_value(c: Color) -> float:
	match channel:
		Channel.RED:
			return c.r
		Channel.GREEN:
			return c.g
		Channel.BLUE:
			return c.b
		Channel.LUMINANCE:
			return (c.r + c.g + c.b) / 3.0
		_:
			return c.r


## Scan the whole image to find the darkest and brightest values for the chosen
## channel, so normalization can stretch them to the full 0..1 range.
func _compute_value_range(image: Image) -> void:
	_value_min = 1.0
	_value_max = 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var v: float = _channel_value(image.get_pixel(x, y))
			_value_min = minf(_value_min, v)
			_value_max = maxf(_value_max, v)
	if _value_max <= _value_min:
		_value_min = 0.0
		_value_max = 1.0


func _apply_texture_maps(chunk: MarchingSquaresTerrainChunk) -> void:
	if not chunk.color_map_0 or not chunk.color_map_1:
		chunk.generate_color_maps()
	if not chunk.wall_color_map_0 or not chunk.wall_color_map_1:
		chunk.generate_wall_color_maps()

	if apply_ground_texture:
		var ground_colors: Array = MSTDataHandler._texture_idx_to_colors(ground_texture_slot)
		var ground_c0: Color = ground_colors[0]
		var ground_c1: Color = ground_colors[1]
		for z in range(chunk.dimensions.z):
			for x in range(chunk.dimensions.x):
				var idx: int = z * chunk.dimensions.x + x
				chunk.color_map_0[idx] = ground_c0
				chunk.color_map_1[idx] = ground_c1

	if apply_wall_texture:
		var wall_slot: int = wall_texture_slot if wall_texture_slot >= 0 else terrain.default_wall_texture
		var wall_colors: Array = MSTDataHandler._texture_idx_to_colors(wall_slot)
		var wall_c0: Color = wall_colors[0]
		var wall_c1: Color = wall_colors[1]
		for z in range(chunk.dimensions.z):
			for x in range(chunk.dimensions.x):
				var idx: int = z * chunk.dimensions.x + x
				chunk.wall_color_map_0[idx] = wall_c0
				chunk.wall_color_map_1[idx] = wall_c1

	chunk.mark_dirty()


func _height_from_pixel(c: Color) -> float:
	var value: float = _channel_value(c)

	if normalize_contrast:
		value = (value - _value_min) / (_value_max - _value_min)

	if invert:
		value = 1.0 - value

	if height_gamma != 1.0:
		value = pow(clampf(value, 0.0, 1.0), height_gamma)

	var height: float = value * max_height
	if height_step > 0.0:
		height = round(height / height_step) * height_step
	return height
