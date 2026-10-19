class_name Substance

enum {NICK, MASS, VOLUME, CHARGE, PATTERN}

var name : String
var nick : String
var mass : float #g/mol
var charge : int
var formation_energy : float #kJ/mol
var description : String

var pattern : String

static var _all : Dictionary[String, Substance]

func _init(_name : String, _mass : float, _charge : int, _formation : float = 0, _nick : String = "", _pattern : String = "", _description : String = ""):
	_all[_name] = self
	name = _name
	mass = _mass
	charge = _charge
	formation_energy = _formation
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
			20,                #MASS
			0,                 #CHARGE
			0,
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
		180,         #MASS
		0,           #CHARGE
		0,           #Standard Gibbs free energy of formation
		"LCFA",      #NICK - Long Chain Fatty Acid
		"FADIII",    #PATTERN
	)
	
	new(
		"y",         #NAME
		72,        #MASS
		0,           #CHARGE
		0,           #Standard Gibbs free energy of formation
		"MCFA",      #NICK - Medium Chain Fatty Acid
		"FADII"      #PATTERN
	)
	new(
		"x",         #NAME
		26,        #MASS
		0,           #CHARGE
		0,           #Standard Gibbs free energy of formation
		"SCFA",      #NICK - Short Chain Fatty Acid
		"FADI"      #PATTERN
	)
	
	#ions
	new(
		"n",         #NAME
		22,        #MASS
		+1,          #CHARGE
		0,           #Standard Gibbs free energy of formation
		"Sodium",    #NICK
		"N"       #PATTERN
	)
	new(
		"k",         #NAME
		38,        #MASS
		+1,          #CHARGE
		0,           #Standard Gibbs free energy of formation
		"Potassium", #NICK
		"K"       #PATTERN
	)
	new(
		"l",         #NAME
		34,        #MASS
		-1,          #CHARGE
		0,           #Standard Gibbs free energy of formation
		"Chloride",  #NICK
		"C"       #PATTERN
	)
	new(
		"a",         #NAME
		40,         #MASS
		+1,          #CHARGE
		0,           #Standard Gibbs free energy of formation
		"Calcium",   #NICK
		"A"       #PATTERN
	)
	new(
		"p",         #NAME
		96,          #MASS
		-3,          #CHARGE
		-1060,       #Standard Gibbs free energy of formation
		"Inorganic Phosphate" ,#NICK
		"F"          #PATTERN
	)
	new(
		"pzz",        #NAME
		454,          #MASS
		-3,           #CHARGE
		0,            #Standard Gibbs free energy of formation
		"Phospolipid",#NICK
		"PPLPD"       #PATTERN
	)
	new(
		"app",        #NAME
		427,          #MASS
		-3,           #CHARGE
		-1906,        #Standard Gibbs free energy of formation
		"ADP",        #NICK
		"ABB"         #PATTERN
	)
	new(
		"appp",       #NAME
		507,          #MASS
		-4,           #CHARGE
		-2102.88,     #Standard Gibbs free energy of formation
		"ATP",        #NICK
		"ABBB"        #PATTERN
	)
	new(
		"g",          #NAME
		180,          #MASS
		0,            #CHARGE
		-910,        #Standard Gibbs free energy of formation
		"Glucose",    #NICK
		"G"        #PATTERN
	)
	new(
		"h",          #NAME
		90,           #MASS
		0,            #CHARGE
		-497,         #Standard Gibbs free energy of formation
		"Pyruvate",   #NICK
		"GOANO"       #PATTERN
	)
	new(
		"gp",         #NAME
		88,           #MASS
		0,            #CHARGE
		-1123.58,         #Standard Gibbs free energy of formation
		"Glucose-6-Phosphate",   #NICK
		"GB"       #PATTERN
	)
	
	#amino acids
	for i in 16:
		var letter = char(65 + i)
		new(
			letter,                                 #NAME
			35   + absf(140 - (float(i)/0.2)),       #MASS - rigged to range between 1 to 1.8
			(i % 3)-1,                              #CHARGE
			-305,           #Standard Gibbs free energy of formation
			"Amino Acid " + letter,                 #NICK
			letter + letter + letter                #PATTERN
		)
	
	#nucleotides
	for i in 4:
		var letter = char(97 + i)
		new(
			letter,                                     #NAME
			130,                                        #MASS
			0,                                          #CHARGE
			-305,           #Standard Gibbs free energy of formation
			"Nucleotide " + letter,                     #NICK
			char(65 + i) + char(67 + i) + char(69 + i), #PATTERN
		)
	
	for n in Peptide.DEFAULT_AMINOS:
		var amino = Substance.fetch(n)
		if amino == null: continue
		Peptide.AMINO_POOL.append(amino)
