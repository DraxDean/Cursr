# data/announcements/announcements.gd
# Static dev -> player announcement definitions. Each entry has:
#   id      - unique string key
#   date    - display timestamp string
#   title   - headline text
#   content - full announcement body (list preview truncates this to ~20 chars)
extends Object

const ANNOUNCEMENTS: Array = [
	{
		"id":      "hello_world",
		"date":    "2026-09-17 10:00",
		"title":   "Hello World!",
		"content": "Hello World!",
	},
]
