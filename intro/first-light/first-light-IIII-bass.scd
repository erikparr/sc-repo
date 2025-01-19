//note: using settings from chord-bend-multi project dir

(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

41,46,49,53,54,58,60
46,54,61,65,66,70



/* MELODIC PART 2 with Individual Note Playback */
(
~bpm = 298;
~stop = false;
~repetitions = 2;
~randomMode = false;
~currentMelodySetIndex = 0;
~currentCycle = 1;  // Track which cycle we're in

// Melody sets dictionary
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "First Set",
    patterns: [
        [70,70,72,73,72,70],
		// [41,46,49,53,54,58,60,58,54,53,49,46,41],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set2, (
    name: "Second Set",
    patterns: [
        [65,65, 66, 73, 66,65]
		// [42, 46, 51, 53, 54, 58, 61, 58, 54, 53, 51, 46, 42]
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set3, (
    name: "Third Set",
    patterns: [
        [63,63,66,73,66,63]
//        [46,54,61,65,66,70,66,65,61,54,46]
            ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set4, (
    name: "Fourth Set",
    patterns: [
        [58,58,65,66,65]
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set5, (
    name: "Fifth Set",
    patterns: [
        [58,58,63,66,66,63]
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set6, (
    name: "Sixth Set",
    patterns: [
        [53,53,58,63,63,58]
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
// ~melodyDict.put(\set1, (
// 	name: "First Set",
// 	patterns: [
// 		[39,46,49,53,54,58,60,58,54,53,49,46,41],
// 		// [41,46,49,53,54,58,60,58,54,53,49,46,41],
// 	],
// 	trillMode: (
// 		enabled: false,
// 		index: 0
// 	)
// ));
// ~melodyDict.put(\set2, (
// 	name: "Second Set",
// 	patterns: [
// 		[39, 46, 51, 53, 54, 58, 61, 58, 54, 53, 51, 46, 42]
// 		// [42, 46, 51, 53, 54, 58, 61, 58, 54, 53, 51, 46, 42]
// 	],
// 	trillMode: (
// 		enabled: false,
// 		index: 0
// 	)
// ));
// ~melodyDict.put(\set3, (
// 	name: "Third Set",
// 	patterns: [
// 		[39,54,61,65,66,70,66,65,61,54,46]
// 		//        [46,54,61,65,66,70,66,65,61,54,46]
// 	],
// 	trillMode: (
// 		enabled: false,
// 		index: 0
// 	)
// ));
// ~melodyDict.put(\set4, (
// 	name: "Fourth Set",
// 	patterns: [
// 		[39, 46, 51, 53, 54, 58, 61, 58, 54, 53, 51, 46, 42]
// 	],
// 	trillMode: (
// 		enabled: false,
// 		index: nil
// 	)
// ));
// ~melodyDict.put(\set5, (
// 	name: "Fifth Set",
// 	patterns: [
// 		[39,46,49,53,54,58,60,58,54,53,49,46,41],
// 	],
// 	trillMode: (
// 		enabled: false,
// 		index: nil
// 	)
// ));
// ~melodyDict.put(\set6, (
// 	name: "Sixth Set",
// 	patterns: [
// 		[39,54,61,65,66,70,66,65,61,54,46]
// 	],
// 	trillMode: (
// 		enabled: false,
// 		index: nil
// 	)
// ));

// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Initial Cycle",
	sequence: [\set1, \set1, \set2, \set2,\set3,\set3,\set3,\set3, \set4, \set4,\set5,\set5,\set6,\set6,\set6,\set6,\set6,\set6]  // A A B C A A A
));
~developmentCycles.put(2, (
    name: "Extended Cycle",
    sequence: [\set1, \set1, \set2, \set2,\set3,\set3, \set4, \set5, \set6]  // A A B C A A A
));
~developmentCycles.put(3, (
    name: "Full Cycle",
    sequence: [\set1, \set1, \set2, \set2,\set3,\set3, \set4, \set5, \set6]  // A A B C A A A
));

// Helper function to switch cycles
~switchCycle = { |cycleNumber|
    if(~developmentCycles.includesKey(cycleNumber)) {
        ~currentCycle = cycleNumber;
        ~currentSequence = ~developmentCycles[cycleNumber].sequence;
        ~currentMelodySetIndex = 0;
        ["Switching to cycle:", ~developmentCycles[cycleNumber].name].postln;
        ["Sequence:", ~currentSequence.collect({ |key| ~melodyDict[key].name })].postln;
    } {
        "Invalid cycle number".postln;
    };
};

// Helper function to advance to next cycle
~advanceCycle = {
    var nextCycle = ~currentCycle + 1;
    if(~developmentCycles.includesKey(nextCycle)) {
        ~switchCycle.value(nextCycle);
        ["Advancing to cycle:", nextCycle].postln;
    } {
        ["Staying in final cycle:", ~currentCycle].postln;
    };
};

~sketch = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var noteDuration = 0, restTime = 0;
    var currentNote = 0;
    var noteIndex = 0;
    var melodyIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;
    var temporalAccent;
    var velocity;
    var accentedDuration;
    var currentMelodySet;
    var trillNote = nil;
    var cycleCompletionCount = 0;
    var getNextMelodyIndex;  // Declare the function variable here
    var firstNoteDuration = 0;  // Add the new variable for first note duration

    // Initialize with first cycle
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;

    // Define the function after declaring it
    getNextMelodyIndex = {
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
    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
    currentMelodyList = currentMelodySet.patterns;
    currentNote = currentMelodyList[melodyIndex][noteIndex];
    0.25.wait;

    loop({
        // Get timing values from MIDI controller
        noteDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 0.75);
        restTime = ~midiController.sliderValues[2].linlin(0, 127, 0.01, 0.5);
        temporalAccent = ~midiController.sliderValues[5].linlin(0, 127, 0.75, 1.5);
        velocity = ~midiController.sliderValues[3].linlin(0, 127, 0, 100);
        firstNoteDuration = ~midiController.sliderValues[6].linlin(0, 127, 0.1, 2.0);  // 0.1 to 2 seconds for first note

        // Update tempo
        ts.setBPM(~midiController.sliderValues[0].linlin(0, 127, 60, 400));

        // Check if we need to release trill note due to a lower note
        if(trillNote.notNil and: { currentNote < trillNote }) {
            ~vstList.do { |item|
                item.midi.noteOff(0, trillNote, 0);
            };
            trillNote = nil;
        };

        // Play current single note
        ~vstList.do { |item|
            item.midi.noteOn(0, currentNote, velocity);
        };

        // Handle trill mode
        if(currentMelodySet.trillMode.enabled
            and: { currentMelodySet.trillMode.index == noteIndex }
            and: { trillNote.isNil }) {
            trillNote = currentNote;
        };

        currentNote.post; " ".post;
        if(noteIndex == 0) {
            ["TEMPORAL ACCENT:", temporalAccent].postln;
            ["First Note Duration:", firstNoteDuration].postln;
        } {
            "".postln;
        };

        // Apply duration based on note position
        accentedDuration = if(noteIndex == 0) {
            firstNoteDuration  // Use the special first note duration
        } {
            noteDuration  // Use regular note duration for other notes
        };

        postf("note duration: % (first note: %)\n", accentedDuration, if(noteIndex == 0) { "yes" } { "no" });
        accentedDuration.wait;

        // Release current note only if it's not the trill note
        if(currentNote != trillNote) {
            ~vstList.do { |item|
                item.midi.noteOff(0, currentNote, 0);
            };
        };

        restTime.wait;

        // Advance to next note in current melody
        noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

        // If we've completed the current melody
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if (repetitionCount >= ~repetitions) {
                repetitionCount = 0;
                melodyIndex = getNextMelodyIndex.value;

                // If we've completed all melodies in current set, move to next set in sequence
                if(melodyIndex == 0) {
                    // Release any existing trill note before changing sets
                    if(trillNote.notNil) {
                        ~vstList.do { |item|
                            item.midi.noteOff(0, trillNote, 0);
                        };
                        trillNote = nil;
                    };

                    ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~currentSequence.size;

                    // Check if we've completed a full cycle
                    if(~currentMelodySetIndex == 0) {
                        cycleCompletionCount = cycleCompletionCount + 1;
                        ["Completed cycle", ~currentCycle, cycleCompletionCount, "times"].postln;

                        // After completing the cycle twice, advance to next cycle
                        if(cycleCompletionCount >= 2) {
                            cycleCompletionCount = 0;
                            ~advanceCycle.value;
                        };
                    };

                    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
                    currentMelodyList = currentMelodySet.patterns;
                    ["Current melody set:", currentMelodySet.name].postln;
                }
            }
        };

        currentNote = currentMelodyList[melodyIndex][noteIndex];
        ts.advance;

        // Print time signature state
        ts.printCurrentTime;

        // Print additional context for important time signature events
        if(ts.isFirstBeatInBarAndMeasure) {
            "=== NEW BAR ===".postln;
        };

        if(ts.isFirstBeatInMeasure) {
            "--- NEW MEASURE ---".postln;
        };

        if(~stop == true) {
            // Make sure to release trill note when stopping
            if(trillNote.notNil) {
                ~vstList.do { |item|
                    item.midi.noteOff(0, trillNote, 0);
                };
            };
            ~sketch.stop;
        };
    });
});
)

// Control commands
~sketch.play;
~repetitions = 1;  // Change number of repetitions
~stop = true;

// Cycle control commands
~switchCycle.value(1);  // Switch to cycle 1
~switchCycle.value(2);  // Switch to cycle 2
~switchCycle.value(3);  // Switch to cycle 3
