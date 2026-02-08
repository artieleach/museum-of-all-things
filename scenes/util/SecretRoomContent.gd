class_name SecretRoomContent
extends RefCounted
## Curated list of unusual/fascinating Wikipedia articles for secret rooms.

const SECRET_CHANCE: float = 0.12  # ~12% chance per room

const CURATED_ARTICLES: Array[String] = [
	"Voynich manuscript",
	"Antikythera mechanism",
	"Dancing plague of 1518",
	"Bloop",
	"Number station",
	"Wow! signal",
	"Georgia Guidestones",
	"Dyatlov Pass incident",
	"Taos Hum",
	"Codex Seraphinianus",
	"Oak Island",
	"Roanoke Colony",
	"Sailing stones",
	"Ball lightning",
	"Tunguska event",
	"Hessdalen lights",
	"Mary Celeste",
	"Overtoun Bridge",
	"SS Ourang Medan",
	"Lead masks case",
	"Cicada 3301",
	"UVB-76",
	"Max Headroom signal hijacking",
	"Toynbee tiles",
	"Tamam Shud case",
	"Phaistos Disc",
	"Rongorongo",
	"Linear A",
	"Zodiac Killer",
	"D. B. Cooper",
	"Beale ciphers",
	"Kryptos",
	"Elisa Lam",
	"Flannan Isles Lighthouse",
	"Philadelphia Experiment",
	"Rendlesham Forest incident",
	"Kentucky Meat Shower",
	"Rain of animals",
	"Spontaneous human combustion",
	"Winchester Mystery House",
	"Cottingley Fairies",
	"Spring-heeled Jack",
	"Mothman",
	"Jersey Devil",
	"Mokele-mbembe",
	"Yeti",
	"Loch Ness Monster",
	"Bermuda Triangle",
	"Zone of Silence",
	"Aokigahara",
]


static func should_have_secret(exhibit_title: String, room_index: int) -> bool:
	var h: int = hash(exhibit_title + ":secret:" + str(room_index))
	return (h % 100) < int(SECRET_CHANCE * 100)


static func get_secret_article(exhibit_title: String) -> String:
	var h: int = hash(exhibit_title + ":secret")
	return CURATED_ARTICLES[absi(h) % CURATED_ARTICLES.size()]
