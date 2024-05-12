
(
// increasing tempo
~state = Task({
	var index = 0;
	var waitEnv = Env([1,0.1,1],[10,10], \sin);
	var durTend = Pfunc({arg timeIn = 0;
		Tendency.new(
			Env([0.1,0.2],[10], \sin),
			Env([0.05,0.1],[10], \sin), defDist:\betaRand).at(timeIn)
	}).asStream;

	var	duration = 20;
	var startTime = Main.elapsedTime;
	0.25.wait;
	loop({
		var now = Main.elapsedTime - startTime;
		var waittime = 0.25;
		if(~chordList.size > 1){
			// first turn the note on
			~vsti.midi.noteOn(index, ~chordList[~chordList.size-1].choose, 100);
		};

		waittime.wait;
		// ~vsti.midi.noteOff(0, currentNotes, 0);
	});
});

)
~state.play
~state.stop

(
// Function to slightly modify the chord order in ~chordList
~shuffleSlightly = {
	var chord = ~chordList[~chordList.size - 1];
	var idx1, idx2, temp;
	// Simple swap logic to slightly change the order
	idx1 = chord.size.rand;
	idx2 = (idx1 + 1 + chord.size.rand(chord.size - 1)) % chord.size; // Ensure idx2 is different
	// Swap the two notes
	temp = chord[idx1];
	chord[idx1] = chord[idx2];
	chord[idx2] = temp;
	~chordList[~chordList.size - 1] = chord; // Update the chord list with the slightly shuffled chord
};

// Define the task for playing notes with evolving order
~state = Task({
	var index = 0;
	var cycleIndex = 0; // Index to track the current note in the cycle
	var chordSize; // To keep track of the size of the current chord
	var waittime = 0.25; // Fixed duration between notes

	// Initialize with a slight shuffle to start
	~shuffleSlightly.value;
	chordSize = ~chordList[~chordList.size - 1].size; // Get the size of the shuffled chord

	"chord: ".post;
	~chordList[~chordList.size - 1].postln;

	loop {
		if (~chordList.size > 1) {
			var chord = ~chordList[~chordList.size - 1];
			var note = chord[cycleIndex]; // Sequentially select the next note in the chord
			if(note.isNil == false){
				~vsti.midi.noteOn(index, note, 100); // Trigger the noteOn event
				" %".format(note).post;
			};
			cycleIndex = cycleIndex + 1;

			if (cycleIndex >= chordSize) { // Check if we've reached the end of the current cycle
				"".postln;
				~shuffleSlightly.value; // Slightly shuffle the chord for the next cycle
				cycleIndex = 0; // Reset cycle index for the new cycle
				chordSize = ~chordList[~chordList.size - 1].size; // Update the chord size in case it changes
			}
		};

		waittime.wait; // Wait for 0.25 seconds before the next iteration
	};
});

)


~state.play
~state.stop