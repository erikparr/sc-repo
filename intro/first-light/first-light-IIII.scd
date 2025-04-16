(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;



(
// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;

// OSC responder for note events with debug printing
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;

    ["OSC Received:", "channel:", channel, "note:", note, "vel:", velocity, "dur:", duration].postln;

    // Play the note on all VST instances
    ~vstList.do { |item, index|
        ["Playing on VST:", index].postln;
        item.midi.noteOn(index, note, velocity);

        // Schedule note release
        SystemClock.sched(duration, {
            ["Releasing note:", note, "on channel:", index].postln;
            item.midi.noteOff(index, note, 0);
            nil;
        });
    };
}, '/note/on');

/* MELODIC PART 2 with Individual Note Playback */
~bpm = 298;
~stop = false;
~repetitions = 6;
~randomMode = false;
~melodyRestMode = true;  // Toggle for longer rests between melodies
~currentMelodySetIndex = 0;
~currentCycle = 2;  // Track which cycle we're in

// Melody sets dictionary
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "I A",
    patterns: [
        [70,65,63],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set2, (
    name: "II A",
    patterns: [
        [70,65,61]
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set3, (
    name: "III A",
    patterns: [
        [66,65,63]
            ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set4, (
    name: "IV A",
    patterns: [
        [70,65,61],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set5, (
    name: "V A",
    patterns: [
        [61,58,54],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set6, (
    name: "VI A",
    patterns: [
        [60,57,53],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
	));

~melodyDict.put(\set0b, (
    name: "I B",
    patterns: [
        [70,65,61],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set1b, (
    name: "II B",
    patterns: [
        [66,65,61],
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set2b, (
    name: "II B",
    patterns: [
        [66,65,63]
    ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set3b, (
    name: "III B",
    patterns: [
        [65,63,61]
            ],
    trillMode: (
        enabled: false,
        index: 0
    )
));
~melodyDict.put(\set4b, (
    name: "IV B",
    patterns: [
        [63,61,58],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set5b, (
    name: "V B",
    patterns: [
        [61,58,54],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set6b, (
    name: "VI B",
    patterns: [
        [63,61,54],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set7b, (
    name: "VII B",
    patterns: [
        [66,65,58],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set8b, (
    name: "VIII B",
    patterns: [
        [70,66,65],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));
~melodyDict.put(\set9b, (
    name: "IX B",
    patterns: [
        [73,70,65],
    ],
    trillMode: (
        enabled: false,
        index: nil
    )
));

// set I C
~melodyDict.put(\set0c, (
    name: "I C",
    patterns: [
        [61,60,58],
    ],
));

// set II C
~melodyDict.put(\set1c, (
    name: "II C",
    patterns: [
        [65, 60, 57],
    ],
));

// set III C
~melodyDict.put(\set2c, (
    name: "III C",
    patterns: [
        [66, 60, 58],
    ],
));

// set I D
~melodyDict.put(\set0d, (
    name: "I D",
    patterns: [
        [70, 65, 61],
    ],
));

// set II D
~melodyDict.put(\set1d, (
    name: "II D",
    patterns: [
        [73, 65, 63],
    ],
));

// set III D
~melodyDict.put(\set2d, (
    name: "III D",
    patterns: [
        [73,66,63],
    ],
));

// set IV D
~melodyDict.put(\set3d, (
    name: "IV D",
    patterns: [
        [72,65,60],
    ],
));

// set 0    E
~melodyDict.put(\set0e, (
    name: "I E",
    patterns: [
        [58, 54, 65, 63, 66],
    ],
));

// set 1 E
~melodyDict.put(\set1e, (
    name: "II E",
    patterns: [
        [61, 58, 65, 63, 66],
    ],
));


// set 2 E
~melodyDict.put(\set2e, (
    name: "III E",
    patterns: [
        [54, 65, 66, 58, 70],
    ],
));

// set 3 E
~melodyDict.put(\set3e, (
    name: "IV E",
    patterns: [
        [51, 65, 54, 63, 66],
    ],
));

// set 4 E
~melodyDict.put(\set4e, (
    name: "V E",
    patterns: [
        [51, 56, 65, 70],
    ],
));

// set 5 E
~melodyDict.put(\set5e, (
    name: "VI E",
    patterns: [
        [51, 54, 65, 70],
    ],
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
    sequence: [\set1b, \set1b, \set8b, \set1b, \set9b ]  // A A B C D E A A A
));
~developmentCycles.put(3, (
    name: "Full Cycle",
    sequence: [\set0c, \set1c, \set2c,\set1c, \set0c]  // A A B C D E F G A A A
));
//bridge
~developmentCycles.put(4, (
    name: "Extended Cycle",
    sequence: [\set3,\set3,\set3,\set3,\set3,\set3,\set1b, \set2b, \set3b, \set4b, \set5b, \set6b,  \set6b,\set7b,\set7b, \set1b, \set1b, \set1b]  // A A B C D E A A A
));

~developmentCycles.put(5, (
    name: "Extended Cycle",
    sequence: [\set0d, \set1d, \set2d, \set3d]  // A A B C D E A A A
));

~developmentCycles.put(6, (
    name: "Extended Cycle",
    sequence: [\set3, \set3, \set3, \set3,\set7b,\set7b,\set7b,\set7b, \set0d,  \set0d, \set1d,\set1d, \set2d, \set2d]  // A A B C D E A A A
));

// slow mode cycle
~developmentCycles.put(7, (
    name: "Slow Mode Cycle",
    sequence: [\set0e, \set1e, \set2e, \set3e, \set4e, \set5e]  // A A B C D E A A A
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
    var currentNote, noteIndex = 0, melodyIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;
    var currentMelodySet;
    var cycleCompletionCount = 0;

    // Initialize sequence
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
    currentMelodyList = currentMelodySet.patterns;
    currentNote = currentMelodyList[melodyIndex][noteIndex];

    loop({
        var noteDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 0.3);
        var noteRestTime = ~midiController.sliderValues[2].linlin(0, 127, 0.0001, 0.2);
        var melodyRestTime = ~midiController.sliderValues[6].linlin(0, 127, 0.5, 8.0);  // Using slider 6 for melody rest
        var temporalAccent = ~midiController.sliderValues[5].linlin(0, 127, 0.75, 2);
        var velocity = ~midiController.sliderValues[3].linlin(0, 127, 40, 127);
        var actualDuration;

        // Apply temporal accent to first note in pattern (noteIndex == 0)
        actualDuration = if(noteIndex == 0) {
            [
                "Applying accent to first note:",
                "Base Duration:", noteDuration,
                "Accent Multiplier:", temporalAccent,
                "Final Duration:", noteDuration * temporalAccent
            ].postln;
            noteDuration * temporalAccent
        } {
            noteDuration
        };

        // Send note event with debug info
        ["Playing note:", currentNote, "duration:", actualDuration, "noteIndex:", noteIndex].postln;
        NetAddr.localAddr.sendMsg('/note/on', 0, currentNote, velocity, actualDuration);

        // Wait for rest time before next note
        noteRestTime.wait;

        // Advance sequence
        noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

        // If we've completed the current pattern
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if(repetitionCount >= ~repetitions) {
                repetitionCount = 0;

                // If melody rest mode is enabled, wait between melodies
                if(~melodyRestMode) {
                    ["Taking a longer rest between melodies:", melodyRestTime, "seconds"].postln;
                    melodyRestTime.wait;
                };

                ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~currentSequence.size;

                if(~currentMelodySetIndex == 0) {
                    cycleCompletionCount = cycleCompletionCount + 1;
                    if(cycleCompletionCount >= 2) {
                        cycleCompletionCount = 0;
                        ~advanceCycle.value;
                    };
                };

                currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
                currentMelodyList = currentMelodySet.patterns;
                ["New Melody Set:", currentMelodySet.name, currentMelodyList[0]].postln;
            };
        };

        currentNote = currentMelodyList[melodyIndex][noteIndex];
        ts.advance;
        ts.printCurrentTime;

        if(~stop) { ~sketch.stop };
    });
});
)

// Control commands
/* RIFT SETTINGS: [ Duration:, 0.072, Rest:, 0.055,  ] */
/* RIFT SETTINGS: [ Duration:, 0.074, Rest:, 0.041  ] */
~sketch.play;
~repetitions = 1;  // Change number of repetitions
~stop = true;
~melodyRestMode = true;   // Enable melody rest mode
~melodyRestMode = false;  // Disable melody rest mode






(
10.do { |note, index|
	var vstKey = (\vsti ++ index).asSymbol;
	var vst = ~vstList[vstKey];

	if(vst.notNil) {
		vst.midi.allNotesOff(index);  // Stop any playing notes
	};
};
)
/*[ OSC Received:, channel:, 0, note:, 66, vel:, 126, dur:, 0.17522047460079 ]
*/
//slow mode:
/*[ OSC Received:, channel:, 0, note:, 70, vel:, 127, dur:, 0.066921256482601 */
// Cycle control commands
~switchCycle.value(1);  // Switch to cycle 1
~switchCycle.value(2);  // Switch to cycle 2
~switchCycle.value(3);  // Switch to cycle 3
~switchCycle.value(4);  // Switch to cycle 3
~switchCycle.value(5);  // Switch to cycle 3
~switchCycle.value(6);  // Switch to cycle 3
~switchCycle.value(7);  // Switch to cycle 3
~repetitions = 1000;  // Change number of repetitions
~repetitions = 5;  // Change number of repetitions
  ~sketch.play;
~stop = true;
