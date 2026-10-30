extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:
	call_deferred("run")
func outward_normals(mesh:Mesh)->bool:
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in range(0,vertices.size(),3):
			var face:Vector3=-(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if face.length_squared()>0.0000001 and face.normalized().dot(normals[i])<0.1:
				return false
	return true
func run()->void:
	var course=load("res://scripts/offroad_course.gd").new()
	root.add_child(course)
	course.build(JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json")))
	var forest=course.terrain.get_node_or_null("ForestValley")
	if forest==null:
		push_error("Dense layered forest, cliffs and creek detail not implemented")
		quit(1)
		return
	var trees:=0
	var chunks:=0
	var layered:=true
	for node in forest.find_children("*","MultiMeshInstance3D",true,false):
		if node.get_meta("forest_tree",false):
			trees+=node.multimesh.instance_count
			chunks+=1
			layered=layered and node.multimesh.mesh.get_surface_count()>=2
	check(trees>=1500 and chunks>=20 and layered,"forest uses dense branched trunks/foliage in spatial batches")
	var clear:=true
	for node in forest.find_children("ForestTrunk*","StaticBody3D",true,false):
		var p:Vector3=node.position
		if course.terrain.trail_distance(Vector2(p.x,p.z))<5:
			clear=false
	check(clear,"collidable tree trunks leave the main route clear")
	check(forest.find_children("Cliff*","StaticBody3D",true,false).size()>=8,"playable valley includes physical rock formations")
	check(forest.get_node_or_null("MountainRidge")!=null,"continuous distant ridge replaces primitive mountain cones")
	check(forest.get_node_or_null("CreekBanks")!=null,"creek has dedicated bank vegetation and rock detail")
	var assets=load("res://scripts/forest_assets.gd")
	check(outward_normals(assets.sculpt_rock(Vector3.ONE,1)),"rock normals match Godot clockwise exterior faces")
	check(outward_normals(assets.trees[0]),"tree and leaf normals agree with their face winding")
	check(outward_normals(forest.get_node("MountainRidge").mesh),"mountain ridge normals match its visible valley-facing surfaces")
	print("Forest scenery: ",checks-failures,"/",checks," passed; trees=",trees," chunks=",chunks)
	course.queue_free()
	await process_frame
	quit(1 if failures else 0)
