// surfacing-procmod.scd
// A reimplementation of surfacing-ii.scd using ProcMod for better gestural control

// Load the setup files
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;


// =====================================================================
// Global variables and settings
// =====================================================================

// Control parameters
~bpm = 298;
~noteDuration = 0.2;
~noteRest = 0.2;
~melodyRest = 4.47;
~fermataReleaseRest = 0.25;

// Flags for different behavior modes
~modes = (
    melodyRest: true,        // Enable longer rests between melodies
    fermata: false,          // Hold the last note of each melody
    rampTempo: false,        // Progressively change note rest times
    velocityMultiply: false, // Apply velocity multipliers to first/last notes
    noteOffset: true,        // Apply note offset to all notes
    removeLast: false        // Skip the last note in each melody
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
    attackFactor: 0.4,            // Portion of melody duration for attack
    decayFactor: 0.6,             // Portion of melody duration for decay

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
    totalNoteDuration + (if(~modes.melodyRest, {~melodyRest}, {0}));
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

// Function specifically for using channel 0 for all VSTs
~startCCEnvelopesOnChannel0 = { |melodyKey|
    var duration = ~calcEnvelopeDuration.value;
    var attackTime, sustainTime, releaseTime;

    "=============================================".postln;
    "DEBUG: Starting CC Envelopes (CHANNEL 0 MODE)".postln;
    "Duration: %".format(duration).postln;
    "Active VSTs:".postln;
    ~vstList.keysValuesDo { |k, v|
        "  % -> %".format(k, v).postln;
    };
    "=============================================".postln;

    // Free any existing synths
    ~activeCCSynths.do { |synth|
        "Freeing CC synth: %".format(synth).postln;
        synth.free;
    };
    ~activeCCSynths.clear;

    if(~ccControl.enabled) {
        // Calculate timing parameters based on envelope duration
        attackTime = duration * ~ccControl.attackFactor * ~ccControl.expressionPeakPos;
        sustainTime = duration * 0.1; // Short sustain at peak
        releaseTime = duration * ~ccControl.decayFactor * (1 - ~ccControl.expressionPeakPos);

        "CC Control enabled (CHANNEL 0): true".postln;
        "Envelope timing - Attack: %, Sustain: %, Release: %".format(
            attackTime, sustainTime, releaseTime
        ).postln;

        // Create one synth for each VST
        ~vstList.keysValuesDo { |vstKey, vst, i|
            var ccSynth;

            "Creating CC envelope synth for % on channel 0".format(vstKey).postln;

            // Create a control synth
            ccSynth = Synth(\ccEnvelope, [
                \start, ~ccControl.expressionMin,
                \peak, ~ccControl.expressionMax,
                \end, ~ccControl.expressionMin,
                \attackTime, attackTime,
                \releaseTime, releaseTime,
                \chanIndex, i,
                \ccNum, ~ccControl.expressionCC,
                \attackCurve, ~ccControl.expressionShape,
                \releaseCurve, ~ccControl.expressionShape
            ]);

            // Store the synth in the dictionary
            ~activeCCSynths[vstKey] = ccSynth;
        };

        "CC control synths created (CHANNEL 0 MODE)".postln;
    }  {
        "CC Control disabled".postln;
    };

    "Finished setting up CC envelopes (CHANNEL 0 MODE)".postln;
    "=============================================".postln;
};

// Function to start looping CC envelopes
~startLoopingCCEnvelopes = { |melodyKey|
    var duration = ~calcEnvelopeDuration.value;
    var attackTime, releaseTime, loopDuration;

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
            ~startCCEnvelopesOnChannel0.(melodyKey);
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
            ~startCCEnvelopesOnChannel0.(melodyKey);
        };
    };
};

// Tuba Melody Dictionary
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 1.0    // Normal velocity for last note
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
        last: 1.0
    )
));

// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Initial Cycle",
    sequence: [\set1, \set1, \set1, \set1]
	// sequence: [\set1, \set1, \set1, \set1, \set3, \set3, \set5, \set5, \set6, \set6, \set7, \set7, \set1, \set1]
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

// Create a ProcMod for a melody
~createMelodyProc = { |melodyKey, patternIndex=0|
    var pattern = ~melodyDict[melodyKey].patterns[patternIndex];
    var id = (melodyKey ++ "_" ++ patternIndex).asSymbol;

    // Create an amplitude envelope with a release node
    var env = Env([0, 1, 1, 0], [0.1, pattern.size * ~noteRest * 1.2, 0.5], \sin, 2);

    // Create the ProcMod for this melody
    ProcMod.new(
        env,          // Envelope with release node
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
            var effectiveLength = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
            var notePlaying = false;
            var task;

            // Get duration parameters (use defaults if no controller)
            var noteDuration = ~noteDuration;
            var noteRestTime = ~noteRest;
            var temporalAccent = 1.5;

            // Use MIDI controller values if available
            if(~midiController.notNil) {
                noteDuration = ~midiController.getSliderValue(1).linlin(0, 127, 0.001, 0.3);
                noteRestTime = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
                temporalAccent = ~midiController.getSliderValue(5).linlin(0, 127, 0.75, 2);
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
                        var isFermata = isLastNote && ~modes.fermata && ~modes.melodyRest;
                        var actualDuration, processedNote;

                        // Process the note (apply offset, etc.)
                        processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);

                        // Adjust duration for first note accent
                        actualDuration = if(isFirstNote, {
                            noteDuration * temporalAccent
                        }, {
                            noteDuration
                        });

                        // Make sure duration doesn't exceed rest time
                        if(isFermata.not) {
                            var maxDuration = noteRestTime * 0.9;
                            if(actualDuration > maxDuration) {
                                actualDuration = maxDuration;
                            };
                        };

                        // Release any previous fermata note
                        if(~lastFermataNote.notNil) {
                            ["Releasing previous fermata note:", ~lastFermataNote].postln;
                            NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                            ~lastFermataNote = nil;
                        };

                        // Play the note with OSC
                        ["Playing note:", processedNote[0], "duration:", actualDuration,
                         "noteIndex:", noteIndex, "fermata:", isFermata,
                         "first:", isFirstNote, "last:", isLastNote].postln;

                        NetAddr.localAddr.sendMsg('/note/on', 0, processedNote[0], processedNote[1],
                            actualDuration, isFermata.asInteger,
                            isFirstNote.asInteger, isLastNote.asInteger);

                        // Store fermata note for later release
                        if(isFermata) {
                            ~lastFermataNote = processedNote[0];
                        };

                        // Wait before playing the next note
                        noteRestTime.wait;

                        // Advance to next note
                        noteIndex = noteIndex + 1;
                    };

                    // Post-pattern logic
                    if(repIndex < (~repetitions - 1)) {
                        // Add a brief wait between repetitions
                        (noteRestTime * 2).wait;
                    };
                };

                // After all repetitions, handle melody rest if enabled
                if(~modes.melodyRest) {
                    ["Taking a longer rest between melodies:", ~melodyRest, "seconds"].postln;
                    ~melodyRest.wait;

                    // Release fermata note after melody rest
                    if(~lastFermataNote.notNil) {
                        ["Releasing fermata note after melody rest:", ~lastFermataNote].postln;
                        NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);

                        // Wait for additional fermata release rest
                        ["Waiting for fermata release rest:", ~fermataReleaseRest, "seconds"].postln;
                        ~fermataReleaseRest.wait;

                        ~lastFermataNote = nil;
                    };
                };

                // Signal completion
                ["Melody", melodyKey, "completed"].postln;
            });

            // Start the task
            task.play;

            // Return the task so ProcMod can track it
            task;
        },

        // Release function - executes after ProcMod has fully released
        { |group, envbus|
            ["ProcMod for", id, "has completed release"].postln;

            // Clean up resources if needed
            ~activeNotes.clear;
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
            totalWaitTime = melodyDuration + ~melodyRest + 0.5; // Add a small buffer

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
        ~startCCEnvelopesOnChannel0.value(melodyKey);
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

    // Reset melody index
    ~currentMelodySetIndex = 0;

    // Clear any active notes
    ~activeNotes.clear;

    ["All melodies stopped"].postln;
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

// =====================================================================
// CC Control Profiles System
// =====================================================================

// Storage for different CC control profiles
~ccProfiles = Dictionary.new;

// Add the default profile (based on current settings)
~ccProfiles.put(\default, ~ccControl.copy);

// Create a few additional sample profiles
~ccProfiles.put(\gentle, (
    enabled: true,
    expressionCC: 17,
    expressionMin: 30,            // Lower minimum for gentler sound
    expressionMax: 80,            // Lower maximum to avoid overblowing
    expressionShape: \sin,        // Smooth sine shape
    expressionPeakPos: 0.7,       // Peak later in the phrase
    attackFactor: 0.6,            // Longer attack
    decayFactor: 0.4,             // Shorter decay
    bowPressureCC: 23,
    harmAGainCC: 25,
    harmBGainCC: 26,
    bowPressureAccentCC: 27,
    bowPositionCC: 28
));

~ccProfiles.put(\intense, (
    enabled: true,
    expressionCC: 17,
    expressionMin: 60,            // Higher minimum for more present sound
    expressionMax: 120,           // Higher maximum for intensity
    expressionShape: \exp,        // Exponential curve for more dramatic build
    expressionPeakPos: 0.4,       // Peak earlier in the phrase
    attackFactor: 0.3,            // Faster attack
    decayFactor: 0.7,             // Longer decay
    bowPressureCC: 23,
    harmAGainCC: 25,
    harmBGainCC: 26,
    bowPressureAccentCC: 27,
    bowPositionCC: 28
));

~ccProfiles.put(\pulsing, (
    enabled: true,
    expressionCC: 17,
    expressionMin: 40,
    expressionMax: 100,
    expressionShape: \sin,        // Sine shape works best for pulsing
    expressionPeakPos: 0.5,       // Centered peak
    attackFactor: 0.2,            // Very short attack for pulsing effect
    decayFactor: 0.2,             // Very short decay for pulsing effect
    bowPressureCC: 23,
    harmAGainCC: 25,
    harmBGainCC: 26,
    bowPressureAccentCC: 27,
    bowPositionCC: 28
));

// Function to list all available CC profiles
~listCCProfiles = {
    "Available CC Profiles:".postln;
    ~ccProfiles.keys.asList.sort.do { |key|
        var profile = ~ccProfiles[key];
        ("  " ++ key ++ ": min=" ++ profile.expressionMin ++
         ", max=" ++ profile.expressionMax ++
         ", shape=" ++ profile.expressionShape ++
         ", peakPos=" ++ profile.expressionPeakPos).postln;
    };
};

// Function to apply a CC profile
~applyCCProfile = { |profileName|
    var profile = ~ccProfiles[profileName];

    if(profile.notNil) {
        // Store the current profile name
        ~currentCCProfile = profileName;

        // Apply the profile settings
        ~ccControl = profile.copy;

        ["Applied CC profile:", profileName].postln;

        // Restart CC envelopes if they're already running
        if(~activeCCSynths.size > 0) {
            var melodyKey = ~currentSequence[~currentMelodySetIndex];
            ~stopCCEnvelopes.value;

            // Apply the appropriate type of envelope
            if(~loopingCCEnvelopes) {
                ~startLoopingCCEnvelopes.value(melodyKey);
            }  {
                ~startCCEnvelopesOnChannel0.value(melodyKey);
            };
        };

        ^true;
    } {
        ["Profile not found:", profileName].postln;
        ^false;
    };
};

// Function to save the current settings as a profile
~saveCurrentCCProfile = { |profileName|
    ~ccProfiles.put(profileName, ~ccControl.copy);
    ["Saved current settings as profile:", profileName].postln;
};

// Function to create a new CC profile with specified parameters
~createCCProfile = { |profileName, params|
    var newProfile = ~ccControl.copy; // Start with current settings

    // Update with provided parameters
    params.keysValuesDo { |key, value|
        if(newProfile.includesKey(key)) {
            newProfile[key] = value;
        } {
            ["Warning: Ignoring unknown parameter:", key].postln;
        };
    };

    // Save the new profile
    ~ccProfiles.put(profileName, newProfile);
    ["Created new CC profile:", profileName].postln;

    ^true;
};

// Function to create a sequence of CC profiles with automatically calculated timings
~createCCProfileSequence = { |profileNames, melodyDurations = nil|
    var sequence = List.new;
    var durations = melodyDurations ?? {
        // If no durations provided, use the same duration for each profile
        profileNames.collect { ~calcEnvelopeDuration.value * 1.2 }
    };

    // Ensure we have the same number of durations as profiles
    if(profileNames.size != durations.size) {
        ["Error: Number of profiles (", profileNames.size,
         ") does not match number of durations (", durations.size, ")"].postln;
        ^nil;
    };

    // Create the sequence
    profileNames.do { |name, i|
        var profile = ~ccProfiles[name];

        if(profile.notNil) {
            sequence.add((
                profile: name,
                duration: durations[i]
            ));
        } {
            ["Warning: Profile not found:", name, "- skipping in sequence"].postln;
        };
    };

    if(sequence.size > 0) {
        ~ccProfileSequence = sequence.asArray;
        ["Created CC profile sequence with", sequence.size, "profiles"].postln;
        ^true;
    } {
        ["Error: No valid profiles in sequence"].postln;
        ^false;
    };
};

// Function to play a sequence of CC profiles
~currentCCProfileSequenceIndex = 0;
~ccProfileSequenceActive = false;
~ccProfileSequence = [];

~startCCProfileSequence = {
    if(~ccProfileSequence.size > 0) {
        ~ccProfileSequenceActive = true;
        ~currentCCProfileSequenceIndex = 0;
        ~playCCProfileSequenceStep.value;
        ["Started CC profile sequence with", ~ccProfileSequence.size, "steps"].postln;
        ^true;
    } {
        "No CC profile sequence defined".postln;
        ^false;
    };
};

~stopCCProfileSequence = {
    ~ccProfileSequenceActive = false;
    "Stopped CC profile sequence".postln;
};

~playCCProfileSequenceStep = {
    var step = ~ccProfileSequence[~currentCCProfileSequenceIndex];

    if(step.notNil && ~ccProfileSequenceActive) {
        // Apply the profile
        ~applyCCProfile.value(step.profile);

        // Schedule the next step
        SystemClock.sched(step.duration, {
            if(~ccProfileSequenceActive) {
                ~currentCCProfileSequenceIndex =
                    (~currentCCProfileSequenceIndex + 1) % ~ccProfileSequence.size;
                ~playCCProfileSequenceStep.value;
            };
            nil;
        });
    };
};

// Set the initial CC profile
~currentCCProfile = \default;
~applyCCProfile.value(~currentCCProfile);

// =====================================================================
// Example profile sequence
// =====================================================================

// Create a sample CC profile sequence
~createCCProfileSequence.value([\default, \gentle, \intense, \pulsing], [8, 10, 5, 12]);

"  ~listCCProfiles.value - List available CC profiles".postln;
"  ~applyCCProfile.(\profileName) - Apply a CC profile".postln;
"  ~saveCurrentCCProfile.(\newName) - Save current settings as a profile".postln;
"  ~startCCProfileSequence.value - Start cycling through CC profiles".postln;
"  ~stopCCProfileSequence.value - Stop CC profile sequence".postln;


// Interface commands for direct control
// ~playAllMelodiesInSequence.value;  // Play through the entire sequence automatically
// ~stopAllMelodies.value;
// ~switchToCycle.value(1);
// ~stopAllNotes.value;
            ~playMelody.value(\set1);



