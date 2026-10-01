extends Node

# Solo señales: así ninguna pantalla depende directamente de otra.

signal mission_started(mission: MissionData)
signal exercise_requested(mission: MissionData)
signal exercise_failed(mission: MissionData, option: OptionData, attempt: int)
signal exercise_passed(mission: MissionData)
signal mission_completed(mission: MissionData)
