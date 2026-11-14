class_name RigMeshBuilder
extends RefCounted
## Builds the players' body parts (look only): a few low-poly primitive shapes (cylinders, spheres,
## capsules) merged into one mesh per limb and colored per vertex, so every player shares a single
## material and a whole body costs about ten draw calls on the phone.
## The primitives keep their own triangle winding and normals; transforms never mirror them.

static var _material: StandardMaterial3D


## The one material of every body mesh: the color comes from the vertices.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = float(Config.get_value("body", "roughness", 0.8))
	return _material


## parts: Array of [PrimitiveMesh, Transform3D, Color]. Returns one mesh, or null if empty.
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var shape: PrimitiveMesh = part[0]
		var xform: Transform3D = part[1]
		var color: Color = part[2]
		var shape_arrays := shape.get_mesh_arrays()
		var shape_verts: PackedVector3Array = shape_arrays[Mesh.ARRAY_VERTEX]
		var shape_normals: PackedVector3Array = shape_arrays[Mesh.ARRAY_NORMAL]
		var shape_indices: PackedInt32Array = shape_arrays[Mesh.ARRAY_INDEX]
		var normal_basis := xform.basis.inverse().transposed()
		var base := verts.size()
		for i in range(shape_verts.size()):
			verts.append(xform * shape_verts[i])
			normals.append((normal_basis * shape_normals[i]).normalized())
			colors.append(color)
		if shape_indices.is_empty():
			for i in range(shape_verts.size()):
				indices.append(base + i)
		else:
			for index in shape_indices:
				indices.append(base + index)
	if verts.is_empty():
		return null
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_COLOR] = colors
	surface[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	mesh.surface_set_material(0, material())
	return mesh


## A tapered cylinder along Y, centered (from -height/2 to +height/2).
static func cylinder(top_radius: float, bottom_radius: float, height: float, caps: bool = true) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = _segments()
	m.rings = 0
	m.cap_top = caps
	m.cap_bottom = caps
	return m


## A sphere (or an ellipsoid when height != 2 * radius), centered.
static func sphere(radius: float, height: float = -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height if height > 0.0 else radius * 2.0
	m.radial_segments = _segments()
	m.rings = _rings()
	return m


## A dome from y = 0 (flat side) up to y = height.
static func dome(radius: float, height: float) -> SphereMesh:
	var m := sphere(radius, height)
	m.is_hemisphere = true
	return m


## A capsule along Y, centered; height is the total length.
static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = _segments()
	m.rings = maxi(1, _rings() - 3)
	return m


## Transform helpers: a position, optionally with a scale and a rotation around X (radians).
static func at(pos: Vector3, scale: Vector3 = Vector3.ONE, x_rotation: float = 0.0) -> Transform3D:
	var basis := Basis(Vector3.RIGHT, x_rotation) * Basis.from_scale(scale)
	return Transform3D(basis, pos)


static func _segments() -> int:
	return int(Config.get_value("body", "radial_segments", 8))


static func _rings() -> int:
	return int(Config.get_value("body", "sphere_rings", 5))
