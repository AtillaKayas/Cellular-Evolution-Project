class_name Nuclein

static var DEFAULT_BASES = ["a", "b", "c", "d"]
static var PROMOTER := "dcddbadb" #OPEN
static var TERMINATOR := "accddcddba" #CLOPE
static var _CODONS : Dictionary = { "aa": "A", "ab": "B", "ac": "C", "ad": "D", "ba": "E", "bb": "F", "bc": "G", "bd": "H", "ca": "I", "cb": "J", "cc": "K", "cd": "L", "da": "M", "db": "N", "dc": "O", "dd": "P" }
static var _REVERSE : Dictionary = { "A": "aa", "B": "ab", "C": "ac", "D": "ad", "E": "ba", "F": "bb", "G": "bc", "H": "bd", "I": "ca", "J": "cb", "K": "cc", "L": "cd", "M": "da", "N": "db", "O": "dc", "P": "dd" }
static var intron_regex : RegEx

var sequence : String
var introns : Dictionary[String, float]
var name : String

static func _static_init() -> void:
	intron_regex = RegEx.new()
	intron_regex.compile(PROMOTER + "(.*?)" + TERMINATOR)

func _init(nuclein_name : String, seq : String, recalculate : bool = true) -> void:
	name = nuclein_name
	sequence = seq
	
	if recalculate:
		recalculate_peptides()
	
func recalculate_peptides():
	introns.clear()
	#store all valid introns (peptide-making units)
	var results = intron_regex.search_all(sequence)
	for result in results:
		
		var string = result.get_string()
		var left = PROMOTER.length()
		var true_length = string.length() - (PROMOTER.length() + TERMINATOR.length())
		var intron = string.substr(left, true_length)
		if intron == "": continue
		
		var amount = introns.get_or_add(intron, 0)
		introns[intron] += amount


static func generate_basic():
	var nucleotides = ["a", "b", "c", "d"]
	_CODONS.clear()
	_REVERSE.clear()
	
	var x : int = 0
	for i in nucleotides:
		for ii in nucleotides:
			_CODONS[i + ii] = char(x + 65)
			_REVERSE[char(x + 65)] = i + ii
			x += 1

static func seq_to_pep(s : String) -> String:
	var result : String = ""
	for n in s.length()/2:
		var first = s[n*2]
		var sec = s[n*2+1]
		result += _CODONS.get(first + sec, "")
	return result

static func pep_to_seq(s : String) -> String:
	var result : String = ""
	for n in s:
		result += _REVERSE.get(n, "")
	return result
