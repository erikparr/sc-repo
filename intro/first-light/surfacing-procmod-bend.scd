// surfacing-procmod.scd
// A reimplementation of surfacing-ii.scd using ProcMod for better gestural control

// Load the setup files
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;

// first we load the melodies from the data folder
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "data/surfacing-melody.scd").load;

// MIDI Button Controls Setup - implement proper toggle behavior
// Track last button state to implement toggle logic
~lastButtonState = Dictionary.new;
~toggleMelodyRest.free;
~toggleMelodyRest = MIDIdef.cc(\toggleMelodyRest, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only toggle on rising edge (0->127, button press)
    // Ignore falling edge (127->0, button release)
    if(buttonPressed && (lastState == false)) {
        // Toggle the melody rest mode
        ~modes.melodyRestMode = ~modes.melodyRestMode.not;

        // Provide immediate feedback about the new state
        ["MIDI Button CC 45: Melody Rest mode",
            if(~modes.melodyRestMode, "ENABLED", "DISABLED"),
            "- Will take effect on next loop cycle"].postln;
    };

    // Remember current state for next time
    ~lastButtonState[ccNum] = buttonPressed;

}, 45);  // CC 45 for the button

// Add pause notes toggle control
~togglePauseNotes.free;
~togglePauseNotes = MIDIdef.cc(\togglePauseNotes, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only toggle on rising edge (0->127, button press)
    // Ignore falling edge (127->0, button release)
    if(buttonPressed && (lastState == false)) {
        // Toggle the pause notes mode
        ~modes.pauseNotesMode = ~modes.pauseNotesMode.not;

        // Provide immediate feedback about the new state
        ["MIDI Button CC 41: Pause Notes toggled to",
            if(~modes.pauseNotesMode, "ON", "OFF"),
            "- Will take effect on next loop cycle"].postln;
    };

    // Remember current state for next time
    ~lastButtonState[ccNum] = buttonPressed;

}, 41);  // CC 41 for the button


// Add next cycle control
~nextCycle.free;
~nextCycle = MIDIdef.cc(\nextCycle, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only act on rising edge (0->127, button press)
    // Ignore falling edge (127->0, button release)
    if(buttonPressed && (lastState == false)) {
        var nextCycle = ~currentCycle + 1;
        var numCycles = ~developmentCycles.size;

        // Wrap around if we go past the last cycle
        if(nextCycle > numCycles) {
            nextCycle = 1;
        };

        // Only switch if there's actually a change
        if(nextCycle != ~currentCycle) {
            // Provide feedback before switching
            ["MIDI Button CC 59: Switching from cycle", ~currentCycle, "(", ~developmentCycles[~currentCycle].name, ")",
             "to cycle", nextCycle, "(", ~developmentCycles[nextCycle].name, ")",
             "- Will take effect on next loop cycle"].postln;

            // Switch to the next cycle
            ~switchCycle.value(nextCycle);

            // Reset to beginning of sequence
            ~currentMelodySetIndex = 0;
        };
    };

    // Remember current state for next time
    ~lastButtonState[ccNum] = buttonPressed;

}, 59);  // CC 59 for next cycle

~prevCycle.free;
// Add previous cycle control
~prevCycle = MIDIdef.cc(\prevCycle, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only act on rising edge (0->127, button press)
    // Ignore falling edge (127->0, button release)
    if(buttonPressed && (lastState == false)) {
        var prevCycle = ~currentCycle - 1;
        var numCycles = ~developmentCycles.size;

        // Wrap around if we go below the first cycle
        if(prevCycle < 1) {
            prevCycle = numCycles;
        };

        // Only switch if there's actually a change
        if(prevCycle != ~currentCycle) {
            // Provide feedback before switching
            ["MIDI Button CC 58: Switching from cycle", ~currentCycle, "(", ~developmentCycles[~currentCycle].name, ")",
             "to cycle", prevCycle, "(", ~developmentCycles[prevCycle].name, ")",
             "- Will take effect on next loop cycle"].postln;

            // Switch to the previous cycle
            ~switchCycle.value(prevCycle);

            // Reset to beginning of sequence
            ~currentMelodySetIndex = 0;
        };
    };

    // Remember current state for next time
    ~lastButtonState[ccNum] = buttonPressed;

}, 58);  // CC 58 for previous cycle

// Add bend mode toggle control
~toggleBendMode.free;
~toggleBendMode = MIDIdef.cc(\toggleBendMode, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only toggle on rising edge (0->127, button press)
    if(buttonPressed && (lastState == false)) {
        // Toggle the bend mode
        ~modes.bendMode = ~modes.bendMode.not;

        // Provide immediate feedback
        ["MIDI Button CC 46: Bend Mode toggled to",
            if(~modes.bendMode, "ON", "OFF"),
            "- Will affect fermata notes when fermata mode is ON"].postln;
    };

    // Remember current state
    ~lastButtonState[ccNum] = buttonPressed;

}, 46);  // CC 46 for the bend mode button

// =====================================================================
// Global variables and settings
// =====================================================================

// Control parameters
~bpm = 298;
~noteDuration = 0.2;
~noteRest = 0.2;
~melodyRestTime = 0.025;  // Renamed from ~melodyRest for clarity
~fermataReleaseRest = 0.25;

// Bend control parameters
~bendControl = (
	bendPercent: -10,       // Bend amount in percentage (-100 to 100)
	bendPeakTimeFactor: 0.7, // Portion of hold duration to reach peak bend
	bendReturnTimeFactor: 0.3,// Portion of hold duration to return from bend
	curveShape: \sin        // Envelope shape for bend
);

// Flags for different behavior modes
~modes = (
    melodyRestMode: true,        // Enable longer rests between melodies (renamed from melodyRest)
    fermata: true,          // Hold the last note of each melody
    rampTempo: false,        // Progressively change note rest times
    velocityMultiply: false, // Apply velocity multipliers to first/last notes
    noteOffset: true,        // Apply note offset to all notes
    removeLast: false,       // Skip the last note in each melody
    pauseNotesMode: false,   // When true, stop triggering new notes (toggled by CC 41)
    bendMode: false          // When true, apply pitch bend to fermata notes (toggled by CC 46)
);

// Control parameters
~noteOffset = -12;           // Semitones to offset notes (-12 = one octave down)
~repetitions = 1;            // Number of times to repeat each melody
~currentMelodySetIndex = 0;  // Current melody index
~currentCycle = 1;           // Current development cycle

// =====================================================================
// CC Control Envelope System
// =====================================================================

// Expression CC control parameters
~ccControl = (
    enabled: true,                // Enable/disable the CC control
    expressionCC: 17,             // CC number for expression
    expressionMin: 40,            // Minimum expression value
    expressionMax: 110,           // Maximum expression value (slightly reduced to avoid overblowing)
    expressionShape: \sin,        // Envelope shape: \sin, \lin, \exp, etc.
    expressionPeakPos: 0.6,       // Position of peak in the envelope (0.0-1.0)

    // Time factors relative to melody duration
    attackFactor: 0.9,            // Portion of melody duration for attack
    decayFactor: 0.1,             // Portion of melody duration for decay

    // Controls for future additions
    bowPressureCC: 23,            // CC for bow pressure (for future use)
    harmAGainCC: 25,              // CC for harmonic A gain (for future use)
    harmBGainCC: 26,              // CC for harmonic B gain (for future use)
    bowPressureAccentCC: 27,      // CC for bow pressure accent (for future use)
    bowPositionCC: 28             // CC for bow position (for future use)
);

// Function to calculate envelope duration based on current melody
~calcEnvelopeDuration = {
    var melodyKey = ~currentSequence[~currentMelodySetIndex];
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
    var totalNoteDuration = noteCount * ~noteRest * ~repetitions;

    // If we have melody rests, include those in the envelope duration
    totalNoteDuration + (if(~modes.melodyRestMode, {~melodyRestTime}, {0}));
};

// Function to create Env for a CC over time
~createCCEnvelope = { |ccNum, minVal, maxVal, duration, shape, peakPosition|
    var attackTime = duration * ~ccControl.attackFactor * peakPosition * 2;
    var decayTime = duration * ~ccControl.decayFactor * (1-peakPosition) * 2;

    ["Creating CC envelope",
     "CC:", ccNum,
     "Range:", minVal, "to", maxVal,
     "Duration:", duration,
     "Shape:", shape,
     "Attack:", attackTime,
     "Decay:", decayTime
    ].postln;

    Env(
        [minVal, maxVal, minVal],
        [attackTime, decayTime],
        shape
    );
};

// Collection to track active CC control synths
~activeCCSynths = Dictionary.new;

// Function to start a CC envelope for the current melody
~startCCEnvelopes = { |melodyKey|
    var duration = ~calcEnvelopeDuration.value;
    var attackTime, sustainTime, releaseTime;

    // Update expression range from knobs before creating envelopes
    ~updateExpressionRangeFromKnobs.value;

    // Concise logging
    "Starting CC envelopes for duration: %".format(duration).postln;

    // Free any existing synths
    ~activeCCSynths.do { |synth|
        synth.free;
    };
    ~activeCCSynths = Dictionary.new;

    if(~ccControl.enabled) {
        // Calculate timing parameters based on envelope duration
        attackTime = duration * ~ccControl.attackFactor * ~ccControl.expressionPeakPos;
        sustainTime = duration * 0.1; // Short sustain at peak
        releaseTime = duration * ~ccControl.decayFactor * (1 - ~ccControl.expressionPeakPos);

        // Create expression control synths for each VST
        ~vstList.keysValuesDo { |vstKey, vst, i|
            var ccSynth;

            // Create a single control synth for each VST
            ccSynth = Synth(\ccEnvelope, [
                \start, ~ccControl.expressionMin,
                \peak, ~ccControl.expressionMax,
                \end, ~ccControl.expressionMin,
                \attackTime, attackTime,
                \releaseTime, releaseTime,
                \chanIndex, i, // Use i to differentiate the VSTs
                \ccNum, ~ccControl.expressionCC,
                \attackCurve, ~ccControl.expressionShape,
                \releaseCurve, ~ccControl.expressionShape
            ]);

            // Store the synth in the dictionary with a key that includes the vstKey
            ~activeCCSynths[vstKey] = ccSynth;

            "Created CC envelope synth for %".format(vstKey).postln;
        };

        "CC control synths started".postln;
    }  {
        "CC Control disabled".postln;
    };
};

// Function to stop all CC envelopes
~stopCCEnvelopes = {
    ~activeCCSynths.do { |synth|
        synth.free;
    };
    ~activeCCSynths.clear;
    "All CC envelopes stopped".postln;
};

// Function to start looping CC envelopes
~startLoopingCCEnvelopes = { |melodyKey|
    var duration = ~calcEnvelopeDuration.value;
    var attackTime, releaseTime, loopDuration;

    // Update expression range from knobs before creating envelopes
    ~updateExpressionRangeFromKnobs.value;

    "Starting looping CC envelopes for duration: %".format(duration).postln;

    // Free any existing synths
    ~stopCCEnvelopes.value;

    if(~ccControl.enabled) {
        // Calculate timing parameters based on envelope duration
        attackTime = duration * ~ccControl.attackFactor * ~ccControl.expressionPeakPos;
        releaseTime = duration * ~ccControl.decayFactor * (1 - ~ccControl.expressionPeakPos);
        loopDuration = attackTime + releaseTime + 0.1; // Add a small padding

        // Create looping expression control synths for each VST
        ~vstList.keysValuesDo { |vstKey, vst, i|
            var ccSynth;

            // Create a looping CC envelope synth for each VST
            ccSynth = Synth(\ccEnvelopeLoop, [
                \start, ~ccControl.expressionMin,
                \peak, ~ccControl.expressionMax,
                \end, ~ccControl.expressionMin,
                \delayTime, 0,
                \attackTime, attackTime,
                \releaseTime, releaseTime,
                \loopDuration, loopDuration,
                \chanIndex, i, // Always use channel 0
                \ccNum, ~ccControl.expressionCC,
                \timeOffset, i * 0.25, // Stagger slightly between VSTs
                \attackCurve, ~ccControl.expressionShape,
                \releaseCurve, ~ccControl.expressionShape,
                \delayCurve, \lin
            ]);

            // Store the synth in the dictionary
            ~activeCCSynths[vstKey] = ccSynth;

            "Created looping CC envelope synth for %".format(vstKey).postln;
        };

        // If needed, add additional CC controllers for bow parameters, etc.
        if(~advancedCCsEnabled == true) {
            ~vstList.keysValuesDo { |vstKey, vst, i|
                var bowPressureSynth, harmASynth, harmBSynth, accentSynth, bowPositionSynth;

                // Example: Create bow pressure CC synth with different parameters
                bowPressureSynth = Synth(\ccEnvelopeLoop, [
                    \start, 20,             // Different start value
                    \peak, 100,             // Different peak value
                    \end, 20,
                    \delayTime, i * 0.1,    // Staggered delay
                    \attackTime, attackTime * 0.8,  // Shorter attack
                    \releaseTime, releaseTime * 1.2, // Longer release
                    \loopDuration, loopDuration * 1.1, // Slightly different loop timing
                    \chanIndex, i,
                    \ccNum, ~ccControl.bowPressureCC,
                    \timeOffset, i * 0.15,  // Different stagger timing
                    \attackCurve, ~ccControl.expressionShape,
                    \releaseCurve, ~ccControl.expressionShape,
                    \delayCurve, \lin
                ]);

                // Store in the dictionary with a compound key
                ~activeCCSynths[vstKey ++ "_bowPressure"] = bowPressureSynth;

                // Additional CC controllers could be added in a similar way
                // for harmonic gain, bow position, etc.
            };
        };

        "Looping CC control synths started".postln;
    }  {
        "CC Control disabled".postln;
    };
};

// Toggle for advanced CCs (bow pressure, harmonics, etc.)
~advancedCCsEnabled = false;

// Function to enable/disable advanced CC control
~setAdvancedCCsEnabled = { |enabled|
    ~advancedCCsEnabled = enabled;
    ["Advanced CC controls", if(enabled, "enabled", "disabled")].postln;

    // If CC envelopes are already running, restart them to apply changes
    if(~activeCCSynths.size > 0) {
        var melodyKey = ~currentSequence[~currentMelodySetIndex];
        ~stopCCEnvelopes.value;

        // Call appropriate function based on whether looping is desired
        if(~loopingCCEnvelopes == true) {
            ~startLoopingCCEnvelopes.(melodyKey);
        } {
            ~startCCEnvelopes.(melodyKey);
        };
    };
};

// Global flag for using looping CC envelopes
~loopingCCEnvelopes = false;

// Function to toggle between looping and one-shot CC envelopes
~setLoopingCCEnvelopes = { |looping|
    ~loopingCCEnvelopes = looping;
    ["Looping CC envelopes", if(looping, "enabled", "disabled")].postln;

    // If CC envelopes are already running, restart them to apply change
    if(~activeCCSynths.size > 0) {
        var melodyKey = ~currentSequence[~currentMelodySetIndex];
        ~stopCCEnvelopes.value;

        if(looping) {
            ~startLoopingCCEnvelopes.(melodyKey);
        }  {
            ~startCCEnvelopes.(melodyKey);
        };
    };
};

// =====================================================================
// Melody Dictionary
// =====================================================================


// Tuba Melody Dictionary
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // Normal velocity for last note
    )
));
~melodyDict.put(\set1b, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78, 94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set2, (
    name: "Tuba Melody II",
    patterns: [
        [89, 84, 81, 77, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set3, (
    name: "Tuba Melody III",
    patterns: [
        [90, 85, 82, 75, 90],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set4, (
    name: "Tuba Melody IV",
    patterns: [
        [90, 85, 78, 73, 90],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set5, (
    name: "Tuba Melody V",
    patterns: [
        [89, 85, 82, 75, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set6, (
    name: "Tuba Melody VI",
    patterns: [
        [87, 82, 78, 73, 87],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set7, (
    name: "Tuba Melody VII",
    patterns: [
        [89, 82, 78, 73, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set8, (
    name: "Tuba Melody VIII",
    patterns: [
        [85, 82, 78, 75],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    )
));
~melodyDict.put(\set9, (
    name: "Tuba Melody IX",
    patterns: [
        [94, 89, 84, 78, 70],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));
~melodyDict.put(\part2a, (
    name: "Tuba Melody X",
    patterns: [
        [77, 75, 77, 89, 78, 75, 77, 78, 90, 77, 78, 94, 82, 73, 77, 89, 78],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    )
));
~melodyDict.put(\part2b, (
    name: "Tuba Melody XI",
    patterns: [
        [70, 85, 72, 87, 73, 89, 75, 87, 75, 85, 70, 84, 72, 82, 70, 85],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    )
));

~melodyDict.put(\loop1, (
    name: "Tuba Melody XI",
    patterns: [
        [94,89,66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop1a, (
    name: "Tuba Melody XI",
    patterns: [
        [89,94,66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop2, (
    name: "Tuba Melody XII",
    patterns: [
        [94, 89, 82],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop3, (
    name: "Tuba Melody XIII",
    patterns: [
        [94, 89, 78],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop4, (
    name: "Tuba Melody XIV",
    patterns: [
        [94, 89, 77],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop5, (
    name: "Tuba Melody XV",
    patterns: [
        [94, 89, 73],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop6, (
    name: "Tuba Melody XVI",
    patterns: [
        [94, 89, 66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop7, (
    name: "Tuba Melody XVII",
    patterns: [
        [94, 89, 70],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop8, (
    name: "Tuba Melody XVIII",
    patterns: [
        [94, 89, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));



~melodyDict.put(\loop9, (
    name: "Tuba Melody XI",
    patterns: [
        [94,89,61],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop9a, (
    name: "Tuba Melody XI",
    patterns: [
        [89,94,61],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop10, (
    name: "Tuba Melody XI",
    patterns: [
        [94,89,65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop10a, (
    name: "Tuba Melody XI",
    patterns: [
        [89,94,65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop11, (
    name: "Tuba Melody XI",
    patterns: [
        [94,89,63],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop11a, (
    name: "Tuba Melody XI",
    patterns: [
        [89,94,63],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop12, (
    name: "Tuba Melody XII",
    patterns: [
        [94,89,60],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));
~melodyDict.put(\loop12a, (
    name: "Tuba Melody XII",
    patterns: [
        [89,94,60],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

// Define development cycles
~developmentCycles = Dictionary.new;
// ~developmentCycles.put(1, (
// 	name: "Initial Cycle",
// 	sequence: [\loop1, \loop1a]
// ));
// // Add a second cycle with the new loops
// ~developmentCycles.put(2, (
// 	name: "Second Cycle",
// 	sequence: [\loop9, \loop9a]
// ));
// ~developmentCycles.put(3, (
// 	name: "Second Cycle",
// 	sequence: [\loop10, \loop10a]
// ));
// ~developmentCycles.put(4, (
// 	name: "Second Cycle",
// 	sequence: [\loop11, \loop11a]
// ));
// ~developmentCycles.put(5, (
// 	name: "Second Cycle",
// 	sequence: [\loop12, \loop12a]
// ));

~developmentCycles.put(1, (
name: "Second Cycle",
sequence: [\set1, \set1]
));
~developmentCycles.put(2, (
name: "Second Cycle",
sequence: [\set3, \set3]
));
~developmentCycles.put(3, (
name: "Second Cycle",
sequence: [\set5, \set5]
));
~developmentCycles.put(4, (
name: "Second Cycle",
sequence: [\set6, \set6]
));
~developmentCycles.put(5, (
name: "Second Cycle",
sequence: [\set7, \set7]
));
~developmentCycles.put(6, (
name: "Second Cycle",
sequence: [\set8, \set8]
));
// Initialize the current sequence
~currentSequence = ~developmentCycles[~currentCycle].sequence;

// =====================================================================
// Helper functions
// =====================================================================

// Function to modify a note based on current settings
~processNote = { |note, isFirstNote=false, isLastNote=false, melodyKey|
    var processedNote = note;
    var velocity = 80; // Default velocity
    var velocityMultiplier = 1.0;

    // Use MIDI controller if available
    if(~midiController.notNil) {
        velocity = ~midiController.getSliderValue(3).linlin(0, 127, 11, 127);
    };

    // Apply note offset if enabled
    if(~modes.noteOffset) {
        processedNote = (note + ~noteOffset).clip(0, 127);
    };

    // Apply velocity multipliers if enabled
    if(~modes.velocityMultiply) {
        if(isFirstNote) {
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers.first;
        };
        if(isLastNote) {
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers.last;
        };
        velocity = (velocity * velocityMultiplier).asInteger.clip(1, 127);
    };

    [processedNote, velocity];
};

// Function to switch to a specific cycle
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

// Function to advance to the next cycle
~advanceCycle = {
    var nextCycle = ~currentCycle + 1;
    if(~developmentCycles.includesKey(nextCycle)) {
        ~switchCycle.value(nextCycle);
        ["Advancing to cycle:", nextCycle].postln;
    } {
        ["Staying in final cycle:", ~currentCycle].postln;
    };
};

// =====================================================================
// OSC Responders
// =====================================================================

// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;
OSCdef(\releaseFermata).free;

// OSC responder for note events
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;
    var isFirstNote = msg[6].asInteger == 1;
    var isLastNote = msg[7].asInteger == 1;

    // Apply note offset if mode is enabled
    if(~modes.noteOffset) {
        note = (note + ~noteOffset).clip(0, 127);
    };

    ["OSC Received:", "channel:", channel, "note:", note, "vel:", velocity,
     "dur:", duration, "fermata:", isFermata, "first:", isFirstNote, "last:", isLastNote].postln;

    // Play note on all VST instances
    ~vstList.do { |item, index|
        ["Playing on VST:", index].postln;
        item.midi.noteOn(index, note, velocity);

        // Schedule note release unless it's a fermata note
        if(isFermata.not) {
            SystemClock.sched(duration, {
                ["Releasing note:", note, "on channel:", index].postln;
                item.midi.noteOff(index, note, 0);
                nil;
            });
        };
    };
}, '/note/on');

// Add a new OSC responder for releasing fermata notes
OSCdef(\releaseFermata, { |msg, time, addr, recvPort|
    var note = msg[1].asInteger;

    ["Releasing fermata note:", note].postln;

    // Release the note on all VST instances
    ~vstList.do { |item, index|
        item.midi.noteOff(index, note, 0);
    };
}, '/note/release');

// =====================================================================
// ProcMod Implementation
// =====================================================================

// Variables to store ProcMod instances
~melodyProcs = Dictionary.new;
~activeMelodyProc = nil;
~activeNotes = Dictionary.new;
~lastFermataNote = nil;
~sequenceTask = nil;
~activeBendSynths = Dictionary.new; // Added for bend mode

// Create a ProcMod for a melody
~createMelodyProc = { |melodyKey, patternIndex=0|
    var pattern = ~melodyDict[melodyKey].patterns[patternIndex];
    var id = (melodyKey ++ "_" ++ patternIndex).asSymbol;
    var estimatedMaxTaskDuration, baseRest, maxNoteDur, maxAccent, maxMelRest, maxFermRest;
    var effectiveLength = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
var env;
    // --- Calculate a safe maximum duration for the ProcMod envelope ---
    // Use max possible values for dynamic controls
    baseRest = 0.4; // Max from slider 2 range
    maxNoteDur = 1.0; // Max from slider 1 range
    maxAccent = 8.0; // Max from slider 5 range
    maxMelRest = 1.0; // Max from slider 4 range
    maxFermRest = ~fermataReleaseRest; // Fixed value

    // Duration of notes + rests within repetitions
    estimatedMaxTaskDuration = ~repetitions * (
        (effectiveLength - 1) * baseRest + // Time for n-1 notes
        (maxNoteDur * maxAccent) // Max time for the last note
    );

    // Add potential time between repetitions
    if(~repetitions > 1) {
        estimatedMaxTaskDuration = estimatedMaxTaskDuration + ((~repetitions - 1) * (baseRest * 2));
    };

    // Add potential final rests (melody rest or fermata)
    estimatedMaxTaskDuration = estimatedMaxTaskDuration + maxMelRest + maxFermRest;

    // Add safety buffer
    estimatedMaxTaskDuration = estimatedMaxTaskDuration + 1.0;

    ["DEBUG: Estimated Max Task Duration:", estimatedMaxTaskDuration].postln;
    // --- End Max Duration Calculation ---

    // Create an amplitude envelope without a release node, long enough to contain the task
     env = Env([0, 1, 1, 0], [0.1, estimatedMaxTaskDuration, 0.1], \sin);

    // Create the ProcMod for this melody
    ProcMod.new(
        env,          // Envelope without release node
        1.0,          // Amplitude
        id,           // Unique ID
        nil,          // Group (create new)
        0,            // addAction
        1,            // target

        // Main function - this will be executed when ProcMod plays
        { |group, envbus|
            var currentNote = pattern[0];
            var noteIndex = 0;
            var repetitionCount = 0;
            var notePlaying = false;
            var task;

            // Get duration parameters (use defaults if no controller)
            var noteDuration = ~noteDuration;
            var noteRestTime = ~noteRest;
            var temporalAccent = 1;

            // Use MIDI controller values if available
            if(~midiController.notNil) {
                noteDuration = ~midiController.getSliderValue(1).linlin(0, 127, 0.001, 0.5);
                noteRestTime = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
                temporalAccent = ~midiController.getSliderValue(5).linlin(0, 127, 0.75, 8);
                // Get melody rest time from slider 4
                ~melodyRestTime = ~midiController.getSliderValue(4).linlin(0, 127, 0.0, 1.0);
            };

            // Store the ID of the active melody
            ~activeMelodyProc = id;

            // Log start
            ["Starting melody:", melodyKey, "with", effectiveLength, "notes"].postln;

            // Play each note with proper timing
            task = Task({
                // Repeat the pattern the specified number of times
                ~repetitions.do { |repIndex|
                    // Reset note index for this repetition
                    noteIndex = 0;

                    // Play through each note in the pattern
                    while({ noteIndex < effectiveLength }) {
                        var note = pattern[noteIndex];
                        var isFirstNote = (noteIndex == 0);
                        var isLastNote = (noteIndex == (effectiveLength - 1));
                        var isFermata = isLastNote && ~modes.fermata && ~modes.melodyRestMode;
                        var actualDuration, processedNote;

                        // Process the note (apply offset, etc.)
                        processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);

                        // Calculate note duration based on position in melody - clear if/else structure
                        if(isFirstNote) {
                            // Only first note gets temporal accent
                            actualDuration = noteDuration * 1;
                        } {
                            if(isLastNote) {
                                // Only last note gets the last note duration scalar
                                actualDuration = noteDuration * temporalAccent;
                            } {
                                // Middle notes get the base duration with no modifier
                                actualDuration = noteDuration;
                            };
                        };

                        // Debug the duration calculation
                        ["DEBUG - Duration calculation:",
                            "note:", processedNote[0],
                            "isFirst:", isFirstNote,
                            "isLast:", isLastNote,
                            "baseDur:", noteDuration,
                            "actualDur:", actualDuration,
                            if(isLastNote, {"accentMult:" ++ temporalAccent}, {""})
                        ].postln;

                        // Store last note duration for loop timing adjustment
                        if(isLastNote) {
                            ~lastNoteDuration = actualDuration;
                            ["Setting ~lastNoteDuration to:", ~lastNoteDuration].postln;
                        };

                        // Make sure duration doesn't exceed rest time
                        if(isFermata.not) {
                            if(isLastNote) {
                                // For last note, allow any duration - no cap
                                // The loop will adjust timing to accommodate it
                            }  {
                                // For other notes, keep the normal cap
                                var maxDuration = noteRestTime * 0.9;
                                if(actualDuration > maxDuration) {
                                    actualDuration = maxDuration;
                                };
                            };
                        };

                        // Release any previous fermata note and bend synths
                        if(~lastFermataNote.notNil) {
                            ["Releasing previous fermata note:", ~lastFermataNote].postln;
                            NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                            ~lastFermataNote = nil;

                            // Also clear any active bend synths
                            if(~activeBendSynths.size > 0) {
                                ["Clearing active bend synths (new note)"].postln;
                                ~activeBendSynths.do(_.free);
                                ~activeBendSynths.clear;
                            };
                        };

                        // Play the note with OSC
                        ["Playing note:", processedNote[0], "duration:", actualDuration,
                            "noteIndex:", noteIndex, "fermata:", isFermata,
                            "first:", isFirstNote, "last:", isLastNote,
                        ].postln;

                        NetAddr.localAddr.sendMsg('/note/on', 0, processedNote[0], processedNote[1],
                            actualDuration, isFermata.asInteger,
                            isFirstNote.asInteger, isLastNote.asInteger);

                        // Store fermata note for later release AND potentially trigger bend
                        if(isFermata) {
                            ~lastFermataNote = processedNote[0];

                            // If bendMode is also on, create bend envelopes
                            if(~modes.bendMode) {
                                var fermataHoldDuration = ~melodyRestTime + ~fermataReleaseRest;
                                var bendPeakTime = fermataHoldDuration * ~bendControl.bendPeakTimeFactor;
                                var bendReturnTime = fermataHoldDuration * ~bendControl.bendReturnTimeFactor;
                                var bendValue = ~calcBendValue.(~bendControl.bendPercent);

                                ["Triggering BEND for fermata note:", ~lastFermataNote,
                                 "Percent:", ~bendControl.bendPercent,
                                 "Value:", bendValue,
                                 "Hold Dur:", fermataHoldDuration,
                                 "Peak Time:", bendPeakTime,
                                 "Return Time:", bendReturnTime
                                ].postln;

                                // Create bend synth for each VST
                                ~vstList.keysValuesDo { |vstKey, vst, i|
                                    var bendSynth;
                                    bendSynth = Synth(\BendEnvelope, [
                                        \start, 8192,
                                        \peak, bendValue,
                                        \end, 8192,
                                        \peakTime, bendPeakTime,
                                        \returnTime, bendReturnTime,
                                        \chanIndex, i,
                                        \peakCurve, ~bendControl.curveShape,
                                        \returnCurve, ~bendControl.curveShape
                                    ]);
                                    ~activeBendSynths[vstKey] = bendSynth;
                                };
                            };
                        };

                        // Wait before playing the next note
                        noteRestTime.wait;

                        // Advance to next note
                        noteIndex = noteIndex + 1;
                    };

                    // --- Post-Repetitions Logic ---

                    // Handle fermata release specifically when melodyRestMode is OFF
                    if(~modes.fermata && (~modes.melodyRestMode.not) && ~lastFermataNote.notNil) {
                        var holdDuration = ~lastNoteDuration ? 0.1; // Use last note duration or default
                        var bendDuration = 0;

                        ["Handling fermata release without melody rest. Holding for:", holdDuration].postln;

                        // If bending, calculate bend time to wait
                        if(~modes.bendMode && ~activeBendSynths.size > 0) {
                            bendDuration = (holdDuration * ~bendControl.bendPeakTimeFactor) +
                                           (holdDuration * ~bendControl.bendReturnTimeFactor);
                            ["Bend active, waiting for bend duration:", bendDuration].postln;
                            // Wait for the bend envelope to roughly complete
                            bendDuration.wait;
                        } {
                            // Otherwise, just wait for the note's intended hold
                            holdDuration.wait;
                        };

                        // Release the note and bend synths AFTER the wait
                        ["Releasing fermata note after hold (no melody rest):", ~lastFermataNote].postln;
                        NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                        ~lastFermataNote = nil;

                        if(~activeBendSynths.size > 0) {
                            ["Clearing active bend synths (no melody rest)"].postln;
                            ~activeBendSynths.do(_.free);
                            ~activeBendSynths.clear;
                        };
                    };

                    // Cleanup bend synths if they were created (might happen if fermata is ON but melodyRestMode is OFF)
                     if(~activeBendSynths.size > 0 && ~lastFermataNote.isNil) { // Only cleanup if note wasn't just released above
                         ["Clearing active bend synths (end of task, non-melody-rest fermata release)"].postln;
                         ~activeBendSynths.do(_.free);
                         ~activeBendSynths.clear;
                     };

                    // Signal completion
                    ["Melody", melodyKey, "completed"].postln;
                    ["**** DEBUG: Melody task complete for", melodyKey, "- exact time:", Main.elapsedTime.round(0.001)].postln;
                };

                // After all repetitions, handle melody rest if enabled
                if(~modes.melodyRestMode) {
                    ["Taking a longer rest between melodies:", ~melodyRestTime, "seconds (controlled by slider 4)"].postln;
                    ~melodyRestTime.wait;

                    // Release fermata note after melody rest
                    if(~lastFermataNote.notNil) {
                        ["Releasing fermata note after melody rest:", ~lastFermataNote].postln;
                        NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);

                        // Wait for additional fermata release rest
                        ["Waiting for fermata release rest:", ~fermataReleaseRest, "seconds"].postln;
                        ~fermataReleaseRest.wait;

                        ~lastFermataNote = nil;

                        // Also clear any active bend synths after rest
                        if(~activeBendSynths.size > 0) {
                            ["Clearing active bend synths (after rest)"].postln;
                            ~activeBendSynths.do(_.free);
                            ~activeBendSynths.clear;
                        };
                    };
                };

                // Signal completion
                ["Melody", melodyKey, "completed"].postln;
                ["**** DEBUG: Melody task complete for", melodyKey, "- exact time:", Main.elapsedTime.round(0.001)].postln;
            });

            // Start the task
            task.play;

            // Return the task so ProcMod can track it
            task;
        },

        // Release function - executes after ProcMod has fully released
        { |group, envbus|
            ["ProcMod for", id, "has completed release"].postln;
            ["**** DEBUG: ProcMod fully released for", id, "- exact time:", Main.elapsedTime.round(0.001)].postln;

            // Clean up resources if needed
            ~activeNotes.clear;

            // Release bend synths
            if(~activeBendSynths.size > 0) {
                ["Clearing active bend synths (ProcMod release)"].postln;
                ~activeBendSynths.do(_.free);
                ~activeBendSynths.clear;
            };
        },

        // onReleaseFunc - executes when release is triggered
        { |group, envbus|
            ["Releasing ProcMod for", id].postln;

            // Release any fermata notes
            if(~lastFermataNote.notNil) {
                ["Releasing fermata note:", ~lastFermataNote].postln;
                NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                ~lastFermataNote = nil;
            };

            // Release any active notes
            ~activeNotes.keysValuesDo { |key, noteInfo|
                ["Releasing note:", noteInfo.note].postln;
                ~vstList.do { |vst, index|
                    vst.midi.noteOff(index, noteInfo.note, 0);
                };
            };

            // Clear active notes
            ~activeNotes.clear;
        }
    );
};

// Initialize ProcMods for each melody
~currentSequence.do { |melodyKey|
    if(~melodyProcs[melodyKey].isNil) {
        ~melodyProcs[melodyKey] = ~createMelodyProc.value(melodyKey);
    };
};

// Play through all melodies in the sequence automatically
~playAllMelodiesInSequence = {
    var sequenceTask;

    // Stop any currently playing melody
    ~stopAllMelodies.value;

    // Reset to beginning of the sequence
    ~currentMelodySetIndex = 0;

    // Create a task that will play each melody and then advance to the next
    sequenceTask = Task({
        var melodyCount, completed;
        var currentMelodyKey, currentProc;
        var pattern, noteCount, melodyDuration, totalWaitTime;

        melodyCount = ~currentSequence.size;
        completed = false;

        ["Starting automatic playback of", melodyCount, "melodies in sequence"].postln;

        // Play through all melodies in the sequence
        while({ ~currentMelodySetIndex < melodyCount and: { completed.not } }) {
            currentMelodyKey = ~currentSequence[~currentMelodySetIndex];
            currentProc = ~melodyProcs[currentMelodyKey];

            ["Auto-playing melody", ~currentMelodySetIndex + 1, "of", melodyCount, ":", currentMelodyKey].postln;

            // Play this melody
            ~playMelody.value(currentMelodyKey);

            // Wait for it to complete (melody duration + rest time)
            pattern = ~melodyDict[currentMelodyKey].patterns[0];
            noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
            melodyDuration = noteCount * ~noteRest * ~repetitions;
            totalWaitTime = melodyDuration + ~melodyRestTime + 0.1; // Add a small buffer

            ["Waiting for melody to complete:", totalWaitTime, "seconds"].postln;
            totalWaitTime.wait;

            // Advance to the next melody
            ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % melodyCount;

            // If we've completed one full cycle, trigger an advance to the next cycle if needed
            if(~currentMelodySetIndex == 0) {
                ["Completed one full cycle of melodies"].postln;
                // Optionally advance to the next cycle here with:
                // ~advanceCycle.value;

                // For now, set completed to true to stop after one full cycle
                completed = true;
            };
        };

        ["Automatic playback completed"].postln;
    });

    // Start the sequence task
    sequenceTask.play;
    ~sequenceTask = sequenceTask;
};

// Play a specific melody
~playMelody = { |melodyKey|
    var proc = ~melodyProcs[melodyKey];

    // Stop any currently playing melody
    if(~activeMelodyProc.notNil && ~melodyProcs[~activeMelodyProc].notNil) {
        ~melodyProcs[~activeMelodyProc].release(0.2);
    };

    // Always recreate the ProcMod for the melody to ensure it plays fresh every time
    // This ensures repeated melodies will play properly
    if(proc.notNil && proc.isRunning) {
        ["Stopping and recreating ProcMod for:", melodyKey].postln;
        proc.stop;
        proc = nil;
    };

    // Create a new ProcMod instance
    proc = ~createMelodyProc.value(melodyKey);
    ~melodyProcs[melodyKey] = proc;

    // Start CC envelopes for this melody based on mode
    if(~loopingCCEnvelopes) {
        ~startLoopingCCEnvelopes.value(melodyKey);
    }  {
        ~startCCEnvelopes.value(melodyKey);
    };

    // Play this melody after a short delay
    SystemClock.sched(0.3, {
        ["Playing melody:", melodyKey].postln;
        proc.play;
        nil;
    });
};

// Play the current melody set
~playCurrentMelody = {
    var melodyKey = ~currentSequence[~currentMelodySetIndex];
    ~playMelody.value(melodyKey);
};

// Advance to the next melody
~nextMelody = {
    // Stop current CC envelopes
    ~stopCCEnvelopes.value;

    // Advance to the next melody index
    ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~currentSequence.size;

    // Check if we've completed a cycle
    if(~currentMelodySetIndex == 0) {
        ~advanceCycle.value;
    };

    ~playCurrentMelody.value;
};

// Stop all melodies
~stopAllMelodies = {
    // First, stop the sequence task if it's running
    if(~sequenceTask.notNil) {
        ["Stopping automatic sequence playback"].postln;
        ~sequenceTask.stop;
        ~sequenceTask = nil;
    };

    // Stop all individual melody ProcMods
    ~melodyProcs.do { |proc|
        if(proc.notNil && proc.isRunning) {
            proc.release(0.2);
        };
    };

    // Stop all CC envelopes
    ~stopCCEnvelopes.value;

    // Release any fermata notes
    if(~lastFermataNote.notNil) {
        NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
        ~lastFermataNote = nil;
    };

    // Clear bend synths
    if(~activeBendSynths.size > 0) {
        ["Clearing active bend synths (stopAllMelodies)"].postln;
        ~activeBendSynths.do(_.free);
        ~activeBendSynths.clear;
    };

    // Reset melody index
    ~currentMelodySetIndex = 0;

    // Clear any active notes
    ~activeNotes.clear;
};

// Stop all notes regardless of melody state
~stopAllNotes = {
    // Stop each VST instance
    ~vstList.do { |vst|
        5.do { |channel|
            vst.midi.allNotesOff(channel);
        };
    };

    // Stop all CC envelopes
    ~stopCCEnvelopes.value;

    // Reset tracking variables
    ~lastFermataNote = nil;
    ~activeNotes.clear;
};

// Set a mode
~setMode = { |mode, value|
    if(~modes.includesKey(mode)) {
        ~modes[mode] = value;
        ["Mode", mode, "set to", value].postln;
    } {
        ["Invalid mode:", mode].postln;
    };
};

// Set repetitions
~setRepetitions = { |num|
    ~repetitions = num;
    ["Repetitions set to", num].postln;
};

// Set note offset
~setNoteOffset = { |offset|
    ~noteOffset = offset;
    ["Note offset set to", offset, "semitones"].postln;
};

// Switch to a cycle
~switchToCycle = { |cycleNum|
    ~switchCycle.value(cycleNum);
    ~currentMelodySetIndex = 0;
    ["Switched to cycle", cycleNum].postln;
};
~setMode.value(\fermata, true);
~setMode.value(\noteOffset, false);
~setRepetitions.value(1);
~setNoteOffset.value(0);

// =====================================================================
// CC Control Functions
// =====================================================================

// Enable or disable CC envelope control
~setCCControlEnabled = { |enabled|
    ~ccControl.enabled = enabled;
    ["CC control", if(enabled, "enabled", "disabled")].postln;

    // If disabling, stop any running envelopes
    if(enabled.not) {
        ~stopCCEnvelopes.value;
    }  {
        // If a melody is currently playing, restart envelopes
        if(~activeMelodyProc.notNil) {
            var melodyKey = ~currentSequence[~currentMelodySetIndex];
            ~startCCEnvelopes.value(melodyKey);
        };
    };
};

// Set expression CC range
~setExpressionRange = { |min, max|
    ~ccControl.expressionMin = min.clip(0, 127);
    ~ccControl.expressionMax = max.clip(0, 127);
    ["Expression range set to", min, "-", max].postln;

    // Update running envelopes if needed
    if(~ccControl.enabled && ~activeMelodyProc.notNil) {
        var melodyKey = ~currentSequence[~currentMelodySetIndex];
        ~startCCEnvelopes.value(melodyKey);
    };
};

// Set expression envelope shape
~setExpressionShape = { |shape|
    ~ccControl.expressionShape = shape;
    ["Expression envelope shape set to", shape].postln;

    // Update running envelopes if needed
    if(~ccControl.enabled && ~activeMelodyProc.notNil) {
        var melodyKey = ~currentSequence[~currentMelodySetIndex];
        ~startCCEnvelopes.value(melodyKey);
    };
};

// Set expression envelope peak position
~setExpressionPeakPos = { |position|
    ~ccControl.expressionPeakPos = position.clip(0, 1);
    ["Expression envelope peak position set to", position].postln;

    // Update running envelopes if needed
    if(~ccControl.enabled && ~activeMelodyProc.notNil) {
        var melodyKey = ~currentSequence[~currentMelodySetIndex];
        ~startCCEnvelopes.value(melodyKey);
    };
};

// Set all CC parameters at once
~configureCCControl = { |params|
    params.keysValuesDo { |key, value|
        if(~ccControl.includesKey(key)) {
            ~ccControl[key] = value;
        };
    };

    ["CC control parameters updated:", params].postln;

    // Update running envelopes if needed
    if(~ccControl.enabled && ~activeMelodyProc.notNil) {
        var melodyKey = ~currentSequence[~currentMelodySetIndex];
        ~startCCEnvelopes.value(melodyKey);
    };
};
// ~stopAllMelodies.value;
//

// ~playAllMelodiesInSequence.value;


// =====================================================================
// Looping Melody Functionality
// =====================================================================

// Variable to track looping state
~loopingMelody = false;
~loopingMelodyKey = nil;
~loopingTask = nil;

// Function to start looping a specific melody
~startLoopingMelody = { |melodyKey|
    var pattern, noteCount, melodyDuration, totalWaitTime, currentNoteRest;
    var initialCycle = ~currentCycle; // Track initial cycle to detect changes
    var initialMelody = melodyKey;

    // Initialize last note duration tracking
    ~lastNoteDuration = nil;

    // Stop any currently playing melody or loop
    ~stopLoopingMelody.value;
    ~stopAllMelodies.value;

    // Set looping state
    ~loopingMelody = true;
    ~loopingMelodyKey = melodyKey;

    // Debug: Log current noteRest value
    ["DEBUG: Current ~noteRest value:", ~noteRest].postln;

    // Get pattern info once (doesn't change)
    pattern = ~melodyDict[melodyKey].patterns[0];
    noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});

    ["Starting loop of melody:", melodyKey, "with", noteCount, "notes"].postln;

    // Create a task that will keep playing the melody
    ~loopingTask = Task({
        var proc, isPaused = false, cycleChanged = false;

        while({ ~loopingMelody }) {
            // --- Check for and release previous fermata note ---
            if(~lastFermataNote.notNil) {
                ["LoopingMelody: Releasing previous fermata note:", ~lastFermataNote].postln;
                NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                ~lastFermataNote = nil;

                if(~activeBendSynths.size > 0) {
                    ["LoopingMelody: Clearing active bend synths"].postln;
                    ~activeBendSynths.do(_.free);
                    ~activeBendSynths.clear;
                };
            };
            // ---------------------------------------------------

            // Check if the cycle has changed
            if(initialCycle != ~currentCycle) {
                ["Cycle changed from", initialCycle, "to", ~currentCycle,
                 "- Updating to play from the new sequence"].postln;

                // Get the first melody from the new cycle
                melodyKey = ~developmentCycles[~currentCycle].sequence[0];

                // Update the pattern info for the new melody
                pattern = ~melodyDict[melodyKey].patterns[0];
                noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});

                // Update tracking variables
                initialCycle = ~currentCycle;
                initialMelody = melodyKey;
                cycleChanged = true;

                ["Now playing melody:", melodyKey, "from cycle:", ~currentCycle].postln;
            };

            // Check if we need to pause
            if(~modes.pauseNotesMode) {
                // Only print the message once when entering pause mode
                if(isPaused.not) {
                    ["PAUSED: Waiting until pause mode is disabled (CC 41)"].postln;
                    isPaused = true;
                };

                // Wait briefly then check again
                0.1.wait;
            } {
                // If we're not paused, proceed with normal playback

                // If we were paused and now we're not, print a message
                if(isPaused) {
                    ["RESUMING: Pause mode disabled, continuing playback"].postln;
                    isPaused = false;
                };

                // If the cycle changed, announce the new melody
                if(cycleChanged) {
                    ["Starting new melody:", melodyKey, "from cycle:", ~currentCycle].postln;
                    cycleChanged = false;
                };

                // Read the current MIDI controller values on each iteration
				// currentNoteRest = ~noteRest; // Default value
				// if(~midiController.notNil) {
				// 	currentNoteRest = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
				// 	// Get melody rest time from slider 4
				// 	~melodyRestTime = ~midiController.getSliderValue(4).linlin(0, 127, 0.0, 1.0);
				// 	["DEBUG: Using MIDI-controlled noteRest:", currentNoteRest, "melodyRestTime:", ~melodyRestTime].postln;
				// };
				//
                // Calculate duration based on current settings
                if(~lastNoteDuration.notNil) {
                    // If we know the last note's duration, use it for more precise timing
                    // Calculate wait time based on (n-1) regular notes + actual last note duration
                    melodyDuration = (noteCount - 1) * currentNoteRest + ~lastNoteDuration;
                    ["Using precise timing with last note duration:", ~lastNoteDuration].postln;
                } {
                    // First time through, use standard calculation
                    melodyDuration = noteCount * currentNoteRest;
                };

                totalWaitTime = melodyDuration;

                // Add melody rest if enabled (only if actually needed)
                // This will check the current value of ~modes.melodyRestMode on each iteration
                // so button toggles take effect immediately for the next loop cycle
                if(~modes.melodyRestMode) {
                    ["Adding melody rest of", ~melodyRestTime, "seconds (CC 45 is ON)"].postln;
                    totalWaitTime = totalWaitTime + ~melodyRestTime;
                    // Add fermata release rest if applicable
                    if(~modes.fermata) {
                        totalWaitTime = totalWaitTime + ~fermataReleaseRest;
                    };
                } {
                    ["No melody rest added (CC 45 is OFF)"].postln;
                };

                ["Iteration timing: noteRest:", currentNoteRest,
                 "lastNoteDur:", if(~lastNoteDuration.notNil, {~lastNoteDuration}, {"unknown"}),
                 "totalWaitTime:", totalWaitTime].postln;

                // Create a new ProcMod instance for this iteration
                proc = ~createMelodyProc.value(melodyKey);
                ~melodyProcs[melodyKey] = proc;

                // Start CC envelopes for this melody based on mode
                if(~loopingCCEnvelopes) {
                    ~startLoopingCCEnvelopes.value(melodyKey);
                } {
                    ~startCCEnvelopes.value(melodyKey);
                };

                // Play immediately without delay
                ["Playing melody iteration:", melodyKey].postln;
                proc.play;

                // Wait for melody to complete before playing again
                ["Waiting", totalWaitTime, "seconds before next iteration"].postln;
                totalWaitTime.wait;
            };
        };
    }).play;
};

// Function to stop looping
~stopLoopingMelody = {
    if(~loopingMelody) {
        ["Stopping loop of melody:", ~loopingMelodyKey].postln;
        ~loopingMelody = false;

        // Stop the looping task
        if(~loopingTask.notNil) {
            ~loopingTask.stop;
            ~loopingTask = nil;
        };

        ~loopingMelodyKey = nil;

        // Optionally stop the currently playing melody
        // ~stopAllMelodies.value;
    };
};
// =====================================================================
// Continuous Loop Sequence
// =====================================================================

// Variables to track the continuous loop sequence
// ~continuousLoopSequence = [\loop1, \loop2, \loop3, \loop4, \loop5, \loop6, \loop7, \loop8];
~continuousLoopSequence = [\loop1, \loop1a];
~currentLoopIndex = 0;
~currentLoopIteration = 0;
~continuousLoopTask = nil;
~continuousLoopRunning = false;

// Function to start playing all loops sequentially
~startContinuousLoopSequence = {
    var initialCycle = ~currentCycle; // Track initial cycle to detect change
    // Stop any currently playing melody or loop
    ~stopLoopingMelody.value;
    ~stopAllMelodies.value;

    if(~continuousLoopTask.notNil) {
        ~continuousLoopTask.stop;
    };

    // Reset tracking variables
    ~currentLoopIndex = 0;
    ~currentLoopIteration = 0;
    ~continuousLoopRunning = true;

    ["Starting continuous loop sequence with", ~continuousLoopSequence.size, "loops"].postln;

    // Create a task to manage the continuous loop sequence
    ~continuousLoopTask = Task({
        var currentLoopKey, loopCount, pattern, noteCount, currentNoteRest;
        var melodyDuration, totalWaitTime, proc, isPaused = false, cycleChanged = false;

        // Continue until manually stopped
        while({ ~continuousLoopRunning }) {
            // --- Check for and release previous fermata note ---
            if(~lastFermataNote.notNil) {
                ["ContinuousLoop: Releasing previous fermata note:", ~lastFermataNote].postln;
                NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                ~lastFermataNote = nil;

                if(~activeBendSynths.size > 0) {
                    ["ContinuousLoop: Clearing active bend synths"].postln;
                    ~activeBendSynths.do(_.free);
                    ~activeBendSynths.clear;
                };
            };
            // ---------------------------------------------------

            // Check if the cycle has changed FIRST
            if(initialCycle != ~currentCycle) {
                ["Cycle changed from", initialCycle, "to", ~currentCycle,
                 "- Updating to play from the new sequence"].postln;

                // Update continuous sequence based on the new cycle
                ~continuousLoopSequence = ~developmentCycles[~currentCycle].sequence;
				["~developmentCycles[~currentCycle].sequence: ", ~developmentCycles[~currentCycle].sequence].postln;
                // Reset sequence counters
                ~currentLoopIndex = 0;
                ~currentLoopIteration = 0;

                // Update tracking variable
                initialCycle = ~currentCycle;

                ["DEBUG: Cycle Change Detected! Assigning new sequence:", ~developmentCycles[~currentCycle].sequence].postln;
                ~continuousLoopSequence = ~developmentCycles[~currentCycle].sequence;

                // Reset sequence counters
                ~currentLoopIndex = 0;
                ~currentLoopIteration = 0;

                ["Now playing sequence from cycle:", ~currentCycle,
                 "with", ~continuousLoopSequence.size, "melodies"].postln;
            };

            // Check if we need to pause
            if(~modes.pauseNotesMode) {
                // Only print the message once when entering pause mode
                if(isPaused.not) {
                    ["PAUSED: Waiting until pause mode is disabled (CC 41)"].postln;
                    isPaused = true;
                };

                // Wait briefly then check again
                0.1.wait;
            } {
                // If we're not paused, proceed with normal playback

                // If we were paused and now we're not, print a message
                if(isPaused) {
                    ["RESUMING: Pause mode disabled, continuing playback"].postln;
                    isPaused = false;
                };

                // --> ADDED DEBUG <--
                ["DEBUG: Pre-Select State:",
                 "currentCycle:", ~currentCycle,
                 "initialCycle:", initialCycle,
                 "contLoopSeq:", ~continuousLoopSequence,
                 "contLoopIdx:", ~currentLoopIndex].postln;

                // Get the current loop to play
                currentLoopKey = ~continuousLoopSequence[~currentLoopIndex];
                ["DEBUG: Selected Key:", currentLoopKey].postln;

                loopCount = ~melodyDict[currentLoopKey].loopCount ? 1; // Default to 1 if not specified

                ["Playing loop sequence:", currentLoopKey, "iteration", ~currentLoopIteration + 1, "of", loopCount].postln;

                // Get pattern info
                pattern = ~melodyDict[currentLoopKey].patterns[0];
                noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});

                // Get current rest time
                currentNoteRest = ~noteRest;
                if(~midiController.notNil) {
                    currentNoteRest = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
                };

                // Calculate wait time
                if(~lastNoteDuration.notNil) {
                    melodyDuration = (noteCount - 1) * currentNoteRest + ~lastNoteDuration;
                } {
                    melodyDuration = noteCount * currentNoteRest;
                };

                totalWaitTime = melodyDuration;

                // Check real-time melody rest mode setting (affected by CC 45)
                if(~modes.melodyRestMode) {
                    ["Loop sequence: Adding melody rest of", ~melodyRestTime, "seconds (CC 45 is ON)"].postln;
                    totalWaitTime = totalWaitTime + ~melodyRestTime;
                } {
                    ["Loop sequence: No melody rest (CC 45 is OFF)"].postln;
                };

                // Create and play a new ProcMod for this iteration
                proc = ~createMelodyProc.value(currentLoopKey);
                ~melodyProcs[currentLoopKey] = proc;

                // Start CC envelopes
                if(~loopingCCEnvelopes) {
                    ~startLoopingCCEnvelopes.value(currentLoopKey);
                } {
                    ~startCCEnvelopes.value(currentLoopKey);
                };

                // Play immediately
                proc.play;

                // Wait for melody to complete
                ["Waiting", totalWaitTime, "seconds before next iteration"].postln;
                totalWaitTime.wait;

                // Increment counters and check if we need to move to next loop
                ~currentLoopIteration = ~currentLoopIteration + 1;

                if(~currentLoopIteration >= loopCount) {
                    // Move to next loop
                    ~currentLoopIteration = 0;
                    ~currentLoopIndex = (~currentLoopIndex + 1) % ~continuousLoopSequence.size;
                    ["Moving to next loop:", ~continuousLoopSequence[~currentLoopIndex]].postln;
                };
            };
        };
    }).play;
};

// Function to stop the continuous loop sequence
~stopContinuousLoopSequence = {
    ["Stopping continuous loop sequence"].postln;
    ~continuousLoopRunning = false;

    if(~continuousLoopTask.notNil) {
        ~continuousLoopTask.stop;
        ~continuousLoopTask = nil;
    };

    // Optionally stop any currently playing melody
    ~stopAllMelodies.value;
};

// Example usage:
// ~startContinuousLoopSequence.value;  // Start playing through all loops
// ~stopContinuousLoopSequence.value;   // Stop the sequence

// ~startLoopingMelody.value(\loop1);
// ~stopLoopingMelody.value;
// Example usage:
// ~startLoopingMelody.value(\set1);  // Start looping melody set1
// ~stopLoopingMelody.value;          // Stop the loop
// ~playAllMelodiesInSequence.value;
// ~playMelody.value(\set1);

// Function to update CC control expression range from MIDI knobs
~updateExpressionRangeFromKnobs = {
    if(~midiController.notNil) {
        // Use knob 1 (index 0) for minimum (0-63 range)
        ~ccControl.expressionMin = ~midiController.getKnobValue(0).linlin(0, 127, 0, 127).asInteger;

        // Use knob 2 (index 1) for maximu-m (64-127 range)
        ~ccControl.expressionMax = ~midiController.getKnobValue(1).linlin(0, 127, 0, 127).asInteger;

        // Make sure max is always greater than min
        if(~ccControl.expressionMax <= ~ccControl.expressionMin) {
            ~ccControl.expressionMax = ~ccControl.expressionMin + 1;
        };

        ["Expression range updated from knobs: min:", ~ccControl.expressionMin,
         "max:", ~ccControl.expressionMax].postln;
    };
};

// Function to calculate bend value from percentage
~calcBendValue = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range (0-16383, center at 8192)
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383); // Ensure within valid range
};

