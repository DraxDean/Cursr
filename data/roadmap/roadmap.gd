# data/roadmap/roadmap.gd
# Version milestone recaps shown in the main menu's Roadmap list. Each entry has:
#   version    - short version tag, e.g. "0.8" or "0.8.9"
#   title      - one/two-word theme for the milestone
#   status     - "completed" or "planned"
#   summary    - one-line scope description shown at the top of the full review
#   highlights - list of condensed feature bullets covered by the milestone
#
# Versioning scheme: MAJOR.MINOR.MILESTONE.PUSH (e.g. "v0.8.9.153"), shown in the main menu
# by _show_version_label() as "v" + CURRENT_VERSION + "." + <git commit count>.
#   MAJOR.MINOR ("0.8") - the project's overall version, bumped rarely.
#   MILESTONE ("0.8.9", "0.8.10", ...) - one of the big roadmap milestones below, worked on
#     in whatever order makes sense rather than strictly sequentially. Milestones that used
#     to bump MINOR (0.9, 0.10, 0.11...) now live under 0.8 instead, so MINOR doesn't have to
#     move until a large amount of these milestones are actually done.
#   PUSH ("153") - the git commit count, same rolling push tracker as before.
# Update CURRENT_VERSION by hand to whichever milestone was MOST RECENTLY completed (not the
# next one being worked toward) — it only advances once that next milestone is actually done.
extends Object

const CURRENT_VERSION := "0.8.9"

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
		"version":    "0.8.9",
		"title":      "New Game Overhaul",
		"status":     "completed",
		"summary":    "Making the first few minutes of a run feel intentional, from camera framing to how the world itself comes into being.",
		"highlights": [
			"Camera/zoom tuned per world-creation stage so the full map stays visible while it builds. ✅ (completed)",
			"World-creation animation pass — combine the resource-generation step, fade in from black onto the opening ocean (with an ambient ocean sound bed), then reveal the land rising up through a fading blue overlay. 🔁 (rescheduled)",
			"World generation tuning — resource density, winding forest/mountain ranges, a larger map, and better-placed marauder spawns. ✅ (completed)",
			"Intro/welcome screen after the world is built, with a toggle for whether tutorial popups show. ✅ (completed)",
		],
	},
	{
		"version":    "0.8.10",
		"title":      "Tutorials & Onboarding",
		"status":     "planned",
		"summary":    "Teaching new players the loop without a wall of text, one system at a time.",
		"highlights": [
			"Tutorial event popups covering full housing, getting started, getting wood, getting stone, getting food, science, and military.",
		],
	},
	{
		"version":    "0.8.11",
		"title":      "Events & Notifications Overhaul",
		"status":     "planned",
		"summary":    "Cleaning up how the game talks to the player — less clutter, clearer signal.",
		"highlights": [
			"Balance and flavor tweaks to individual world events.",
			"Notification panel rework — a scrollable feed that stops short of overlapping the settings area, plus a Clear Notifications button.",
			"Grouped death events — single-day deaths under 5 keep their own event; 5 or more roll up into one event with each death still viewable inside it.",
			"Combat events reworked to scale cleanly with large armies.",
		],
	},
	{
		"version":    "0.8.12",
		"title":      "Long-Term Ideas",
		"status":     "planned",
		"summary":    "Bigger swings that aren't scheduled yet, but are worth writing down before they're forgotten.",
		"highlights": [
			"100-day progress tracker — a row of outlined circles that fill in as you approach the end, colored by past roll outcomes.",
			"Temple & pantheons — a Temple building unlocking worship paths (light/darkness/wood goddesses, stone/sword/shield gods) at 20 population, each granting buffs.",
			"A toggleable heavy gold-upkeep mode for a harder economy.",
			"Elemental sword spirits (fire/lightning/ice) — legendary army-wide equips unlocked through a research + event chain.",
			"An Armoury page to spend gold on military upgrades.",
			"Encyclopedia unlocks for discovered events and collectibles.",
			"Expand the main menu notice board with pinned dev/contact updates alongside the roadmap and announcements.",
		],
	},
	{
		"version":    "0.8.13",
		"title":      "Yes, I know",
		"status":     "planned",
		"summary":    "I need a placeholder and yes I need more than ten versions before 1.0.",
		"highlights": [],
	},
]
