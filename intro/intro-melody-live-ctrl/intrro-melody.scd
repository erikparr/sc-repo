(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;


/* MELODIC PART 1*/
(
~bpm = 298;
~stop = false;
~chordIndex = 0;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var resttime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[73], [69], [66], [73], [76], [69]];
	var chordList1 = [[72], [69], [64]];
	var arpegList = [chordList, chordList1];
	var nextChordsSet = chordList;
	var currentNotes = nextChordsSet[0];
	/*time*/
	var bpmOffset = Env([-200, 0, -200],[7, 7], \sin);
	var	duration = 20;
	var barIndex = 1;
	var beatIndex = 1;
	var measureIndex = 1;
	var noteIndex = 0;
	var chordIndex = 0;
	var arpegIndex = 0;
	var startTime = Main.elapsedTime;

	~stop = false;
	0.25.wait;
	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlLow1, \end, ctrlHi1, \dur, duration ]);
	loop({
		var now = Main.elapsedTime - startTime;
		var bpm = ~midiController.sliderValues[0].linlin(0, 127, 60, 400); // + bpmOffset.at(now);
		ts.setBPM(bpm);
		// (bpm).postln;
		resttime = 	~midiController.sliderValues[1].linlin(0, 127, 0.025, 0.35);
		waittime = 	~midiController.sliderValues[2].linlin(0, 127, 0.001, 0.25);
		if(waittime == 1.0){waittime = 10};
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOn(0, note, ~midiController.sliderValues[3].linlin(0, 127, 0, 100)); };
			note.post; " ".post;
		};
		"".postln;
		// if (now >= duration) {
		// 	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlHi1, \end, ctrlLow1, \dur, duration ]);
		// 	now = now - duration;
		// 	startTime = Main.elapsedTime - now;
		// 	//switch chords
		// 	nextChordsSet = if(nextChordsSet == chordList1) { chordList } { chordList1 };
		// 	"repeat".postln;
		// 	// currentNotes = if(currentNotes == notes1) { notes2 } { notes1 };
		// };



		postf(" waiting %\n ", waittime);
		resttime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%(nextChordsSet.size);
		currentNotes = nextChordsSet[noteIndex];
		postf(" nextChordsSet index: %\n ", noteIndex);

		if(ts.measure != measureIndex){
			// chordIndex = (chordIndex+1)%nextArpegSet.size;
			// nextChordsSet = nextArpegSet[chordIndex];
		};
		// postf(" nextArpegSet index: %\n ", chordIndex);

		if(ts.bar%2 == 0){
			chordIndex = (chordIndex+1)%arpegList.size;
			// 	nextChordsSet = nextArpegSet[chordIndex];

		};
		// postf(" arpegList index: %\n ", arpegIndex);
		waittime.wait;
		nextChordsSet = arpegList[~chordIndex]; // control index manually
		beatIndex = ts.beat;
		measureIndex = ts.measure;
		barIndex = ts.bar;

		ts.advance;


		// currentNotes = if(currentNotes == nextChordsSet[0]) { nextChordsSet[1] } { nextChordsSet[0] };
		if(~stop == true){
			~burst.stop;
		};
	});
});
)
~burst.play;
~stop = true;
~burst.stop;
~stop = false;




/* MELODIC PART 2*/
(
~bpm = 298;
~stop = false;
~chordIndex = 0;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var resttime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[73], [69], [66], [73], [76], [69]];
	var chordList1 = [[72], [69], [64]];
	var arpegList = [chordList, chordList1];
	var nextChordsSet = chordList;
	var currentNotes = nextChordsSet[0];
	/*time*/
	var bpmOffset = Env([-200, 0, -200],[7, 7], \sin);
	var	duration = 20;
	var barIndex = 1;
	var beatIndex = 1;
	var measureIndex = 1;
	var noteIndex = 0;
	var chordIndex = 0;
	var arpegIndex = 0;
	var startTime = Main.elapsedTime;

	~stop = false;
	0.25.wait;
	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlLow1, \end, ctrlHi1, \dur, duration ]);
	loop({
		var now = Main.elapsedTime - startTime;
		var bpm = ~midiController.sliderValues[0].linlin(0, 127, 60, 400); // + bpmOffset.at(now);
		ts.setBPM(bpm);
		// (bpm).postln;
		resttime = 	~midiController.sliderValues[1].linlin(0, 127, 0.025, 0.35);
		waittime = 	~midiController.sliderValues[2].linlin(0, 127, 0.001, 0.25);
		if(waittime == 1.0){waittime = 10};
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOn(0, note, ~midiController.sliderValues[3].linlin(0, 127, 0, 100)); };
			note.post; " ".post;
		};
		"".postln;
		// if (now >= duration) {
		// 	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlHi1, \end, ctrlLow1, \dur, duration ]);
		// 	now = now - duration;
		// 	startTime = Main.elapsedTime - now;
		// 	//switch chords
		// 	nextChordsSet = if(nextChordsSet == chordList1) { chordList } { chordList1 };
		// 	"repeat".postln;
		// 	// currentNotes = if(currentNotes == notes1) { notes2 } { notes1 };
		// };



		postf(" waiting %\n ", waittime);
		resttime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%(nextChordsSet.size);
		currentNotes = nextChordsSet[noteIndex];
		postf(" nextChordsSet index: %\n ", noteIndex);

		if(ts.measure != measureIndex){
			// chordIndex = (chordIndex+1)%nextArpegSet.size;
			// nextChordsSet = nextArpegSet[chordIndex];
		};
		// postf(" nextArpegSet index: %\n ", chordIndex);

		if(ts.bar%2 == 0){
			chordIndex = (chordIndex+1)%arpegList.size;
			// 	nextChordsSet = nextArpegSet[chordIndex];

		};
		// postf(" arpegList index: %\n ", arpegIndex);
		waittime.wait;
		nextChordsSet = arpegList[~chordIndex]; // control index manually
		beatIndex = ts.beat;
		measureIndex = ts.measure;
		barIndex = ts.bar;

		ts.advance;


		// currentNotes = if(currentNotes == nextChordsSet[0]) { nextChordsSet[1] } { nextChordsSet[0] };
		if(~stop == true){
			~burst.stop;
		};
	});
});
)
~burst.play;
~stop = true;
~burst.stop;
~stop = false;



/* MELODIC PART 2 with Repetition and Random Mode */
(
~bpm = 298;
~stop = false;
~repetitions = 2; // Default number of times to repeat each melody
~randomMode = false; // When true, selects next melody randomly

~burst = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var waittime, resttime;
    var chordList = [
        [[69, 65], [60]],
        [[66, 65], [61]],
        [[70, 66], [63]],
        [[63, 60], [58]],
        [[60, 57], [53]]
    ];
    var currentNotes;
    var noteIndex = 0;
    var melodyIndex = 0;
    var repetitionCount = 0;

    // Helper function to get next melody index
    var getNextMelodyIndex = {
        if(~randomMode) {
            var currentIndex = melodyIndex;
            // Ensure we don't pick the same melody twice
            while({
                melodyIndex = chordList.size.rand;
                melodyIndex == currentIndex;
            });
            melodyIndex;
        } {
            (melodyIndex + 1) % chordList.size;
        };
    };

    ~stop = false;
    currentNotes = chordList[melodyIndex][noteIndex];
    0.25.wait;

    loop({
        // Get timing values from MIDI controller
        resttime = ~midiController.sliderValues[1].linlin(0, 127, 0.025, 0.35);
        waittime = ~midiController.sliderValues[2].linlin(0, 127, 0.001, 0.25);
        if(waittime == 1.0) { waittime = 10 };

        // Update tempo
        ts.setBPM(~midiController.sliderValues[0].linlin(0, 127, 60, 400));

        // Play current notes
        currentNotes.do { |note|
            ~vstList.do { |item|
                item.midi.noteOn(0, note, ~midiController.sliderValues[3].linlin(0, 127, 0, 100));
            };
            note.post;
            " ".post;
        };
        "".postln;

        // Wait and release notes
        postf("waiting %\n", waittime);
        resttime.wait;

        currentNotes.do { |note|
            ~vstList.do { |item|
                item.midi.noteOff(0, note, 0);
            };
        };

        // Advance to next note pair in current melody
        noteIndex = (noteIndex + 1) % (chordList[melodyIndex].size);
        currentNotes = chordList[melodyIndex][noteIndex];

        // Handle melody repetition and progression
        if (noteIndex == 0) {
            repetitionCount = repetitionCount + 1;

            if (repetitionCount >= ~repetitions) {
                melodyIndex = getNextMelodyIndex.value;
                repetitionCount = 0;
                ["Switching to melody", melodyIndex, if(~randomMode) {"(random)"} {"(sequential)"}].postln;
            } {
                ["Repetition", repetitionCount, "of melody", melodyIndex].postln;
            };
        };

        waittime.wait;
        ts.advance;

        if(~stop) { ~burst.stop };
    });
});
)

// Control commands
~repetitions = 24;  // Change number of repetitions
~burst.play;
~randomMode = true;  // Enable random melody selection
~randomMode = false; // Return to sequential melody selection
~stop = true;
~burst.stop;
~stop = false;



/* MELODIC PART 2 with Individual Note Playback */
(
~bpm = 298;
~stop = false;
~repetitions = 2; // Default number of times to repeat each melody
~randomMode = false; // When true, selects next melody randomly
~currentMelodySetIndex = 0; // Control which melody set is active

~melodySet1 = [
    [53, 54, 58, 61],  // First melody as individual notes
    [53, 54, 58, 63]   // Second melody as individual notes
];

~melodySet2 = [
    [53, 54, 58, 63],   // Second melody as individual notes
    [54, 58, 63, 65]
];

~melodySet3 = [
    [54, 58, 63, 65],
    [65, 63, 65, 70]
];

~allMelodySets = [~melodySet1, ~melodySet2, ~melodySet3];

~burst = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var waittime = 0, resttime = 0;
    var currentNote = 0;
    var noteIndex = 0;
    var melodyIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;

    // Helper function to get next melody index
    var getNextMelodyIndex = {
        if(~randomMode) {
            var currentIndex = melodyIndex;
            while({
                melodyIndex = currentMelodyList.size.rand;
                melodyIndex == currentIndex;
            });
            melodyIndex;
        } {
            (melodyIndex + 1) % currentMelodyList.size;
        };
    };

    ~stop = false;
    currentMelodyList = ~allMelodySets[~currentMelodySetIndex];
    currentNote = currentMelodyList[melodyIndex][noteIndex];
    0.25.wait;

    loop({
        // Get timing values from MIDI controller
        resttime = ~midiController.sliderValues[1].linlin(0, 127, 0.025, 0.35);
        waittime = ~midiController.sliderValues[2].linlin(0, 127, 0.001, 0.25);
        if(waittime == 1.0) { waittime = 10 };

        // Update tempo
        ts.setBPM(~midiController.sliderValues[0].linlin(0, 127, 60, 400));

        // Play current single note
        ~vstList.do { |item|
            item.midi.noteOn(0, currentNote, ~midiController.sliderValues[3].linlin(0, 127, 0, 100));
        };
        currentNote.post; " ".post;
        "".postln;

        // Wait and release note
        postf("waiting %\n", waittime);
        resttime.wait;

        // Release current note
        ~vstList.do { |item|
            item.midi.noteOff(0, currentNote, 0);
        };

        // Advance to next note in current melody
        noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

        // If we've completed the current melody
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if (repetitionCount >= ~repetitions) {
                repetitionCount = 0;
                melodyIndex = getNextMelodyIndex.value;

                // If we've completed all melodies in the current set, check if we need to switch sets
                if(melodyIndex == 0) {
                    currentMelodyList = ~allMelodySets[~currentMelodySetIndex];
                    ["Current melody set:", ~currentMelodySetIndex + 1].postln;
                }
            }
        };

        currentNote = currentMelodyList[melodyIndex][noteIndex];
        waittime.wait;
        ts.advance;

        if(~stop == true) {
            ~burst.stop;
        };
    });
});
)

// Control commands
~burst.play;
~repetitions = 2;  // Change number of repetitions
~randomMode = true;  // Enable random melody selection
~randomMode = false; // Return to sequential melody selection
~burst.stop;
~switchToNextMelodySet.value;  // Go to next set
~switchToMelodySet.value(0);   // Switch to first set (0-2)

// New commands for switching melody sets
~switchToNextMelodySet = {
    ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~allMelodySets.size;
    ["Switching to melody set", ~currentMelodySetIndex + 1, "on next cycle"].postln;
};

~switchToMelodySet = { |setIndex|
    if(setIndex >= 0 and: { setIndex < ~allMelodySets.size }) {
        ~currentMelodySetIndex = setIndex;
        ["Switching to melody set", setIndex + 1, "on next cycle"].postln;
    } {
        "Invalid melody set index".postln;
    };
};
