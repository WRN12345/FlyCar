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
func run()->void:
	var catalog=load("res://scripts/track_catalog.gd")
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json"))
	var points: Array[Vector3]=catalog.sample(data)
	var uphill:=0.0
	var downhill:=0.0
	var rises:=0
	var falls:=0
	var old_sign:=0
	var low:=INF
	var high:=-INF
	for i in points.size():
		var a:Vector3=points[i]
		var b:Vector3=points[(i+1)%points.size()]
		var grade:float=(b.y-a.y)/maxf(Vector2(b.x-a.x,b.z-a.z).length(),0.001)
		low=minf(low,a.y)
		high=maxf(high,a.y)
		if grade>0.10:
			uphill+=a.distance_to(b)
			if old_sign!=1:
				rises+=1
			old_sign=1
		elif grade< -0.10:
			downhill+=a.distance_to(b)
			if old_sign!=-1:
				falls+=1
			old_sign=-1
	check(uphill>400 and downhill>400 and rises>=4 and falls>=4,"main route has repeated meaningful climbs and descents")
	check(load("res://scripts/offroad_model.gd").material_at(295,-430)=="rock","canyon bypass remains a continuous exposed-rock road through its inside bend")
	print("Rugged grades: up=",uphill," down=",downhill," cycles=",rises,"/",falls," relief=",high-low)
	var course=load("res://scripts/offroad_course.gd").new()
	root.add_child(course)
	course.build(data)
	var pose:Transform3D=course.pose_at(75)
	var center:=pose.origin
	var verge:=center+pose.basis.x*5
	check(course.terrain.surface_at(center).material=="dirt" and course.terrain.surface_at(verge).material=="grass","five metres off center is grass rather than an oversized dirt road")
	check(course.terrain.has_method("trail_coverage") and course.terrain.call("trail_coverage",Vector2(center.x,center.z))>0.9 and course.terrain.call("trail_coverage",Vector2(verge.x,verge.z))<0.01,"visual mask accurately bounds the narrow trail")
	var image:Image=course.terrain.trail_image
	var bounds:Rect2=course.terrain.bounds
	var scale:float=course.terrain.MASK_SCALE
	var pixel:Vector2=(Vector2(center.x,center.z)-bounds.position)*scale
	var edge:Vector2=(Vector2(verge.x,verge.z)-bounds.position)*scale
	check(image.get_pixel(int(pixel.x),int(pixel.y)).a>0.9 and image.get_pixel(int(edge.x),int(edge.y)).a<0.01,"uploaded trail texture contains narrow coverage rather than only an analytic width")
	var rocks=course.terrain.find_children("TrailRock*","StaticBody3D",true,false)
	check(rocks.size()>=24,"rock sections have physical low obstacles and shoulder boulders")
	print("Narrow rugged trails: ",checks-failures,"/",checks," passed")
	course.queue_free()
	await process_frame
	quit(1 if failures else 0)
