extends RefCounted
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func run(world: Node3D) -> bool:
	var camp: Node3D = world.camp
	check(camp.has_node("Military4x4") and camp.has_node("SharedCampLog") and not camp.has_node("CookStool") and not camp.has_node("CookingStation"),"Military 4x4 and seating present; pot removed")
	var activities: Array = []
	for avatar in camp.avatars: activities.append(avatar.activity)
	check(activities==["smoking","roasting_chicken","cleaning_sniper","inspecting_katana"],"Four distinct camp activities")
	var hand_error := 0.0
	var lowest_foot := 10.0
	var cigarette_error := 0.0
	var roast_radius := 0.0
	var cloth_error := 0.0
	var grip_error := 0.0
	var knee_clearance := 10.0
	var boot_contact_error := 0.0
	var raised_boot_height := 10.0
	var gloves_ok := true
	var glove_attachment_error := 0.0
	var support_alignment := 1.0
	var cloth_finger_gap := 0.0
	var cloth_tip_y := 0.0
	var katana_grip_error := 0.0
	var max_wrist_angle := 0.0
	var idle_wrist_angle := 0.0
	var worst_hand := ""
	var pistol_grip_error := 0.0
	var pistol_down := 1.0
	var pistol_wrap := true
	var screen_positions: Array[Vector2] = []
	for avatar in camp.avatars:
		screen_positions.append(camp.camera.unproject_position(avatar.global_position+Vector3(0,1.4,0)))
	var separated := true
	for i in range(4):
		separated = separated and screen_positions[i].x>450 and screen_positions[i].x<1380
		for j in range(i): separated = separated and absf(screen_positions[i].x-screen_positions[j].x)>95
	check(separated,"All four upper bodies are visible and separated outside menu text")
	check(camp.avatars[3].position.z<0.3 and camp.avatars[3].position.x<0,"Katana survivor kneels beside fire, with center foreground open")
	var shared_log: Node3D=camp.get_node("SharedCampLog")
	var seats_on_log := true
	for slot in [1,2]:
		var avatar: Node3D=camp.avatars[slot]
		var pelvis: Vector3=(avatar.skeleton.global_transform*avatar.skeleton.get_bone_global_pose(avatar.bone_ids["pelvis"])).origin
		var seat: Vector3=shared_log.to_local(pelvis)
		seats_on_log=seats_on_log and absf(seat.x)<0.20 and seat.z>-1.65 and seat.z<1.0 and absf(seat.y-0.244)<0.06
	check(seats_on_log,"Cook and right-hand rifle survivor sit along the same log")
	check(camp.avatars[3].foot_solvers.is_empty() and camp.avatars[3].rest_position.is_equal_approx(Vector3(-1,-0.4,-1.1)),"Left-hand katana survivor retains previous kneeling placement")
	var rifle: Node3D=camp.avatars[2].sniper
	check(rifle.weapon_skeleton!=null and rifle.has_node("Muzzle") and rifle.has_node("Magazine") and rifle.has_node("GripMain"),"Reusable rifle scene retains rig and weapon attachment markers")
	check(camp.avatars[3].katana.has_node("BladeTip") and camp.avatars[3].katana.has_node("GripMain"),"Reusable katana scene exposes blade and grip markers")
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
				gloves_ok = gloves_ok and avatar.hand_visuals.size()==2
				for pair in [["r",avatar.right_goal],["l",avatar.left_goal]]:
					var reach: float = avatar.hand(pair[0]).distance_to(pair[1].global_position)
					if reach>hand_error:
						hand_error=reach
						worst_hand="slot %d side %s clock %.1f" % [camp.avatars.find(avatar),pair[0],avatar.clock]
				for side in ["l","r"]:
					var glove: Node3D = avatar.hand_visuals[side]
					gloves_ok = gloves_ok and glove.rig is Skeleton3D and glove.rig.get_bone_count()==20 and glove.fingertips.size()==5 and glove.digit_meshes==20
					glove_attachment_error=maxf(glove_attachment_error,glove.global_position.distance_to(avatar.hand(side)))
					var elbow: Vector3 = (avatar.skeleton.global_transform*avatar.skeleton.get_bone_global_pose(avatar.bone_ids["lowerarm_"+side])).origin
					var finger_direction: Vector3 = glove.global_basis.x*(1.0 if side=="l" else -1.0)
					max_wrist_angle=maxf(max_wrist_angle,rad_to_deg(finger_direction.angle_to((avatar.hand(side)-elbow).normalized())))
					if avatar.stance==0 and side=="l":idle_wrist_angle=maxf(idle_wrist_angle,rad_to_deg(finger_direction.angle_to((avatar.hand(side)-elbow).normalized())))
					for i in range(1,4): gloves_ok = gloves_ok and glove.fingertips[i].distance_to(glove.fingertips[i-1])>0.014
					var foot: Vector3 = (avatar.skeleton.global_transform*avatar.skeleton.get_bone_global_pose(avatar.bone_ids["foot_"+side])).origin
					lowest_foot = minf(lowest_foot,foot.y)
			var smoker: Node3D = camp.avatars[0]
			pistol_grip_error=maxf(pistol_grip_error,smoker.sidearm.get_node("GripMain").global_position.distance_to(smoker.hand_visuals["l"].to_global(smoker.hand_visuals["l"].grip_frame().center)))
			pistol_down=minf(pistol_down,smoker.sidearm.global_basis.x.dot(Vector3.DOWN))
			var pistol_hand: Node3D=smoker.hand_visuals["l"]
			# Grip length must follow the row of knuckles, with fingers passing
			# around the grip from its near side to the opposite side.
			pistol_wrap=pistol_wrap and smoker.sidearm.global_basis.y.dot(pistol_hand.global_basis.y)>0.99
			for digit in ["middleFinger","ringFinger","littleFinger"]:
				var base_id: int=pistol_hand.rig.find_bone(digit+"_01_l")
				var tip_id: int=pistol_hand.rig.find_bone(digit+"_04_l")
				var base: Vector3=smoker.sidearm.to_local(pistol_hand.rig.to_global(pistol_hand.rig.get_bone_global_pose(base_id).origin))
				var tip: Vector3=smoker.sidearm.to_local(pistol_hand.rig.to_global(pistol_hand.rig.get_bone_global_pose(tip_id).origin))
				pistol_wrap=pistol_wrap and base.z< -0.015 and tip.z>0.012 and tip.y<0.0
			var knee: Vector3 = (smoker.skeleton.global_transform*smoker.skeleton.get_bone_global_pose(smoker.bone_ids["calf_l"])).origin-camp.global_position
			var boot: Vector3 = (smoker.skeleton.global_transform*smoker.skeleton.get_bone_global_pose(smoker.bone_ids["foot_l"])).origin-camp.global_position
			knee_clearance = minf(knee_clearance,knee.z-0.18)
			boot_contact_error = maxf(boot_contact_error,absf(boot.z-0.30))
			raised_boot_height = minf(raised_boot_height,boot.y)
			cigarette_error = maxf(cigarette_error,smoker.cigarette.global_position.distance_to(smoker.hand_visuals["r"].to_global(smoker.hand_visuals["r"].cigarette_anchor())))
			var cook: Node3D = camp.avatars[1]
			roast_radius = maxf(roast_radius,cook.chicken.global_position.distance_to(camp.global_position+Vector3(0,0.935,0.3)))
			var cleaner: Node3D = camp.avatars[2]
			var local_cloth: Vector3 = cleaner.sniper.to_local(cleaner.cloth.global_position)
			cloth_error = maxf(cloth_error,absf(local_cloth.y-cleaner.sniper.get_node("CleaningSurface").position.y)+absf(local_cloth.z))
			var cleaner_glove: Node3D = cleaner.hand_visuals["r"]
			var cloth_finger: Vector3 = cleaner.cloth.to_local(cleaner_glove.to_global(cleaner_glove.fingertips[0]))
			if absf(cloth_finger.y-0.013)>cloth_finger_gap:
				cloth_finger_gap=absf(cloth_finger.y-0.013)
				cloth_tip_y=cloth_finger.y
			support_alignment=minf(support_alignment,cleaner.hand_visuals["l"].global_basis.z.dot(cleaner.sniper.global_basis.y))
			var inspector: Node3D = camp.avatars[3]
			var grip: Vector3 = inspector.katana.to_global(Vector3(-0.1,0,0))
			grip_error = maxf(grip_error,grip.distance_to(inspector.hand("r")))
			katana_grip_error=maxf(katana_grip_error,grip.distance_to(inspector.hand_visuals["r"].to_global(Vector3(-0.09,0,-0.023))))
			support_alignment=minf(support_alignment,inspector.hand_visuals["l"].global_basis.z.dot(inspector.katana.global_basis.y))
	check(hand_error<0.015,"Hand targets reached throughout all three skins and activity cycles (max %.4f m %s)" % [hand_error,worst_hand])
	check(lowest_foot>=0,"Feet stay above ground for every skin (min %.3f m)" % lowest_foot)
	check(cigarette_error<0.001,"Cigarette stays at the thumb and index pinch throughout cycle")
	check(roast_radius<0.25,"Chicken stays above fire throughout turning (max %.3f m)" % roast_radius)
	check(knee_clearance>0.15,"Bent knee stays outside vehicle body (clearance %.3f m)" % knee_clearance)
	check(boot_contact_error<0.15 and raised_boot_height>0.3,"Raised boot stays near wheel side (max depth gap %.3f m)" % boot_contact_error)
	check(is_equal_approx(camp.avatars[1].spit_shaft.mesh.height,1.05),"Roasting stick keeps a fixed length")
	check(cloth_error<0.005,"Cleaning cloth remains on rifle stock throughout inspection")
	check(camp.avatars[2].sniper.has_node("Scope"),"Scoped rifle replaces the sidearm")
	check(grip_error<0.11,"Katana grip remains within palm reach throughout cycle")
	check(camp.avatars[0].cigarette.find_child("Smoke",true,false)!=null,"Cigarette smoke emitter present")
	for i in range(2): await world.get_tree().process_frame
	check(camp.find_children("RoastingSpit*","Node3D",false,false).size()==1,"Changing skins releases previous cook props")
	camp.avatars[1].hide()
	camp.avatars[1]._pose(0)
	check(not camp.avatars[1].spit.visible,"Absent lobby cook has no floating roast")
	var smoker: Node3D = camp.avatars[0]
	smoker.clock = 6.3
	smoker._pose(0)
	check(smoker.exhale.emitting and smoker.exhale.direction.z>0.8,"Exhalation moves forward away from the face")
	smoker.clock = 7.0
	smoker._pose(0)
	check(not smoker.exhale.emitting,"Exhalation stops after the short puff")
	check(gloves_ok,"All three skins use five separate skinned digits; fused source hands removed")
	check(glove_attachment_error<0.001,"New hands stay attached to both wrists throughout animation")
	check(support_alignment>0.99,"Support palms face up beneath rifle and katana, without inverted wrists")
	check(cloth_finger_gap<0.01,"Fingertip surface touches cleaning cloth (max gap %.4f m, tip y %.4f)" % [cloth_finger_gap,cloth_tip_y])
	check(katana_grip_error<0.005,"Katana handle stays centered inside closed fingers (max %.4f m)" % katana_grip_error)
	check(max_wrist_angle<85.0,"Wrists avoid backward folds across all skins and cycles (max %.1f degrees)" % max_wrist_angle)
	check(idle_wrist_angle<25.0,"Smoker's lowered wrist stays aligned with forearm (max %.1f degrees)" % idle_wrist_angle)
	check(pistol_grip_error<0.001 and pistol_down>0.70,"Pistol stays in left grip with muzzle lowered (grip %.4f down %.2f)" % [pistol_grip_error,pistol_down])
	check(pistol_wrap,"Pistol grip aligns with knuckle row and three curled fingers wrap to its opposite side")
	print("CAMP10: ",failures.size()," errors")
	return failures.is_empty()



