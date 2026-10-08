class_name Nuclein

static var PROMOTER := "dddaaaddd"
static var TERMINATOR := "ddddddddd"
static var _CODONS : Dictionary
static var _REVERSE : Dictionary
static var _intron_regex : RegEx

var sequence : String
var introns : Dictionary[String, float]
var nick : String = ""

static func _static_init() -> void:
	_intron_regex = RegEx.new()
	_intron_regex.compile(PROMOTER + "(.*?)" + TERMINATOR)

func _init(seq : String, nick : String = "") -> void:
	sequence = seq
	self.nick = nick
	
	
	#store all valid introns (peptide-making units)
	var results = _intron_regex.search_all(sequence)
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
