# data/roadmap/roadmap.gd
# Version milestone recaps shown in the main menu's Roadmap list. Each entry has:
#   version    - short version tag, e.g. "0.8"
#   title      - one/two-word theme for the milestone
#   status     - "completed" or "planned"
#   summary    - one-line scope description shown at the top of the full review
#   highlights - list of condensed feature bullets covered by the milestone
extends Object

const MILESTONES: Array = [
	{
		"version":    "0.8",
		"title":      "Foundations",
		"status":     "completed",
		"summary":    "Everything built to get a full game loop on its feet, from a blank map to a run that can be won or lost.",
		"highlights": [
			"World creation flow — race selection, narrator intro, and Town Centre placement to kick off a new game.",
			"Full building system — placement, connections, demolition, and a detailed building inspector.",
			"Pathing & job assignment overhaul — unit pathfinding, job stations, and worker (re)assignment.",
			"Resource economy — farms, fishing docks, lumberjacks, stoneworkers, and mining brought online.",
			"Population & housing — growth, capacity tracking, idle villagers, and gendered unit sprites.",
			"Science & tech tree — research buildings, research jobs, and a browsable tech tree.",
			"Military & combat — barracks training, the combat modal, army formations, and army-vs-army battles.",
			"Marauder raids — enemy camps, raid choices, and difficulty tuning.",
			"World events & notifications — an events overhaul, notification cards, and the game log.",
			"Achievements & Encyclopedia — trackable achievements plus an in-game reference/tutorial hub.",
			"Victory & game over — day-length victory, Wonder victory, and a proper game over screen.",
			"Onboarding — starter tutorials covering building and general flow.",
			"Main menu & settings — save/load, settings tabs, and version tagging.",
		],
	},
	{
		"version":    "0.9",
		"title":      "Stability",
		"status":     "planned",
		"summary":    "A focus pass on the core experience before piling on more content — cleaning up the systems players touch every session.",
		"highlights": [
			"UI rework — a consistent visual pass across menus and in-game modals.",
			"Sprite rework — refreshed unit and building art for a cohesive look.",
			"Map gen — improved world generation for more varied, balanced starts.",
			"New game — a smoother, more guided start-of-game experience.",
		],
	},
]
