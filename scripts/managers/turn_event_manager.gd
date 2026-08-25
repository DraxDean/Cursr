# scripts/managers/turn_event_manager.gd
# Collects turn events (discoveries, waves, etc.) and drives the notification
# badge on the End Day button.  After the player clicks End Day the events are
# cleared for the next turn.
extends Node

# ---- data ----
var _pending_events: Array = []   # Array of {title, body, icon} Dictionaries

# ---- signals ----
signal events_changed(count: int)   # Emitted whenever the event list changes

# ------------------------------------------------------------------ public --

func push_event(title: String, body: String, icon: String = "⚠"):
	"""Queue one event to be shown this turn."""
	_pending_events.append({"title": title, "body": body, "icon": icon})
	events_changed.emit(_pending_events.size())
	DebugConfig.dprint("turn_events", ["TurnEvent: [%s] %s" % [title, body]])

func get_events() -> Array:
	return _pending_events.duplicate()

func clear():
	_pending_events.clear()
	events_changed.emit(0)
