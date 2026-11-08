extends RefCounted
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func run(world: Node3D) -> bool:
	var camp: Node3D = world.camp
	check(camp.has_node("CookingStation/IronPot") and camp.has_node("CookStool"),"Cooking station and physical seating present")
	var activities: Array = []
	for avatar in camp.avatars: activities.append(avatar.activity)
	check(activities==["smoking","cooking","sharpening","watching"],"Four distinct camp activities")
	var hand_error := 0.0
	var lowest_foot := 10.0
	var cigarette_error := 0.0
	var spoon_radius := 0.0
	var blade_contact := 0.0
	for skin in range(3):
		for slot in range(4):
			camp.set_skin(slot,skin)
			camp.avatars[slot].set_process(false)
		for sample in range(24):
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
			cigarette_error = maxf(cigarette_error,smoker.cigarette.global_position.distance_to(smoker.hand("r")))
			var cook: Node3D = camp.avatars[1]
			spoon_radius = maxf(spoon_radius,cook.spoon_bowl.global_position.distance_to(camp.global_position+Vector3(0,0.935,0.3)))
			var sharpener: Node3D = camp.avatars[2]
			var local_stone: Vector3 = sharpener.knife.to_local(sharpener.stone.global_position)
			blade_contact = maxf(blade_contact,Vector2(local_stone.x,local_stone.z).length())
	check(hand_error<0.015,"Hand targets reached throughout all three skins and activity cycles (max %.4f m)" % hand_error)
	check(lowest_foot>=0,"Feet stay above ground for every skin (min %.3f m)" % lowest_foot)
	check(cigarette_error<0.12,"Cigarette follows hand throughout raise and lower")
	check(spoon_radius<0.16,"Spoon stays inside cooking pot throughout stirring")
	check(blade_contact<0.09,"Whetstone tracks the blade during sharpening (max %.3f m)" % blade_contact)
	check(camp.avatars[0].cigarette.find_child("Smoke",true,false)!=null,"Cigarette smoke emitter present")
	for i in range(2): await world.get_tree().process_frame
	check(camp.find_children("WoodenSpoon*","Node3D",false,false).size()==1,"Changing skins releases previous cook props")
	camp.avatars[1].hide()
	camp.avatars[1]._pose(0)
	check(not camp.avatars[1].spoon.visible,"Absent lobby cook has no floating spoon")
	print("CAMP06: ",failures.size()," errors")
	return failures.is_empty()
