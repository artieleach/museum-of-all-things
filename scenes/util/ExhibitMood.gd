class_name ExhibitMood
extends RefCounted
## Determines exhibit mood from Wikipedia categories.
## Mood affects fog color, fog density, ambient light color, and decoration bias.

enum Mood { DEFAULT, HISTORY, SCIENCE, NATURE, ASTRO, MEDIA }

const MOOD_KEYWORDS: Dictionary = {
	Mood.HISTORY: ["history", "century", "ancient", "medieval", "war", "empire", "dynasty", "civilization", "kingdom", "revolution", "colonial"],
	Mood.SCIENCE: ["science", "physics", "chemistry", "biology", "mathematics", "technology", "engineering", "medicine", "computer", "algorithm"],
	Mood.NATURE: ["nature", "species", "animal", "plant", "ecology", "forest", "ocean", "wildlife", "bird", "fish", "insect", "mammal", "flora", "fauna"],
	Mood.ASTRO: ["astronomy", "space", "planet", "star", "galaxy", "cosmos", "solar", "lunar", "orbit", "nasa", "telescope", "nebula"],
	Mood.MEDIA: ["film", "television", "album", "song", "music", "novel", "literature", "actor", "actress", "director", "band", "soundtrack"],
}

const MOOD_FOG_COLOR: Dictionary = {
	Mood.DEFAULT: Color.WHITE,
	Mood.HISTORY: Color(1.0, 0.85, 0.6),
	Mood.SCIENCE: Color(0.75, 0.88, 1.0),
	Mood.NATURE: Color(0.7, 0.95, 0.7),
	Mood.ASTRO: Color(0.5, 0.4, 0.8),
	Mood.MEDIA: Color(1.0, 0.92, 0.8),
}

const MOOD_FOG_DEPTH: Dictionary = {
	Mood.DEFAULT: 10.0,
	Mood.HISTORY: 12.0,
	Mood.SCIENCE: 8.0,
	Mood.NATURE: 14.0,
	Mood.ASTRO: 6.0,
	Mood.MEDIA: 10.0,
}

const MOOD_AMBIENT_COLOR: Dictionary = {
	Mood.DEFAULT: Color(1.0, 1.0, 1.0),
	Mood.HISTORY: Color(1.0, 0.9, 0.7),
	Mood.SCIENCE: Color(0.8, 0.9, 1.0),
	Mood.NATURE: Color(0.8, 1.0, 0.8),
	Mood.ASTRO: Color(0.6, 0.5, 0.9),
	Mood.MEDIA: Color(1.0, 0.95, 0.85),
}

const MOOD_AMBIENT_ENERGY: Dictionary = {
	Mood.DEFAULT: 0.4,
	Mood.HISTORY: 0.25,
	Mood.SCIENCE: 0.3,
	Mood.NATURE: 0.2,
	Mood.ASTRO: 0.15,
	Mood.MEDIA: 0.22,
}


static func compute_mood(categories: Array) -> int:
	var scores: Dictionary = {}
	for mood: int in MOOD_KEYWORDS:
		scores[mood] = 0

	for category: String in categories:
		var lower: String = category.to_lower()
		for mood: int in MOOD_KEYWORDS:
			for keyword: String in MOOD_KEYWORDS[mood]:
				if lower.find(keyword) >= 0:
					scores[mood] += 1

	var best_mood: int = Mood.DEFAULT
	var best_score: int = 0
	for mood: int in scores:
		if scores[mood] > best_score:
			best_score = scores[mood]
			best_mood = mood

	# Need at least 2 keyword hits to assign a mood
	if best_score < 2:
		return Mood.DEFAULT
	return best_mood


static func get_fog_color(mood: int) -> Color:
	return MOOD_FOG_COLOR.get(mood, MOOD_FOG_COLOR[Mood.DEFAULT])


static func get_fog_depth(mood: int) -> float:
	return MOOD_FOG_DEPTH.get(mood, MOOD_FOG_DEPTH[Mood.DEFAULT])


static func get_ambient_color(mood: int) -> Color:
	return MOOD_AMBIENT_COLOR.get(mood, MOOD_AMBIENT_COLOR[Mood.DEFAULT])


static func get_ambient_energy(mood: int) -> float:
	return MOOD_AMBIENT_ENERGY.get(mood, MOOD_AMBIENT_ENERGY[Mood.DEFAULT])


static func prefers_pool(mood: int) -> bool:
	return mood == Mood.ASTRO or mood == Mood.NATURE


static func prefers_planter(mood: int) -> bool:
	return mood == Mood.NATURE or mood == Mood.HISTORY
