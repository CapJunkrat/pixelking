class_name BattleAnimationPlayer
extends Node

signal event_presented(event: BattleEvent)
signal sequence_completed

@export_range(0.1, 8.0, 0.1) var playback_speed: float = 1.0
@export_range(0.0, 0.25, 0.01) var event_delay_seconds: float = 0.03

var presented_events: Array[BattleEvent] = []
var _queue: Array[BattleEvent] = []
var _playing: bool = false

func enqueue_events(events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		_queue.append(event)
	if not _playing:
		_drain.call_deferred()

func clear() -> void:
	_queue.clear()
	presented_events.clear()

func _drain() -> void:
	if _playing:
		return
	_playing = true
	while not _queue.is_empty():
		var event: BattleEvent = _queue.pop_front() as BattleEvent
		presented_events.append(event)
		event_presented.emit(event)
		var delay: float = event_delay_seconds / maxf(playback_speed, 0.1)
		if delay > 0.0 and is_inside_tree():
			await get_tree().create_timer(delay).timeout
	_playing = false
	sequence_completed.emit()
