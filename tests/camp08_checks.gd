extends RefCounted
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func run(world: Node3D) -> bool:
	var camp: Node3D = world.camp
	check(camp.has_node("Military4x4") and camp.has_node("CookStool") and not camp.has_node("CookingStation"),"Military 4x4 and seating present; pot removed")
	var activities: Array = []
	for avatar in camp.avatars: activities.append(avatar.activity)
	check(activities==["smoking","roasting_chicken","cleaning_pistol","inspecting_katana"],"Four distinct camp activities")
	var hand_error := 0.0
	var lowest_foot := 10.0
	var cigarette_error := 0.0
	var roast_radius := 0.0
	var cloth_error := 0.0
	var grip_error := 0.0
	var knee_clearance := 10.0
	var boot_contact_error := 0.0
	var raised_boot_height := 10.0
	var screen_positions: Array[Vector2] = []
	for avatar in camp.avatars:
		screen_positions.append(camp.camera.unproject_position(avatar.global_position+Vector3(0,1.4,0)))
	var separated := true
	for i in range(4):
		separated = separated and screen_positions[i].x>450 and screen_positions[i].x<1380
		for j in range(i): separated = separated and absf(screen_positions[i].x-screen_positions[j].x)>95
	check(separated,"All four upper bodies are visible and separated outside menu text")
	check(camp.avatars[3].position.z<0.3 and camp.avatars[3].position.x<0,"Katana survivor stands beside fire, with center foreground open")
	for skin in range(3):
		for slot in range(4):
			camp.set_skin(slot,skin)
			camp.avatars[slot].set_process(false)
		for sample in range(28):
			for avatar in camp.avatars:
				avatar.clock = float(sample)*0.5
				avatar._pose(0)
			await world.get_tree().process_frame
			for avatar in camp.avatars:
				hand_error = maxf(hand_error,avatar.hand("r").distance_to(avatar.right_goal.global_position))
				hand_error = maxf(hand_error,avatar.hand("l").distance_to(avatar.left_goal.global_position))
				for side in ["l","r"]:
					var foot: Vector3 = (avatar.skeleton.global_transform*avatar.skeleton.get_bone_global_pose(avatar.bone_ids["foot_"+side])).origin
					lowest_foot = minf(lowest_foot,foot.y)
			var smoker: Node3D = camp.avatars[0]
			var knee: Vector3 = (smoker.skeleton.global_transform*smoker.skeleton.get_bone_global_pose(smoker.bone_ids["calf_l"])).origin-camp.global_position
			var boot: Vector3 = (smoker.skeleton.global_transform*smoker.skeleton.get_bone_global_pose(smoker.bone_ids["foot_l"])).origin-camp.global_position
			knee_clearance = minf(knee_clearance,knee.z-0.18)
			boot_contact_error = maxf(boot_contact_error,absf(boot.z-0.30))
			raised_boot_height = minf(raised_boot_height,boot.y)
			cigarette_error = maxf(cigarette_error,smoker.cigarette.global_position.distance_to(smoker.hand("r")))
			var cook: Node3D = camp.avatars[1]
			roast_radius = maxf(roast_radius,cook.chicken.global_position.distance_to(camp.global_position+Vector3(0,0.935,0.3)))
			var cleaner: Node3D = camp.avatars[2]
			var local_cloth: Vector3 = cleaner.pistol.to_local(cleaner.cloth.global_position)
			cloth_error = maxf(cloth_error,absf(local_cloth.y-0.111)+absf(local_cloth.z))
			var inspector: Node3D = camp.avatars[3]
			var grip: Vector3 = inspector.katana.to_global(Vector3(-0.1,0,0))
			grip_error = maxf(grip_error,grip.distance_to(inspector.hand("r")))
	check(hand_error<0.015,"Hand targets reached throughout all three skins and activity cycles (max %.4f m)" % hand_error)
	check(lowest_foot>=0,"Feet stay above ground for every skin (min %.3f m)" % lowest_foot)
	check(cigarette_error<0.12,"Cigarette follows hand throughout raise and lower")
	check(roast_radius<0.25,"Chicken stays above fire throughout turning (max %.3f m)" % roast_radius)
	check(knee_clearance>0.15,"Bent knee stays outside vehicle body (clearance %.3f m)" % knee_clearance)
	check(boot_contact_error<0.15 and raised_boot_height>0.3,"Raised boot stays near wheel side (max depth gap %.3f m)" % boot_contact_error)
	check(is_equal_approx(camp.avatars[1].spit_shaft.mesh.height,1.05),"Roasting stick keeps a fixed length")
	check(cloth_error<0.005,"Cleaning cloth remains on pistol slide throughout inspection")
	check(grip_error<0.11,"Katana grip remains within palm reach throughout cycle")
	check(camp.avatars[0].cigarette.find_child("Smoke",true,false)!=null,"Cigarette smoke emitter present")
	for i in range(2): await world.get_tree().process_frame
	check(camp.find_children("RoastingSpit*","Node3D",false,false).size()==1,"Changing skins releases previous cook props")
	camp.avatars[1].hide()
	camp.avatars[1]._pose(0)
	check(not camp.avatars[1].spit.visible,"Absent lobby cook has no floating roast")
	print("CAMP08: ",failures.size()," errors")
	return failures.is_empty()

