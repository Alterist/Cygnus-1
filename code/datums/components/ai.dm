/*
AI CONTROLLER COMPONENT

Really just here to exist as a way to hold the ai behavior while being an easy way of applying ai to atom/movables
The main purpose of this is to handle cleanup and setting up the initial ai behavior
*/

/**
 * An absolute hardcap on the # of instances of /datum/component/ai_controller that can exist.
 * Should a ai component get initialized while there's already enough instances of said thing, it will deny the initialization of the component but NOT the mob it's being attached to.
 * This is mainly here because admins keep on spamming AI without caring for the server's ability to handle hundreds/thousands of AI.
 */
#define AI_INSTANCE_HARDCAP 200

//The most basic of AI; can pathfind to a turf and path around objects in it's path if needed to
/datum/component/ai_controller
	var/datum/ai_behavior/ai_behavior //Calculates the action states to take and the parameters it gets; literally the brain

/datum/component/ai_controller/Initialize(behavior_type, atom/atom_to_escort)
	. = ..()

	if((length(GLOB.ai_instances_active) + 1) >= AI_INSTANCE_HARDCAP)
		message_admins("Notice: An AI controller was initialized but because there's already too many AI controllers existing, the initialization was canceled.")
		return COMPONENT_INCOMPATIBLE

	if(!ismob(parent)) //Requires a mob as the element action states needed to be apply depend on several mob defines like cached_multiplicative_slowdown or do_actions
		stack_trace("An AI controller was initialized on a parent that isn't compatible with the ai component. Parent type: [parent.type]")
		return COMPONENT_INCOMPATIBLE
	if(isnull(behavior_type))
		stack_trace("An AI controller was initialized without a mind to initialize parameter; component removed")
		return COMPONENT_INCOMPATIBLE
	ai_behavior = new behavior_type(src, parent, atom_to_escort, isliving(parent))
	for(var/obj/effect/ai_node/node in range(7))
		ai_behavior.current_node = node
		break
	//Iniatialise the behavior of the ai
	ai_behavior.late_initialize()
	RegisterSignal(parent, list(COMSIG_PARENT_PREQDELETED, COMSIG_MOB_DEATH), .proc/RemoveComponent)
	RegisterSignal(parent, COMSIG_COMBAT_LOG, .proc/handle_combat_log)
	RegisterSignal(parent, COMSIG_MOB_LOGIN, .proc/stop_controlling)
	GLOB.ai_instances_active += src

//Removes registered signals and action states, useful for scenarios like when the parent is destroyed or a client is taking over
/datum/component/ai_controller/proc/handle_combat_log()
	SIGNAL_HANDLER
	return DONT_LOG

/datum/component/ai_controller/RemoveComponent()
	clean_up()
	return ..()

/datum/component/ai_controller/proc/clean_up()
	SIGNAL_HANDLER
	GLOB.ai_instances_active -= src
	UnregisterSignal(parent, COMSIG_COMBAT_LOG)
	UnregisterSignal(parent, list(COMSIG_PARENT_PREQDELETED, COMSIG_MOB_DEATH))
	if(ai_behavior)
		STOP_PROCESSING(SSprocessing, ai_behavior)
		ai_behavior.cleanup_current_action()
		QDEL_NULL(ai_behavior)

///Stop this ai controller from acting on the mob
/datum/component/ai_controller/proc/stop_controlling()
	SIGNAL_HANDLER
	STOP_PROCESSING(SSprocessing, ai_behavior)
	ai_behavior.cleanup_current_action()
	GLOB.ai_instances_active -= src
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, .proc/resume_controlling)

///Resume this ai controller process
/datum/component/ai_controller/proc/resume_controlling()
	SIGNAL_HANDLER
	UnregisterSignal(parent, COMSIG_MOB_LOGOUT)
	if((length(GLOB.ai_instances_active) + 1) >= AI_INSTANCE_HARDCAP)
		message_admins("Notice: An AI controller failed resume because there's already too many AI controllers existing.")
		return
	START_PROCESSING(SSprocessing, ai_behavior)
	ai_behavior.late_initialize()
	GLOB.ai_instances_active += src

/datum/component/ai_controller/Destroy()
	clean_up()
	return ..()
