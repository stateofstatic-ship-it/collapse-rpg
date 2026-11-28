class_name Heritage
extends RefCounted
## Heritage presets and skin ramps for the layered family sprites. A preset
## only sets looks and name pools; no rule anywhere reads it (plan Q8).

const PRESETS: Array[String] = ["Black or African American", "East Asian", "Latino or Hispanic", "Middle Eastern or North African", "Native American or Alaska Native", "Pacific Islander", "South Asian", "White", "Mixed"]
const TONES := [
	[Color(0.16, 0.09, 0.05), Color(0.48, 0.31, 0.2)],
	[Color(0.42, 0.29, 0.19), Color(0.96, 0.84, 0.7)],
	[Color(0.33, 0.2, 0.12), Color(0.85, 0.66, 0.48)],
	[Color(0.35, 0.22, 0.14), Color(0.88, 0.7, 0.54)],
	[Color(0.3, 0.17, 0.1), Color(0.78, 0.56, 0.4)],
	[Color(0.26, 0.15, 0.09), Color(0.72, 0.52, 0.36)],
	[Color(0.22, 0.12, 0.07), Color(0.68, 0.48, 0.32)],
	[Color(0.48, 0.32, 0.24), Color(0.99, 0.86, 0.76)],
	[Color(0.3, 0.18, 0.11), Color(0.82, 0.62, 0.46)],
]
const NAMES := {
	"any": ["Morgan", "Jordan", "Riley", "Avery", "Casey", "Rowan", "Quinn", "Sage", "Emery", "Reese", "Kai", "Sam", "Alex", "Jamie", "Robin", "Drew", "Frankie", "Remy"],
	"hero": ["Morgan", "Jordan", "Andrea", "Marcus", "Priya", "Luis", "Hana", "Tomas", "Keisha", "Owen", "Lena", "Malik", "Rosa", "Daniel", "Mei", "Samir"],
	"partner": ["Dana", "Chris", "Adrienne", "Nate", "Farah", "Diego", "Yuki", "Grant", "Imani", "Noel", "Teresa", "Ravi", "Lucia", "Ben", "Sun", "Omar"],
	"teen": ["Tess", "Jaden", "Maya", "Leo", "Zara", "Mateo", "Aiko", "Finn", "Nia", "Eli", "Sofia", "Arjun", "Ivy", "Theo", "Lina", "Kofi"],
	"child": ["Eli", "Ruby", "Max", "Ava", "Sami", "June", "Oscar", "Mira", "Kenji", "Lola", "Ezra", "Ana", "Felix", "Noor", "Jonah", "Isla"],
	"elder": ["Walt", "Marge", "Frank", "Esther", "Hiro", "Lupe", "Earl", "Bea", "Rajesh", "Opal", "Gus", "Mae", "Ignacio", "Ruthanne", "Desmond", "Lorna"],
	"dog": ["Pilot", "Biscuit", "Juno", "Ranger", "Moss", "Pepper", "Scout", "Tucker", "Olive", "Bear", "Lady", "Rook"],
	"surname": ["Hale", "Okafor", "Nguyen", "Ramirez", "Patel", "Kowalski", "Begay", "Tanaka", "Haddad", "Johansson", "Mensah", "Castillo", "Lindqvist", "Fale", "Reyes", "Whitfield"],
}


static func tone(i: int) -> Array:
	return TONES[clampi(i, 0, TONES.size() - 1)]


static func roll_name(pool: String, r: RandomNumberGenerator) -> String:
	var arr: Array = NAMES.get(pool, NAMES["any"])
	return arr[r.randi() % arr.size()]
