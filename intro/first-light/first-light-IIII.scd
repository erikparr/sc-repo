(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

/* MELODIC PART 2 with Individual Note Playback */
(
~bpm = 298;
~stop = false;
~repetitions = 6;
~randomMode = false;
~currentMelodySetIndex = 0;
~currentCycle = 1;  // Track which cycle we're in

// Melody sets dictionary
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "First Set",
    patterns: [
        [70,65,63],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set2, (
    name: "Second Set",
    patterns: [
        [70,65,61]
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set3, (
    name: "Third Set",
    patterns: [
        [66,65,63]
            ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set4, (
    name: "Fourth Set",
    patterns: [
        [70,65,61],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set5, (
    name: "Fifth Set",
    patterns: [
        [61,58,54],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set6, (
    name: "Sixth Set",
    patterns: [
        [60,57,53],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
	));

~melodyDict.put(\set0b, (
    name: "First Set",
    patterns: [
        [70,65,61],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set1b, (
    name: "First Set",
    patterns: [
        [66,65,61],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set2b, (
    name: "Second Set",
    patterns: [
        [66,65,63]
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set3b, (
    name: "Third Set",
    patterns: [
        [65,63,61]
            ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set4b, (
    name: "Fourth Set",
    patterns: [
        [63,61,58],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set5b, (
    name: "Fifth Set",
    patterns: [
        [61,58,54],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set6b, (
    name: "Sixth Set",
    patterns: [
        [63,61,54],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set7b, (
    name: "Seventh Set",
    patterns: [
        [66,65,58],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));

// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Initial Cycle",
	// sequence: [\set1, \set1, \set2, \set2,\set3,\set3,\set4,\set4,\set5,\set5,\set6,\set6]  // A A B C A A A
    sequence: [\set1b, \set1b,\set1b, \set1b, \set2b, \set1b, \set1b,\set1b, \set1b,]  // A A B C D E A A A
));
~developmentCycles.put(2, (
    name: "Extended Cycle",
    sequence: [\set0b, \set0b, \set1b, \set1b, \set2b, \set3b, \set4b, \set5b, \set6b,  \set6b,\set7b,\set7b, \set1b, \set1b, \set1b]  // A A B C D E A A A
));
~developmentCycles.put(3, (
    name: "Full Cycle",
    sequence: [\set1, \set1, \set2, \set3, \set4, \set5, \set6, \set1, \set1, \set1]  // A A B C D E F G A A A
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
    var currentMelodySet;
    var trillNote = nil;
    var cycleCompletionCount = 0;
    var getNextMelodyIndex;
    var activeNotes;  // Dictionary to track active notes and their release times

    // Initialize
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    activeNotes = Dictionary.new;

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
        var now = Main.elapsedTime;  // Current time
        var releaseTime;  // When to release the current note

        // Get timing values from MIDI controller
        noteDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 0.75);
        restTime = ~midiController.sliderValues[2].linlin(0, 127, 0.0001, 0.5);
        temporalAccent = ~midiController.sliderValues[5].linlin(0, 127, 0.75, 2);
        velocity = ~midiController.sliderValues[3].linlin(0, 127, 0, 100);

        // Update tempo
        ts.setBPM(~midiController.sliderValues[0].linlin(0, 127, 60, 400));

        // Release any notes that have reached their duration
        activeNotes.keysValuesDo({ |note, releaseAt|
            if(releaseAt <= now) {
                if(note != trillNote) {  // Don't release trill notes
                    ~vstList.do { |item|
                        item.midi.noteOff(0, note, 0);
                    };
                };
                activeNotes.removeAt(note);
            };
        });

        // Check if we need to release trill note due to a lower note
        if(trillNote.notNil and: { currentNote < trillNote }) {
            ~vstList.do { |item|
                item.midi.noteOff(0, trillNote, 0);
            };
            trillNote = nil;
        };

        // Play current note and schedule its release
        ~vstList.do { |item|
            item.midi.noteOn(0, currentNote, velocity);
        };

        // Calculate when to release this note
        releaseTime = now + if(noteIndex == 0) {
            noteDuration * temporalAccent
        } {
            noteDuration
        };
        activeNotes.put(currentNote, releaseTime);

        // Handle trill mode
        if(currentMelodySet.trillMode.enabled
            and: { currentMelodySet.trillMode.index == noteIndex }
            and: { trillNote.isNil }) {
            trillNote = currentNote;
        };

        // Print current note info
        currentNote.post; " ".post;
        if(noteIndex == 0) {
            ["TEMPORAL ACCENT:", temporalAccent].postln;
        } {
            "".postln;
        };

        // Wait base duration before next note
        noteDuration.wait;
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
~repetitions = 6;  // Change number of repetitions
~stop = true;
(
10.do { |note, index|
	var vstKey = (\vsti ++ index).asSymbol;
	var vst = ~vstList[vstKey];

	if(vst.notNil) {
		vst.midi.allNotesOff(index);  // Stop any playing notes
	};
};
)

// Cycle control commands
~switchCycle.value(1);  // Switch to cycle 1
~switchCycle.value(2);  // Switch to cycle 2
~switchCycle.value(3);  // Switch to cycle 3
