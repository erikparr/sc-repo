
// play a list of notes (chords) as note sequences in a repeating pattern
// repeating pattern is slightly altered each cycle
(
var notes1 = [53,57,60,64,69];
var notes1b = [48,53,60,64,69];
var notes1c = [45,48,60,64,69];
var notes2 = [50,53,60,64,71];
var notes2b = [50,53,62,67];
var notes3 = [52, 55, 59, 67, 72];
var notes4 = [52,59,65,74];
var notes5 = [55,53,59,64];
var notes6 = [46,51,55,60,67];
var notes7 = [45,52,55];
// var notes8 = [41,48,52];
var notes8 = [43,55,59,60,64];
var notes9 = [43,55,56,60,63];
var ascend1 = [45,50,65,72];
var ascend2 = [47,50,65,76];
var bridge1 = [35,38,53,64];
var ts = TimeSignature(5,8);
~chordList = [notes1,notes2,notes1,notes2,notes1b,notes2,notes1c,notes1,notes2b,notes1b,notes2,notes1c,notes1,notes2b,notes1b,notes2,ascend1,ascend2,bridge1];

// increasing tempo
~state = Task({
	var index = 0;
	var waitEnv = Env([0.25],[10], \sin);
	var durTend = Pfunc({arg timeIn = 0;
		Tendency.new(
			Env([0.1,0.2],[10], \sin),
			Env([0.05,0.1],[10], \sin), defDist:\betaRand).at(timeIn)
	}).asStream;

	var	duration = 20;
	var startTime = Main.elapsedTime;
	var currentPattern, patternIndex, pitch=0;

	~updateEvolvingPattern = {
		~evolvingPattern = if(~chordList.size > 0, {
			var lastChordSize = ~chordList[0].size;
			var indices = (0..(lastChordSize - 1)).scramble; // Scramble indices for variation
			Pseq(indices, inf) // Create a repeating pattern of indices
		}, {
			Pseq([0], inf) // Default pattern to avoid errors
		});
	};


	0.25.wait;
	~updateEvolvingPattern.value(); // Update the evolving pattern based on the new chord list
	currentPattern = ~evolvingPattern.value.asStream; // Convert pattern to stream for iteration

	loop({
		var now = Main.elapsedTime - startTime;
		var waittime = 0.125;

		~chordList[0].do{arg note, i;
			patternIndex = currentPattern.next; // Retrieve the next index from the pattern stream
			pitch = ~chordList[0][patternIndex]; // Use the pattern index to select the note

			pitch.post;
			" ".post;
			// first turn the note on
			~vsti.midi.noteOn(i, pitch, 100);
			// Synth(\BendEnvelope1, [ \gate, 1, \chanIndex, index, \start, 0, \end, 8192, \dur, 10 ]);

			// ~vsti.midi.noteOff(0, currentNotes, 0);
		};

		waittime.wait;
		if(ts.beat==ts.numerator){
			".".postln;
			~chordList[0].do {|note, index| ~vsti.midi.noteOff(index, note, 0); };
		};
		~updateEvolvingPattern.value(); // Update the evolving pattern based on the new chord list
		currentPattern = ~evolvingPattern.value.asStream; // Convert pattern to stream for iteration

		index = (index + 1)%~chordList[~chordList.size-1].size;
		ts.printCurrentTime;
		ts.advance;

	});
});

)
~state.play
~state.stop
