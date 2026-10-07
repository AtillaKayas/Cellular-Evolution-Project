class_name Substance

enum {NICK, MASS, VOLUME, CHARGE, PATTERN}

var name : String
var nick : String
var mass : float
var charge : int
var description : String

var pattern : String

static var _all : Dictionary[String, Substance]

func _init(_name : String, _mass : float, _charge : int, _nick : String = "", _pattern : String = "", _description : String = ""):
	_all[_name] = self
	name = _name
	mass = _mass
	charge = _charge
	nick = _nick
	pattern = _pattern
	description = _description

func _to_string() -> String:
	if nick != "": return nick
	return name

static func fetch(subs_name : String) -> Substance:
	var result = _all.get(subs_name)
	if result == null:
		printerr("ERROR: Attempted to call upon a nonexistent substance")
		return new(
			subs_name,         #NAME
			0.2,               #MASS
			0,                 #CHARGE
			"",                #NICK
			"",                #PATTERN
			"Generated as a dummy - the sim attempted to call upon a nonexistent substance" #DESCRIPTION
		)
	return result

static func fetch_from_pattern(subs_pattern : String) -> Substance:
	var lambda = func(substance : Substance):
		return substance.pattern == subs_pattern
	var substances = _all.values()
	var index = substances.find_custom(lambda)
	if index == -1: return null
	return substances[index]

static func generate_basic():
	#fatty acids
	new(
		"z",         #NAME
		1.8,         #MASS
		0,           #CHARGE
		"LCFA",      #NICK - Long Chain Fatty Acid
		"FADIII"     #PATTERN
	)
	
	new(
		"y",         #NAME
		0.72,        #MASS
		0,           #CHARGE
		"MCFA",      #NICK - Long Chain Fatty Acid
		"FADII"      #PATTERN
	)
	new(
		"x",         #NAME
		0.26,        #MASS
		0,           #CHARGE
		"SCFA",      #NICK - Long Chain Fatty Acid
		"FADI"      #PATTERN
	)
	
	#ions
	new(
		"n",         #NAME
		0.22,        #MASS
		+1,          #CHARGE
		"Sodium",    #NICK
		"N"       #PATTERN
	)
	new(
		"k",         #NAME
		0.38,        #MASS
		+1,          #CHARGE
		"Potassium", #NICK
		"K"       #PATTERN
	)
	new(
		"l",         #NAME
		0.34,        #MASS
		-1,          #CHARGE
		"Chloride",  #NICK
		"C"       #PATTERN
	)
	new(
		"a",         #NAME
		0.4,         #MASS
		+1,          #CHARGE
		"Calcium",   #NICK
		"A"       #PATTERN
	)
	new(
		"p",         #NAME
		0.94,        #MASS
		-3,          #CHARGE
		"Phosphate" ,#NICK
		"P"       #PATTERN
	)
	new(
		"pzz",        #NAME
		4.54,         #MASS
		-3,           #CHARGE
		"Phospolipid",#NICK
		"PPLPD"       #PATTERN
	)
	
	#amino acids
	for i in 16:
		var letter = char(65 + i)
		new(
			letter,                                 #NAME
			0.35 + absf(1.4 - (float(i)/20)),       #MASS - rigged to range between 1 to 1.8
			((i+7) / 10)-1,                         #CHARGE - rigged to give 3 + and 3 - charged amino acids
			"Amino Acid " + letter,                 #NICK
			letter + letter + letter                #PATTERN
		)
	
	#nucleotides
	for i in 4:
		var letter = char(97 + i)
		new(
			letter,                                     #NAME
			1.3,                                        #MASS
			0,                                          #CHARGE
			"Nucleotide " + letter,                     #NICK
			char(65 + i) + char(67 + i) + char(69 + i), #PATTERN
		)
