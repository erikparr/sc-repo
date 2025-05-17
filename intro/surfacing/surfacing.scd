// surfacing-procmod-slim.scd
// A streamlined version of surfacing-procmod.scd using ProcMod for gestural control

// Load the setup files
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

// Load the melody dictionary
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "data/surfacing-melody.scd").load;

// =====================================================================
// MIDI Button Controls Setup
// =====================================================================


// Track last button state to implement toggle logic
~lastButtonState = Dictionary.new;

// Toggle Melody Rest mode (CC 45)
~toggleMelodyRest.free;
~toggleMelodyRest = MIDIdef.cc(\toggleMelodyRest, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only toggle on rising edge (0->127, button press)
    if(buttonPressed && (lastState == false)) {
        // Toggle the melody rest mode
        ~modes.melodyRestMode = ~modes.melodyRestMode.not;
        ["MIDI Button CC 45: Melody Rest mode",
            if(~modes.melodyRestMode, "ENABLED", "DISABLED"),
            "- Will take effect on next loop cycle"].postln;
    };

    // Remember current state for next time
    ~lastButtonState[ccNum] = buttonPressed;
}, 45);  // CC 45 for the button

// Add pause notes toggle control (CC 41)
~togglePauseNotes.free;
~togglePauseNotes = MIDIdef.cc(\togglePauseNotes, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only toggle on rising edge (0->127, button press)
    if(buttonPressed && (lastState == false)) {
        // Toggle the pause notes mode
        ~modes.pauseNotesMode = ~modes.pauseNotesMode.not;
        ["MIDI Button CC 41: Pause Notes toggled to",
            if(~modes.pauseNotesMode, "ON", "OFF"),
            "- Will take effect on next loop cycle"].postln;
    };

    // Remember current state for next time
    ~lastButtonState[ccNum] = buttonPressed;
}, 41);  // CC 41 for the button

// Add next cycle control (CC 59)
~nextCycle.free;
~nextCycle = MIDIdef.cc(\nextCycle, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only act on rising edge (0->127, button press)
    if(buttonPressed && (lastState == false)) {
        var nextCycle = ~currentCycle + 1;
        var numCycles = ~developmentCycles.size;

        // Wrap around if we go past the last cycle
        if(nextCycle > numCycles) {
            nextCycle = 1;
        };

        // Only switch if there's actually a change
        if(nextCycle != ~currentCycle) {
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

// Add previous cycle control (CC 58)
~prevCycle.free;
~prevCycle = MIDIdef.cc(\prevCycle, { |val, ccNum, chan, src|
    var buttonPressed = val > 0;
    var lastState = ~lastButtonState[ccNum] ? false;

    // Only act on rising edge (0->127, button press)
    if(buttonPressed && (lastState == false)) {
        var prevCycle = ~currentCycle - 1;
        var numCycles = ~developmentCycles.size;

        // Wrap around if we go below the first cycle
        if(prevCycle < 1) {
            prevCycle = numCycles;
        };

        // Only switch if there's actually a change
        if(prevCycle != ~currentCycle) {
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

// =====================================================================
// Global variables and settings
// =====================================================================

// Control parameters
~bpm = 298;
~noteDuration = 0.2;
~noteRest = 0.2;
~melodyRestTime = 0.025;  // Renamed from ~melodyRest for clarity
~fermataReleaseRest = 0.25;

// Flags for different behavior modes
~modes = (
    melodyRestMode: false,        // Enable longer rests between melodies (renamed from melodyRest)
    fermata: false,          // Hold the last note of each melody
    rampTempo: false,        // Progressively change note rest times
    velocityMultiply: true, // Apply velocity multipliers to first/last notes
    noteOffset: true,        // Apply note offset to all notes
    removeLast: false,       // Skip the last note in each melody
    pauseNotesMode: false    // When true, stop triggering new notes (toggled by CC 41)
);

// Control parameters
~noteOffset = -12;           // Semitones to offset notes (-12 = one octave down)
~repetitions = 1;            // Number of times to repeat each melody
~currentMelodySetIndex = 0;  // Current melody index
~currentCycle = 1;           // Current development cycle
~firstNoteRestMult = 1.0;    // Multiplier for the rest after the first note (1.0 - 2.0), controlled by knob index 6

// Collection to track active CC control synths
~activeCCSynths = Dictionary.new;
~activeNotes = Dictionary.new;
~lastFermataNote = nil;
~sequenceTask = nil;
~advancedCCsEnabled = false;
~loopingCCEnvelopes = false;


// =====================================================================
// CC Control Envelope System
// =====================================================================


// Expression CC control parameters
~ccControl = (
    enabled: true,                // Enable/disable the CC control
    expressionCC: 17,             // CC number for expression
    expressionMin: 10,            // Minimum expression value
    expressionMax: 120,           // Maximum expression value
    expressionShape: \sin,        // Envelope shape: \sin, \lin, \exp, etc.
    expressionPeakPos: 0.5,       // Position of peak in the envelope (0.0-1.0)
    expressionDurationScalar: 1.0, // Scalar for expression envelope duration (0.1 to 1.0)
    bowPressureCC: 23,            // CC for bow pressure (for future use)
);

// Function to calculate envelope duration based on current melody
~calcEnvelopeDuration = { |activeNoteRest|
    var melodyKey = ~currentSequence[~currentMelodySetIndex];
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
    var totalNoteDuration = noteCount * activeNoteRest * ~repetitions;

    totalNoteDuration;
};

// Function to start CC envelopes for the current melody
~startCCEnvelopes = { |melodyKey|
    var currentActualNoteRest, duration;
    var attackTime, releaseTime;
    var scaledExpressionDuration;

    // Update expression range from knobs AND duration scalar before creating envelopes
    ~updateExpressionRangeFromKnobs.value;
    ~updateExpressionDurationScalarFromKnob.value;

    // Determine the actual noteRestTime to be used
    if(~midiController.notNil) {
        currentActualNoteRest = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 1.0);
    } { // No MIDI controller, use global default
        currentActualNoteRest = ~noteRest;
    };

    duration = ~calcEnvelopeDuration.value(currentActualNoteRest); // This is the trueMelodyDuration
    scaledExpressionDuration = duration * ~ccControl.expressionDurationScalar;

    // Concise logging
    "Starting CC envelopes for true melody duration: %, scaled expr duration: %".format(duration, scaledExpressionDuration).postln;

    // Free any existing synths
    ~activeCCSynths.do { |synth|
        synth.free;
    };
    ~activeCCSynths = Dictionary.new;

    if(~ccControl.enabled) {
        // Calculate timing parameters based on SCALED expression envelope duration
        attackTime = scaledExpressionDuration * ~ccControl.expressionPeakPos;
        releaseTime = scaledExpressionDuration * (1.0 - ~ccControl.expressionPeakPos);

        // Create expression control synths for each VST
        ~vstManager.getInstances.keysValuesDo { |vstKey, vst, i|
            var ccSynth;
            "expression Max: %".format(~ccControl.expressionMax).postln;

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
    var currentActualNoteRest, duration;
    var attackTime, releaseTime, loopDuration;
    var scaledExpressionDuration;

    ~updateExpressionRangeFromKnobs.value;
    ~updateExpressionDurationScalarFromKnob.value;
    ~stopCCEnvelopes.value;

    if(~midiController.notNil) {
        currentActualNoteRest = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 1.0);
    } { currentActualNoteRest = ~noteRest; };

    duration = ~calcEnvelopeDuration.value(currentActualNoteRest); // This is trueDuration
    scaledExpressionDuration = duration * ~ccControl.expressionDurationScalar;
    "Starting looping CC envelopes for true duration: %, scaled expr duration: %".format(duration, scaledExpressionDuration).postln;

    if(~ccControl.enabled) {
        var exprAttackTime, exprReleaseTime, exprLoopDuration, instances;

        // Timings for the SCALED Expression Envelope (CC17)
        exprAttackTime = scaledExpressionDuration * ~ccControl.expressionPeakPos;
        exprReleaseTime = scaledExpressionDuration * (1.0 - ~ccControl.expressionPeakPos);
        exprLoopDuration = scaledExpressionDuration;

        // Base timings for any OTHER CC envelopes, derived from TRUE melody duration
        attackTime = duration * ~ccControl.expressionPeakPos; // Unscaled attack
        releaseTime = duration * (1.0 - ~ccControl.expressionPeakPos); // Unscaled release
        loopDuration = duration; // Unscaled loop

        // Create looping expression control synths for each VST (this is for CC17)
        instances = ~vstManager.getInstances;
        instances.keysValuesDo { |vstKey, vst, i|
            var ccSynth = Synth(\ccEnvelopeLoop, [
                \start, ~ccControl.expressionMin,
                \peak, ~ccControl.expressionMax,
                \end, ~ccControl.expressionMin,
                \delayTime, 0,
                \attackTime, exprAttackTime,       // Use scaled time for expression
                \releaseTime, exprReleaseTime,     // Use scaled time for expression
                \loopDuration, exprLoopDuration,   // Use scaled loop duration for expression
                \chanIndex, i,
                \ccNum, ~ccControl.expressionCC,
                \timeOffset, i * 0.25,
                \attackCurve, ~ccControl.expressionShape,
                \releaseCurve, ~ccControl.expressionShape,
                \delayCurve, \lin
            ]);
            ~activeCCSynths[vstKey] = ccSynth;
            "Created SCALED looping CC envelope synth for %".format(vstKey).postln;
        };

        if(~advancedCCsEnabled == true) {
            ~vstManager.getInstances.keysValuesDo { |vstKey, vst, i|
                var bowPressureSynth;
                bowPressureSynth = Synth(\ccEnvelopeLoop, [
                    \start, 20,
                    \peak, 100,
                    \end, 20,
                    \delayTime, i * 0.1,
                    \attackTime, attackTime * 0.8,  // Uses unscaled base attackTime
                    \releaseTime, releaseTime * 1.2, // Uses unscaled base releaseTime
                    \loopDuration, loopDuration * 1.1, // Uses unscaled base loopDuration
                    \chanIndex, i,
                    \ccNum, ~ccControl.bowPressureCC,
                    \timeOffset, i * 0.15,
                    \attackCurve, ~ccControl.expressionShape,
                    \releaseCurve, ~ccControl.expressionShape,
                    \delayCurve, \lin
                ]);
                ~activeCCSynths[vstKey ++ "_bowPressure"] = bowPressureSynth;
            };
        };
        "Looping CC control synths started".postln;
    }  {
        "CC Control disabled".postln;
    };
};

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

// Function to update CC control expression range from MIDI knobs
~updateExpressionRangeFromKnobs = {
    if(~midiController.notNil) {
        // Use knob 1 (index 0) for minimum (0-63 range)
        ~ccControl.expressionMin = ~midiController.getKnobValue(0).linlin(0, 127, 0, 0).asInteger;

        // Use knob 2 (index 1) for maximum (64-127 range)
        ~ccControl.expressionMax = ~midiController.getKnobValue(1).linlin(0, 127, 0, 127).asInteger;

        // Make sure max is always greater than min
        if(~ccControl.expressionMax <= ~ccControl.expressionMin) {
            ~ccControl.expressionMax = ~ccControl.expressionMin + 1;
        };

        ["Expression range updated from knobs: min:", ~ccControl.expressionMin,
         "max:", ~ccControl.expressionMax].postln;
    };
};

// Function to update CC control expression duration scalar from MIDI knob
~updateExpressionDurationScalarFromKnob = {
    if(~midiController.notNil) {
        // Use knob 4 (index 3) for expression duration scalar (10% to 100%)
        var scalar = ~midiController.getKnobValue(3).linlin(0, 127, 0.1, 1.0);
        if(~ccControl.expressionDurationScalar != scalar) { // Only update if value changed
            ~ccControl.expressionDurationScalar = scalar;
            ["Expression Duration Scalar (Knob 4) updated to:", scalar.round(0.01)].postln;
        };
    };
};


// =====================================================================
// Development Cycles
// =====================================================================


// Define development cycles
~developmentCycles = Dictionary.new;

// ~developmentCycles.put(1, (
// 	name: "Second Cycle",
// 	sequence: [\set3, \set3]
// ));
// ~developmentCycles.put(2, (
// 	name: "Second Cycle",
// 	sequence: [\set5, \set5]
// ));
// ~developmentCycles.put(3, (
// 	name: "Second Cycle",
// 	sequence: [\set6, \set6]
// ));
// ~developmentCycles.put(4, (
// 	name: "Second Cycle",
// 	sequence: [\set7, \set7]
// ));
// ~developmentCycles.put(5, (
// 	name: "Second Cycle",
// 	sequence: [\bridge2b]
// ));

~developmentCycles.put(1, (
name: "Second Cycle",
sequence: [\part5a]
));
~developmentCycles.put(2, (
name: "Second Cycle",
sequence: [\part5b]
));
~developmentCycles.put(3, (
name: "Second Cycle",
sequence: [\part5d]
));

~developmentCycles.put(4, (
name: "Second Cycle",
sequence: [\part5e]
));

~developmentCycles.put(5, (
name: "Second Cycle",
sequence: [\part3a]
));
~developmentCycles.put(6, (
name: "Second Cycle",
sequence: [\part3b]
));
~developmentCycles.put(7, (
name: "Second Cycle",
sequence: [\part3c]
));

// Initialize the current sequence
~currentSequence = ~developmentCycles[~currentCycle].sequence;

// =====================================================================
// Helper Functions
// =====================================================================

// Function to process a note based on current settings
~processNote = { |note, isFirstNote=false, isLastNote=false, melodyKey|
    var processedNote = note;
    var velocity = 0; // Default velocity
    var velocityMultiplier = 1.0;

    // Use MIDI controller if available
    if(~midiController.notNil) {
        velocity = ~midiController.getSliderValue(3).linlin(0, 127, 1, 127);
    };

    // Apply note offset if enabled
    if(~modes.noteOffset) {
        processedNote = (note + ~noteOffset).clip(0, 127);
    };

    // Apply velocity multipliers if enabled
    if(~modes.velocityMultiply) {
        if(isFirstNote) {
            // Get the numeric value from the 'first' key
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers[\first].asFloat;
        };
        if(isLastNote) {
            // Get the numeric value from the 'last' key
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers[\last].asFloat;
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

// Function to stop all notes regardless of melody state
~stopAllNotes = {
    // Stop each VST instance
    ~vstManager.getInstances.do { |vst|
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

// Initial defaults
~setMode.value(\fermata, true);
~setMode.value(\noteOffset, true);
~setRepetitions.value(1);
~setNoteOffset.value(-12);


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
    ~vstManager.getInstances.do { |item, index|
        var vstKey = (\vsti ++ index).asSymbol;
        var vst = ~vstManager.getInstances[vstKey];
        ["Playing on VST:", index].postln;
        vst.midi.noteOn(index, note, velocity);

        // Schedule note release unless it's a fermata note
        if(isFermata.not) {
            SystemClock.sched(duration, {
                ["Releasing note:", note, "on channel:", index].postln;
                vst.midi.noteOff(index, note, 0);
                nil;
            });
        };
    };
}, '/note/on');

// Add a new OSC responder for releasing fermata notes
OSCdef(\releaseFermata, { |msg, time, addr, recvPort|
    var note, instances;
    
    note = msg[1].asInteger;
    instances = ~vstManager.getInstances;

    ["Releasing fermata note:", note].postln;

    // Release the note on all VST instances
    instances.keysValuesDo { |vstKey, vst|
        var index = vstKey.asString.drop(4).asInteger; // Extract index from vsti0, vsti1, etc.
        vst.midi.noteOff(index, note, 0);
    };
}, '/note/release');

// =====================================================================
// ProcMod Implementation
// =====================================================================


// Variables to store ProcMod instances
~melodyProcs = Dictionary.new;
~activeMelodyProc = nil;

// Create a ProcMod for a melody
~createMelodyProc = { |melodyKey, patternIndex=0|
    var pattern = ~melodyDict[melodyKey].patterns[patternIndex];
    var id = (melodyKey ++ "_" ++ patternIndex).asSymbol;

    // Create an ASR envelope: quick attack, sustain at 1, quick release.
    // This sustains until ProcMod.release is called.
    var env = Env.asr(attackTime: 0.01, sustainLevel: 1.0, releaseTime: 0.1, curve: \lin);

    // Create the ProcMod for this melody
    ProcMod.new(
        env,          // Use ASR envelope
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
            var noteDuration = ~noteDuration;
            var noteRestTime = ~noteRest;
            var temporalAccent = 1;
            var knobRawValue; // Declare knobRawValue here

            // Use MIDI controller values if available
            if(~midiController.notNil) {
                noteDuration = ~midiController.getSliderValue(1).linlin(0, 127, 0.005, 0.5);
                noteRestTime = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
                temporalAccent = ~midiController.getSliderValue(5).linlin(0, 127, 0, 8);
                // Get melody rest time from slider 4
                ~melodyRestTime = ~midiController.getSliderValue(4).linlin(0, 127, 0.0, 1.0);

                // Read knob for firstNoteRestMult (using Knob Index 6 - the 7th knob)
                knobRawValue = ~midiController.getKnobValue(6);
                ~firstNoteRestMult = knobRawValue.linlin(0, 127, 1.0, 2.0);
                ["ProcMod Start: First Note Rest Mult (from Knob 7/Index 6) set to:",
                 ~firstNoteRestMult.round(0.01), "(raw:", knobRawValue, ")"].postln;
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
                        var actualWaitTime;
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

                        // Release any previous fermata note
                        if(~lastFermataNote.notNil) {
                            ["Releasing previous fermata note:", ~lastFermataNote].postln;
                            NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                            ~lastFermataNote = nil;
                        };

                        // Play the note with OSC
                        ["Playing note:", processedNote[0], "duration:", actualDuration,
                            "noteIndex:", noteIndex, "fermata:", isFermata,
                            "first:", isFirstNote, "last:", isLastNote,
                        ].postln;

                        NetAddr.localAddr.sendMsg('/note/on', 0, processedNote[0], processedNote[1],
                            actualDuration, isFermata.asInteger,
                            isFirstNote.asInteger, isLastNote.asInteger);

                        // Store fermata note for later release
                        if(isFermata) {
                            ~lastFermataNote = processedNote[0];
                        };

                        // Wait logic for first note rest multiplier
                        actualWaitTime = noteRestTime; // Default wait time
                        if (isFirstNote) {
                            actualWaitTime = noteRestTime * ~firstNoteRestMult;
                            ["First note's rest: applying ~firstNoteRestMult:", ~firstNoteRestMult.round(0.01),
                             "to base noteRestTime:", noteRestTime.round(0.01),
                             "-> Actual wait:", actualWaitTime.round(0.01)
                            ].postln;
                        } {
                            ["Subsequent note's rest: using base noteRestTime:", noteRestTime.round(0.01)].postln;
                        };
                        actualWaitTime.wait;

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
                ~vstManager.getInstances.do { |vst, index|
                    vst.midi.noteOff(index, noteInfo.note, 0);
                };
            };

            // Clear active notes
            ~activeNotes.clear;
        }
    );
};


// =====================================================================
// Continuous Loop Sequence
// =====================================================================


// Variables to track the continuous loop sequence
~continuousLoopSequence = [\set4a, \set4b, \set4c, \set4d, \set4e, \set4f, \set4g];
~currentLoopIndex = 0;
~currentLoopIteration = 0;
~continuousLoopTask = nil;
~continuousLoopRunning = false;

// Function to start playing all loops sequentially
~startContinuousLoopSequence = {
    var initialCycle = ~currentCycle; // Track initial cycle to detect change

    // Stop any currently playing melody or loop
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
            // Check if the cycle has changed FIRST
            if(initialCycle != ~currentCycle) {
                ["Cycle changed from", initialCycle, "to", ~currentCycle,
                 "- Updating to play from the new sequence"].postln;

                // Update continuous sequence based on the new cycle
                ~continuousLoopSequence = ~developmentCycles[~currentCycle].sequence;

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

                // Get the current loop to play
                currentLoopKey = ~continuousLoopSequence[~currentLoopIndex];
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

    // Stop any currently playing melody
    ~stopAllNotes.value;
};


// =====================================================================
// Initialization and Control
// =====================================================================


// Configure default settings
~setMode.value(\noteOffset, false);
~setMode.value(\fermata, true);
~setMode.value(\melodyRestMode, true);
~loopingCCEnvelopes = true;

// Initialize ProcMods for each melody in the current sequence
~currentSequence.do { |melodyKey|
    if(~melodyProcs[melodyKey].isNil) {
        ~melodyProcs[melodyKey] = ~createMelodyProc.value(melodyKey);
    };
};

// Usage instructions
"
=================================================================
SURFACING - TUBA - PERFORMANCE CONTROLS
=================================================================

Primary control function:
  ~startContinuousLoopSequence.value;  // Start the continuous sequence
  ~stopContinuousLoopSequence.value;   // Stop the sequence
  ~stopAllNotes.value;                 // Emergency stop all notes

MIDI Controls:
  CC 41: Toggle Pause Notes mode
  CC 45: Toggle Melody Rest mode
  CC 58: Previous Cycle
  CC 59: Next Cycle

  Sliders:
    1: Note Duration
    2: Note Rest Time
    3: Velocity
    4: Melody Rest Time
    5: Temporal Accent

  Knobs:
    1 (0): Expression Min
    2 (1): Expression Max
    4 (3): Expression Duration Scalar
    7 (6): First Note Rest Multiplier

=================================================================
".postln;
