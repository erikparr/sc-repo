(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;
~sketch.play;
~stop = true;

/* CHORD PART with Individual Note Playback */
(
~bpm = 298;
~stop = false;
~repetitions = 6;
~randomMode = false;
~currentChordSetIndex = 0;
~currentCycle = 1;  // Track which cycle we're in

// Add these variables near the top where other globals are defined
~proceduralMode = true;  // Toggle for procedural vs MIDI control
~restTimeEnvs = [
    Env(
		[0.5,0.1,0.5],  // levels - from max to min rest time
		[5, 5],           // times in seconds
		\exp                         // curve
    ),
    Env(
        [0.5, 0.2, 0.5],       // different pattern
        [6, 4, 8],                   // different timing
        \exp
    ),
    Env(
		[0.5,0.1,0.5],  // levels - from max to min rest time
		[5, 5],           // times in seconds
		\exp                         // curve
    ),
    Env(
        [0.5, 0.2, 0.5],       // different pattern
        [6, 4, 8],                   // different timing
        \exp
    )
];


// First, define the CC envelopes
~ccEnvs = [
    Env(
        [0, 127, 0],     // levels - scaled from 0 to 127
		[5, 5],           // times in seconds
		\exp                         // curve
    ),
    Env(
        [0, 127, 0],     // levels - scaled from 0 to 127
        [6, 4, 8],                   // different timing
        \exp
    ),
    Env(
        [0, 127, 0],     // levels - scaled from 0 to 127
		[5, 5],           // times in seconds
		\exp                         // curve
    ),
    Env(
        [0, 127, 0],     // levels - scaled from 0 to 127
        [6, 4, 8],                   // different timing
        \exp
    )
];

~currentEnvIndex = 0;  // Track which envelope we're currently using

// Add these variables near the top with the other envelopes
~chordMinEnv = Env(
    [0.1, 0.02, 0.02],  // levels - min chord duration values
    [8,10000],                      // times in seconds
    \sine                           // curve type
);

// Chord sets dictionary
~chordDict = Dictionary.new;
~chordDict.put(\set1, (
    name: "First Set",
    patterns: [
        [78,82],
    ]
));
~chordDict.put(\set2, (
    name: "Second Set",
    patterns: [
        [77,81]
    ]
));
~chordDict.put(\set3, (
    name: "Third Set",
    patterns: [
        [73,75]
    ]
));
~chordDict.put(\set4, (
    name: "Fourth Set",
    patterns: [
        [73,82],
    ]
));
~chordDict.put(\set5, (
    name: "Fifth Set",
    patterns: [
        [78,82],
    ]
));
~chordDict.put(\set6, (
    name: "Sixth Set",
    patterns: [
        [78,82],
    ]
));

~chordDict.put(\set0b, (
    name: "First Set B",
    patterns: [
        [78,82],
    ]
));
~chordDict.put(\set1b, (
    name: "First Set B",
    patterns: [
        [78,82],
    ]
));
~chordDict.put(\set2b, (
    name: "Second Set B",
    patterns: [
        [72,78],
    ]
));
~chordDict.put(\set3b, (
    name: "Third Set B",
    patterns: [
        [72,78],
    ]
));
~chordDict.put(\set4b, (
    name: "Fourth Set B",
    patterns: [
        [72,78],
    ]
));
~chordDict.put(\set5b, (
    name: "Fifth Set B",
    patterns: [
        [72,78],
    ]
));
~chordDict.put(\set6b, (
    name: "Sixth Set B",
    patterns: [
        [63,61,54],
    ]
));
~chordDict.put(\set7b, (
    name: "Seventh Set B",
    patterns: [
        [66,65,58],
    ]
));

// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Initial Cycle",
    sequence: [\set1, \set2, \set1, \set2]
));

// Helper function to switch cycles
~switchCycle = { |cycleNumber|
    if(~developmentCycles.includesKey(cycleNumber)) {
        ~currentCycle = cycleNumber;
        ~currentSequence = ~developmentCycles[cycleNumber].sequence;
        ~currentChordSetIndex = 0;
        ["Switching to cycle:", ~developmentCycles[cycleNumber].name].postln;
        ["Sequence:", ~currentSequence.collect({ |key| ~chordDict[key].name })].postln;
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

// Control ranges with curve definitions
~controlRanges = (
    rest: (min: 0.1, max: 0.75, curve: 3),    // Exponential curve
    chord: (min: 0.016, max: 0.055, curve: -3),  // Inverse exponential
    tempo: (min: 60, max: 400, curve: 2),       // Quadratic curve
    velocity: (min: 0, max: 100, curve: 1),     // Linear (curve: 1)
);

~sketch = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var noteDuration = 0, restTime = 0;
    var currentChord;
    var chordIndex = 0;
    var repetitionCount = 0;
    var currentChordList;
    var velocity;
    var cycleCompletionCount = 0;
    var getNextChordIndex;
    var activeNotes;  // Dictionary to track active notes and their release times
    var calculateInverseRelationship;  // Declare the variable first
    var now, chordDuration, currentChordReleaseTime;  // Declare loop variables at the top
    var envStartTime = Main.elapsedTime;
    var lastLevel = nil;
    var lastChordLevel = nil;  // For chord envelope
    var currentEnv = ~restTimeEnvs[0];

    // Initialize envelope start time
    envStartTime = Main.elapsedTime;

    // Then define the function
    calculateInverseRelationship = { |value, inMin, inMax, outMin, outMax|
        var normalized;
        normalized = value.linlin(inMin, inMax, 0, 1);
        (1 - normalized).linlin(0, 1, outMin, outMax);
    };

    // Initialize
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    activeNotes = Dictionary.new;
    ["Current sequence:", ~currentSequence].postln;  // Debug point 2

    // Check if MIDI controller is initialized
    if(~midiController.isNil) {
        "WARNING: MIDI controller not initialized, using default values".postln;
        ~midiController = (
            sliderValues: Array.fill(8, 64)  // Default mid-range values
        );
    };

    // Define the function for getting next chord index
    getNextChordIndex = {
        if(~randomMode) {
            var currentIndex = chordIndex;
            while({
                chordIndex = currentChordList.size.rand;
                chordIndex == currentIndex;
            });
            chordIndex;
        } {
            (chordIndex + 1) % currentChordList.size;
        };
    };

    ~stop = false;
    currentChordList = ~chordDict[~currentSequence[~currentChordSetIndex]].patterns;
    currentChord = currentChordList[chordIndex];
    ["Initial chord:", currentChord].postln;  // Debug point 3
    0.25.wait;

    "About to enter loop".postln;  // Debug point 4

    loop({
        now = Main.elapsedTime;

        // Calculate chord duration with separate slider control
        chordDuration = if(~proceduralMode) {
            var envTime = now - envStartTime;
            var currentMinValue = ~chordMinEnv.at(envTime);
            var currentChordLevel;

            // Check if we've exceeded the envelope duration
            if(envTime >= ~chordMinEnv.times.sum) {
                currentMinValue = ~chordMinEnv.levels.last;
            };

            // Only post when we reach a new chord level
            if(currentMinValue != lastChordLevel) {
                ["Chord min duration:", currentMinValue.round(0.001)].postln;
                lastChordLevel = currentMinValue;
            };

            // Calculate chord duration using the envelope-controlled minimum
            restTime.lincurve(
                ~controlRanges.rest.min,
                ~controlRanges.rest.max,
                ~controlRanges.chord.max,
                currentMinValue,  // Use envelope value instead of fixed minimum
                ~controlRanges.chord.curve
            );
        } {
            // MIDI control logic using slider 3 for chord duration
            var value = ~midiController.sliderValues[3].lincurve(
                0, 127,
                ~controlRanges.chord.min,
                ~controlRanges.chord.max,
                ~controlRanges.chord.curve
            );
            ["MIDI chord duration:", value.round(0.001)].postln;
            value
        };

        // Rest time still controlled by slider 2
        restTime = if(~proceduralMode) {
            var envTime = now - envStartTime;
            var envValue;
            var timeSum = 0;
            var currentLevel;

            // Check if current envelope is finished
            if(envTime >= currentEnv.times.sum) {
                ["Envelope", ~currentEnvIndex, "complete"].postln;

                // Move to next envelope and advance sequence
                ~currentEnvIndex = ~currentEnvIndex + 1;
                if(~currentEnvIndex < ~restTimeEnvs.size) {
                    ["Starting envelope", ~currentEnvIndex].postln;
                    currentEnv = ~restTimeEnvs[~currentEnvIndex];
                    envStartTime = now;
                    envTime = 0;
                    lastLevel = nil;

                    // Advance to next chord in sequence
                    ~currentChordSetIndex = (~currentChordSetIndex + 1) % ~currentSequence.size;
                    currentChordList = ~chordDict[~currentSequence[~currentChordSetIndex]].patterns;
                    ["Moving to next chord set:", ~chordDict[~currentSequence[~currentChordSetIndex]].name].postln;

                    // If we've completed the sequence, advance cycle
                    if(~currentChordSetIndex == 0) {
                        ~advanceCycle.value;
                        ~currentSequence = ~developmentCycles[~currentCycle].sequence;
                    };
                } {
                    ["All envelopes complete"].postln;
                    ~stop = true;
                    currentEnv.levels.last
                };
            };

            envValue = currentEnv.at(envTime);
            envValue
        } {
            var value = ~midiController.sliderValues[2].lincurve(
                0, 127,
                ~controlRanges.rest.min,
                ~controlRanges.rest.max,
                ~controlRanges.rest.curve
            );
            ["MIDI rest time:", value.round(0.001)].postln;
            value
        };

        velocity = if(~proceduralMode) {
            var value = 100;  // Set a default velocity
            ["Procedural velocity:", value].postln;
            value
        } {
            var value = ~midiController.sliderValues[2].linlin(
                0, 127,
                ~controlRanges.velocity.min,
                ~controlRanges.velocity.max
            );
            ["MIDI controlled velocity:", value].postln;
            value
        };

        // Update tempo with curve
        ts.setBPM(~midiController.sliderValues[0].lincurve(
            0, 127,
            ~controlRanges.tempo.min,
            ~controlRanges.tempo.max,
            ~controlRanges.tempo.curve
        ));

        // Calculate release time for current chord
        currentChordReleaseTime = chordDuration;

        // Debug VST list before playing
        ["VST List status:"].postln;
        ~vstList.keysValuesDo { |key, vst|
            [key, vst.notNil].postln;
        };

        // Play current chord with enhanced debug
        currentChord.do { |note|

            ~vstList.do { |item, i|
                var vstKey = (\vsti ++ i).asSymbol;
                if(item.notNil) {
                    item.midi.noteOn(0, note, velocity.asInteger);
                } {
                };
            };
        };

        // Wait for chord duration
        currentChordReleaseTime.wait;

        // Release all notes in current chord
        currentChord.do { |note|
            ~vstList.do { |item|
                item.midi.noteOff(0, note, 0);
            };
        };

        // Wait rest time before next chord
        restTime.wait;

        // Remove the old sequence progression logic
        repetitionCount = repetitionCount + 1;
        if (repetitionCount >= ~repetitions) {
            repetitionCount = 0;
            chordIndex = getNextChordIndex.value;
        };

        currentChord = currentChordList[chordIndex];
        ts.advance;

        // Print time signature state
        if(~stop == true) {
            // Release all active notes when stopping
            activeNotes.keysValuesDo({ |note, releaseAt|
                ~vstList.do { |item|
                    item.midi.noteOff(0, note, 0);
                };
            });
            activeNotes.clear;
            ~sketch.stop;
        };
    });
});

~proceduralMode = false;   // Enable procedural mode
// ~proceduralMode = false;  // Switch back to MIDI control


// Then define the SynthDef
SynthDef(\CCEnvelope, {
    arg start = 0, end = 127, dur = 1, ccNum = 17;
    var env;

    env = EnvGen.kr(
        Env.new(
            levels: [start, end],
            times: [dur],
            curve: \exp
        ),
        doneAction: 2
    );

    SendReply.kr(
        Impulse.kr(100),
        '/cc',
        [ccNum, env.round(1)],  // Round to integer
        replyID: 0
    );
}).add;

// Define the OSC responder with better message parsing
~ccOscFunc = OSCFunc({ |msg|
    var ccNum, ccValue;

    // Debug the raw message
    // ["Raw OSC message:", msg].postln;

    // Safely extract values
    ccNum = msg[3];  // The CC number
    ccValue = msg[4].round.asInteger;  // The CC value, rounded to integer

    if(ccNum.notNil && ccValue.notNil) {
        ~logCounter = ~logCounter ? 0;
        ~logCounter = ~logCounter + 1;

        if(~logCounter % 5 == 0) {
            ["CC Debug:", "CC:", ccNum, "Value:", ccValue].postln;
        };

        // Send CC value to all VSTs
        6.do { |i|
            var vstKey = (\vsti ++ i).asSymbol;
            if(~vstList[vstKey].notNil && (ccValue >= 0) && (ccValue <= 127)) {
                ~vstList[vstKey].midi.control(0, ccNum, ccValue);
            };
        };
    };
}, '/cc', s.addr);

// Define the trigger helper
~triggerCCEnv = { |start = 0, end = 127, dur = 1, ccNum = 17|
    Synth(\CCEnvelope, [
        \start, start,
        \end, end,
        \dur, dur,
        \ccNum, ccNum
    ]);
};

// Define the sequence starter
~startCCSequence = {
    var startNext = { |envIndex|
        var env = ~ccEnvs[envIndex];
        ["Starting CC envelope", envIndex].postln;

        ~triggerCCEnv.(
            env.levels[0].asInteger,  // Make sure these are integers
            env.levels[1].asInteger,
            env.times[0],
            17
        );

        SystemClock.sched(env.times[0], {
            ~triggerCCEnv.(
                env.levels[1].asInteger,  // Make sure these are integers
                env.levels[2].asInteger,
                env.times[1],
                17
            );

            SystemClock.sched(env.times[1], {
                envIndex = envIndex + 1;
                if(envIndex < ~ccEnvs.size) {
                    startNext.(envIndex);
                } {
                    ["CC envelope sequence complete"].postln;
                };
                nil;
            });
            nil;
        });
    };

    startNext.(0);
};
)
// Now you can run:
~startCCSequence.value;
~sketch.play;
