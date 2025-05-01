// Chord Bend with ProcMod - Expanded Implementation
// This file expands on the basic ProcMod implementation to include
// advanced chord bends, expression control, MIDI integration, and presets

// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// ===== CONFIGURATION =====

// Default parameters (will be customizable via MIDI or code)
~defaultParams = (
    // Notes for each tuba (MIDI note numbers) - C3, G2, C2 by default
    startChord: [92, 92, 92],

    // Bend amount in percentage (+/- 100%)
    bendPercents: [20, 20, 20],

    // Time to reach peak bend (seconds)
    bendDurations: [5.0, 7.5, 10.0],

    // Expression levels for each tuba (0-127)
    exprLevels: [100, 110, 120],

    // Expression attack/decay times (seconds)
    exprDurations: [1.0, 1.2, 1.4],

    // Envelope settings
    attackTime: 0.1,
    sustainTime: 8.0,
    releaseTime: 0.5,

    // Pitch bend curve shape
    bendCurve: \sin,

    // Expression curve shape
    exprCurve: \sin
);

// Create storage for presets
~presets = Dictionary.new;

// Add the default preset
~presets.put(\default, ~defaultParams.copy);

// ===== HELPER FUNCTIONS =====

// Function to calculate bend value from percentage
~calcBendPercent = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range (0-16383, center at 8192)
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383); // Ensure within valid range
};

// Function to create envelope based on parameters
~createEnvelope = { |params|
    Env(
        [0, 1, 1, 0],
        [params.attackTime, params.sustainTime, params.releaseTime],
        \sin,
        2  // Release node index
    );
};

// ===== PROCMOD IMPLEMENTATION =====

// Storage for active synths
~bendSynths = Array.newClear(3);
~exprSynths = Array.newClear(3);
~loopingSynths = Array.newClear(3);  // For looping mode

// Container for ProcMods
~tubaProcMods = Array.newClear(3);

// Create ProcMods for each tuba
3.do { |i|
    var tubaProcMod;
    var vstKey = ("vsti" ++ i).asSymbol;

    // Create the amplitude envelope
    ~procEnv = ~createEnvelope.(~defaultParams);

    // Create a ProcMod for this tuba
    tubaProcMod = ProcMod.new(
        ~procEnv,     // Envelope
        1.0,          // Amplitude
        ("tuba" ++ i).asSymbol,  // ID
        nil,          // Group (create new)
        0,            // addAction
        1,            // target

        // Main function - will be called when ProcMod is played
        { |group, envbus|
            var vst = ~vstList[vstKey];
            var params = ~currentParams ? ~defaultParams;
            var note = params.startChord[i];
            var bendPercent = params.bendPercents[i];
            var bendDur = params.bendDurations[i];
            var exprLevel = params.exprLevels[i];
            var exprDur = params.exprDurations[i];
            var bendValue = ~calcBendPercent.(bendPercent);
            var bendSynth, exprSynth;
            var result;

            // Store info in environment variables
            ~activeNotes = ~activeNotes ? Dictionary.new;
            ~activeNotes.put(i, (
                group: group,
                envbus: envbus,
                note: note
            ));

            if(vst.notNil) {
                // Log the action
                ("Tuba " ++ i ++ " playing note: " ++ note).postln;

                // Send note on to VST
                vst.midi.noteOn(i, note, 100);

                // Regular (non-looping) mode
                if(~loopingMode.not) {
                    // Create bend envelope synth
                    bendSynth = Synth(\BendEnvelope, [
                        \start, 8192,               // Center
                        \peak, bendValue,           // Calculated bend
                        \end, 8192,                 // Return to center
                        \peakTime, bendDur,         // Time to reach peak
                        \returnTime, bendDur * 0.5, // Time to return
                        \chanIndex, i,
                        \peakCurve, params.bendCurve,
                        \returnCurve, params.bendCurve
                    ], group);

                    // Store reference to the synth
                    ~bendSynths[i] = bendSynth;

                    // Create expression envelope synth
                    exprSynth = Synth(\ExpressionEnvelope, [
                        \start, 0,
                        \peak, exprLevel,
                        \end, 0,
                        \attackTime, exprDur,
                        \releaseTime, exprDur * 0.5,
                        \chanIndex, i,
                        \ccNum, 11,  // Expression control CC number
                        \attackCurve, params.exprCurve,
                        \releaseCurve, params.exprCurve
                    ], group);

                    // Store reference to the synth
                    ~exprSynths[i] = exprSynth;
                } {
                    // Looping mode - use looping variants of the synths
                    bendSynth = Synth(\BendEnvelopeLoop, [
                        \start, 8192,               // Center
                        \peak, bendValue,           // Calculated bend
                        \end, 8192,                 // Return to center
                        \delayTime, 0,              // No initial delay
                        \peakTime, bendDur,         // Time to reach peak
                        \returnTime, bendDur * 0.5, // Time to return
                        \loopDuration, bendDur * 2, // Total loop duration
                        \chanIndex, i,
                        \timeOffset, i * 0.5,       // Stagger tubas
                        \peakCurve, params.bendCurve,
                        \returnCurve, params.bendCurve,
                        \delayCurve, \lin
                    ], group);

                    // Store reference to the looping synth
                    ~loopingSynths[i] = bendSynth;

                    // Create looping expression envelope synth
                    exprSynth = Synth(\ExpressionEnvelopeLoop, [
                        \start, 0,
                        \peak, exprLevel,
                        \end, 0,
                        \delayTime, 0,
                        \attackTime, exprDur,
                        \releaseTime, exprDur * 0.5,
                        \loopDuration, exprDur * 2,
                        \chanIndex, i,
                        \ccNum, 11,                 // Expression control CC number
                        \timeOffset, i * 0.25,      // Stagger slightly differently
                        \attackCurve, params.exprCurve,
                        \releaseCurve, params.exprCurve,
                        \delayCurve, \lin
                    ], group);

                    // Store reference to the looping synth
                    ~loopingSynths[i + 3] = exprSynth;  // Use indices 3-5 for expression synths
                };

                // Simply return a dummy task - not crucial for functionality
                result = Task({
                    // Wait for the bend to complete
                    (bendDur * 1.5).wait;
                    // This task completes and is used to signal success
                });

                // Return the task
                result;
            } {
                ("ERROR: VST not found for tuba " ++ i).postln;
                nil;
            };
            
            // Schedule note off when the envelope would naturally finish
            // (only in non-looping mode)
            if(~loopingMode.not && vst.notNil) {
                // Calculate total envelope duration
                var totalDuration = params.attackTime + params.sustainTime + params.releaseTime;
                
                // Schedule the noteOff to happen when the envelope completes
                SystemClock.sched(totalDuration, {
                    // Only execute if the ProcMod is still running (hasn't been manually released)
                    if(~tubaProcMods[i].isRunning) {
                        ("Auto-releasing tuba " ++ i ++ " note " ++ note ++ " after envelope completion").postln;
                        vst.midi.noteOff(i, note, 0);
                        
                        // Free the synths - they should be done by now
                        if(~bendSynths[i].notNil) {
                            ~bendSynths[i].free;
                            ~bendSynths[i] = nil;
                        };
                        
                        if(~exprSynths[i].notNil) {
                            ~exprSynths[i].free;
                            ~exprSynths[i] = nil;
                        };
                        
                        // Release the ProcMod itself - ends the process gracefully
                        ~tubaProcMods[i].release;
                    };
                    nil;
                });
            };
        },

        // Release function - runs after the ProcMod has fully released
        { |group, envbus|
            ("ProcMod for tuba " ++ i ++ " completed").postln;

            // Clean up any lingering synths if needed
            if(~bendSynths[i].notNil) {
                ~bendSynths[i].free;
                ~bendSynths[i] = nil;
            };

            if(~exprSynths[i].notNil) {
                ~exprSynths[i].free;
                ~exprSynths[i] = nil;
            };

            if(~loopingSynths[i].notNil) {
                ~loopingSynths[i].free;
                ~loopingSynths[i] = nil;
            };

            if(~loopingSynths[i + 3].notNil) {
                ~loopingSynths[i + 3].free;
                ~loopingSynths[i + 3] = nil;
            };
        },

        // onReleaseFunc - runs when release is triggered
        { |group, envbus|
            var vst = ~vstList[vstKey];
            var note = ~activeNotes[i].note;

            ("Releasing tuba " ++ i ++ " note " ++ note).postln;

            // Send note off to VST
            if(vst.notNil) {
                vst.midi.noteOff(i, note, 0);
            };

            // Free the synths based on mode
            if(~loopingMode.not) {
                // Regular synths
                if(~bendSynths[i].notNil) {
                    // Don't immediately free - let the envelopes complete naturally
                    ~bendSynths[i] = nil;
                };

                if(~exprSynths[i].notNil) {
                    // Don't immediately free - let the envelopes complete naturally
                    ~exprSynths[i] = nil;
                };
            } {
                // Looping synths - need to be stopped immediately
                if(~loopingSynths[i].notNil) {
                    ~loopingSynths[i].free;
                    ~loopingSynths[i] = nil;
                };

                if(~loopingSynths[i + 3].notNil) {
                    ~loopingSynths[i + 3].free;
                    ~loopingSynths[i + 3] = nil;
                };
            };
        }
    );

    // Store in our array
    ~tubaProcMods[i] = tubaProcMod;
};

// ===== PLAYBACK CONTROL FUNCTIONS =====

// Set default playback mode
~loopingMode = false;

// Function to toggle looping mode
~setLoopingMode = { |enabled|
    ~loopingMode = enabled;
    ("Looping mode " ++ (if(enabled, "enabled", "disabled"))).postln;
};

// Function to apply a preset
~applyPreset = { |presetName|
    var preset = ~presets[presetName];

    if(preset.notNil) {
        ~currentParams = preset.copy;
        ("Applied preset: " ++ presetName).postln;

        // Update synths if they are already running
        3.do { |i|
            if(~tubaProcMods[i].isRunning) {
                ~updateTubaParams.(i);
            };
        };
    } {
        ("Preset not found: " ++ presetName).postln;
    };
};

// Function to save a preset
~savePreset = { |presetName|
    ~presets.put(presetName, ~currentParams.copy);
    ("Saved preset: " ++ presetName).postln;
};

// Function to list all presets
~listPresets = {
    "Available presets:".postln;
    ~presets.keys.do { |key|
        key.postln;
    };
};

// Play a single tuba
~playTuba = { |tubaIndex|
    if((tubaIndex >= 0) && (tubaIndex < 3) && ~tubaProcMods[tubaIndex].notNil) {
        // Ensure ~currentParams exists
        ~currentParams = ~currentParams ? ~defaultParams.copy;

        ("Starting tuba " ++ tubaIndex).postln;
        ~tubaProcMods[tubaIndex].play;
    };
};

// Release a single tuba
~releaseTuba = { |tubaIndex|
    if((tubaIndex >= 0) && (tubaIndex < 3) && ~tubaProcMods[tubaIndex].notNil) {
        ("Releasing tuba " ++ tubaIndex).postln;
        ~tubaProcMods[tubaIndex].release;
    };
};

// Play all tubas (with optional offset)
~playAllTubas = { |withOffset=true|
    3.do { |i|
        var delay = if(withOffset, i * 0.5, 0);

        SystemClock.sched(delay, {
            ~playTuba.(i);
            nil;
        });
    };
};

// Release all tubas (with optional offset)
~releaseAllTubas = { |withOffset=true|
    3.do { |i|
        var delay = if(withOffset, i * 0.5, 0);

        SystemClock.sched(delay, {
            ~releaseTuba.(i);
            nil;
        });
    };
};

// Function to update parameters for a specific tuba
~updateTubaParams = { |tubaIndex|
    var bendSynth, exprSynth, loopingSynth, loopingExprSynth;
    var bendValue, bendDur, exprLevel, exprDur;

    // Ensure we're using the current parameters
    ~currentParams = ~currentParams ? ~defaultParams.copy;

    // Calculate new values
    bendValue = ~calcBendPercent.(~currentParams.bendPercents[tubaIndex]);
    bendDur = ~currentParams.bendDurations[tubaIndex];
    exprLevel = ~currentParams.exprLevels[tubaIndex];
    exprDur = ~currentParams.exprDurations[tubaIndex];

    // Update based on current mode
    if(~loopingMode.not) {
        // Update regular synths
        bendSynth = ~bendSynths[tubaIndex];
        exprSynth = ~exprSynths[tubaIndex];

        if(bendSynth.notNil) {
            bendSynth.set(\peak, bendValue);
            bendSynth.set(\peakTime, bendDur);
            bendSynth.set(\returnTime, bendDur * 0.5);
            bendSynth.set(\peakCurve, ~currentParams.bendCurve);
            bendSynth.set(\returnCurve, ~currentParams.bendCurve);
        };

        if(exprSynth.notNil) {
            exprSynth.set(\peak, exprLevel);
            exprSynth.set(\attackTime, exprDur);
            exprSynth.set(\releaseTime, exprDur * 0.5);
            exprSynth.set(\attackCurve, ~currentParams.exprCurve);
            exprSynth.set(\releaseCurve, ~currentParams.exprCurve);
        };
    } {
        // Update looping synths
        loopingSynth = ~loopingSynths[tubaIndex];
        loopingExprSynth = ~loopingSynths[tubaIndex + 3];

        if(loopingSynth.notNil) {
            loopingSynth.set(\peak, bendValue);
            loopingSynth.set(\peakTime, bendDur);
            loopingSynth.set(\returnTime, bendDur * 0.5);
            loopingSynth.set(\loopDuration, bendDur * 2);
            loopingSynth.set(\peakCurve, ~currentParams.bendCurve);
            loopingSynth.set(\returnCurve, ~currentParams.bendCurve);
        };

        if(loopingExprSynth.notNil) {
            loopingExprSynth.set(\peak, exprLevel);
            loopingExprSynth.set(\attackTime, exprDur);
            loopingExprSynth.set(\releaseTime, exprDur * 0.5);
            loopingExprSynth.set(\loopDuration, exprDur * 2);
            loopingExprSynth.set(\attackCurve, ~currentParams.exprCurve);
            loopingExprSynth.set(\releaseCurve, ~currentParams.exprCurve);
        };
    };

    ("Updated parameters for tuba " ++ tubaIndex).postln;
};

// Function to update all parameters at once
~updateAllParams = { |paramName, valueArray|
    if(~currentParams.notNil && valueArray.notNil && (valueArray.size == 3)) {
        // Update the current parameters
        ~currentParams[paramName] = valueArray;

        // Update all active tubas
        3.do { |i|
            if(~tubaProcMods[i].isRunning) {
                ~updateTubaParams.(i);
            };
        };

        ("Updated " ++ paramName ++ " for all tubas: " ++ valueArray).postln;
    };
};

// ===== MIDI CONTROL INTEGRATION =====

// MIDI control enabled flag
~midiControlEnabled = false;

// Function to update parameters from MIDI
~updateParamsFromMIDI = {
    var exprLevel, exprDuration;

    if(~midiController.notNil && ~midiControlEnabled) {
        // Ensure current params exist
        ~currentParams = ~currentParams ? ~defaultParams.copy;

        // Map sliders 1-3 to bend percentages (0-100%)
        3.do { |i|
            ~currentParams.bendPercents[i] = ~midiController.getSliderValue(i).linlin(0, 127, 0, 100);
        };

        // Map sliders 4-6 to bend durations (0.5-15 seconds)
        3.do { |i|
            ~currentParams.bendDurations[i] = ~midiController.getSliderValue(i+3).linlin(0, 127, 0.5, 15.0);
        };

        // Map slider 7 to expression levels for all channels (0-127)
        exprLevel = ~midiController.getSliderValue(6).linlin(0, 127, 0, 127);
        3.do { |i|
            ~currentParams.exprLevels[i] = exprLevel;
        };

        // Map slider 8 to expression durations for all channels (0.1-5.0 seconds)
        exprDuration = ~midiController.getSliderValue(7).linlin(0, 127, 0.1, 5.0);
        3.do { |i|
            ~currentParams.exprDurations[i] = exprDuration;
        };

        // Update parameters for active tubas
        3.do { |i|
            if(~tubaProcMods[i].isRunning) {
                ~updateTubaParams.(i);
            };
        };
    };
};

// Create the MIDI update routine
~midiUpdateRoutine = Routine({
    inf.do {
        ~updateParamsFromMIDI.value;
        0.05.wait; // Update at 20Hz
    };
});

// Function to enable MIDI control
~enableMIDIControl = { |enable=true|
    ~midiControlEnabled = enable;

    if(enable) {
        if(~midiController.notNil) {
            ~midiUpdateRoutine.reset.play;
            "MIDI control enabled".postln;
        } {
            "MIDI controller not available".postln;
        };
    } {
        ~midiUpdateRoutine.stop;
        "MIDI control disabled".postln;
    };
};

// ===== PRESET SEQUENCE SYSTEM =====

// Create a system for sequencing through presets
~presetSequence = [];
~sequenceIsPlaying = false;
~currentSequenceStep = 0;

// Function to add a preset step to the sequence
~addPresetStep = { |presetName, duration|
    ~presetSequence = ~presetSequence.add((
        preset: presetName,
        duration: duration
    ));
    ("Added preset " ++ presetName ++ " for " ++ duration ++ " seconds to sequence").postln;
};

// Function to clear the sequence
~clearPresetSequence = {
    ~presetSequence = [];
    "Preset sequence cleared".postln;
};

// Function to start the preset sequence
~startPresetSequence = {
    if(~presetSequence.size > 0) {
        ~sequenceIsPlaying = true;
        ~currentSequenceStep = 0;

        // Process the first step
        ~processSequenceStep.(~currentSequenceStep);
        "Preset sequence started".postln;
    } {
        "No preset sequence defined".postln;
    };
};

// Function to stop the preset sequence
~stopPresetSequence = {
    ~sequenceIsPlaying = false;
    "Preset sequence stopped".postln;
};

// Function to process a sequence step
~processSequenceStep = { |stepIndex|
    var step = ~presetSequence[stepIndex];

    if(step.notNil && ~sequenceIsPlaying) {
        // Apply the preset
        ~applyPreset.(step.preset);

        // Play all tubas if not already playing
        3.do { |i|
            if(~tubaProcMods[i].isRunning.not) {
                ~playTuba.(i);
            };
        };

        // Schedule the next step
        SystemClock.sched(step.duration, {
            if(~sequenceIsPlaying) {
                ~currentSequenceStep = (~currentSequenceStep + 1) % ~presetSequence.size;
                ~processSequenceStep.(~currentSequenceStep);
            };
            nil;
        });
    };
};

// ===== CREATE EXAMPLE PRESETS =====

// Create some example presets with different bend parameters
~presets.put(\gentleBend, (
    startChord: [60, 55, 48],     // C3, G2, C2
    bendPercents: [10, 10, 10],   // Small bends
    bendDurations: [3.0, 3.5, 4.0], // Moderate durations
    exprLevels: [90, 100, 110],   // Medium expression levels
    exprDurations: [2.0, 2.2, 2.4], // Medium expression times
    attackTime: 0.1,
    sustainTime: 8.0,
    releaseTime: 0.5,
    bendCurve: \sin,
    exprCurve: \sin
));

~presets.put(\dramaticBend, (
    startChord: [60, 55, 48],     // C3, G2, C2
    bendPercents: [50, 40, 30],   // Large bends
    bendDurations: [1.0, 1.5, 2.0], // Fast durations
    exprLevels: [127, 120, 110],  // High expression levels
    exprDurations: [0.5, 0.7, 0.9], // Fast expression times
    attackTime: 0.05,
    sustainTime: 5.0,
    releaseTime: 0.3,
    bendCurve: \exp,
    exprCurve: \exp
));

~presets.put(\longUnison, (
    startChord: [48, 48, 48],     // All C2
    bendPercents: [20, -20, 10],  // Mixed directions
    bendDurations: [8.0, 10.0, 12.0], // Very long durations
    exprLevels: [80, 100, 120],   // Increasing expression
    exprDurations: [3.0, 4.0, 5.0], // Long expression times
    attackTime: 0.2,
    sustainTime: 15.0,
    releaseTime: 1.0,
    bendCurve: \sin,
    exprCurve: \lin
));

// Set current parameters to default
~currentParams = ~defaultParams.copy;

// ===== EXAMPLE PRESET SEQUENCE =====

// Clear existing sequence
~clearPresetSequence.value;

// Add steps to the sequence
~addPresetStep.(\default, 8);
~addPresetStep.(\gentleBend, 10);
~addPresetStep.(\dramaticBend, 6);
~addPresetStep.(\longUnison, 15);

"Chord Bend ProcMod system initialized.".postln;
"Available commands:".postln;
"  ~playTuba.(0-2) - Play individual tuba".postln;
"  ~releaseTuba.(0-2) - Release individual tuba".postln;
"  ~playAllTubas.value - Play all tubas".postln;
"  ~releaseAllTubas.value - Release all tubas".postln;
"  ~setLoopingMode.(true/false) - Toggle looping mode".postln;
"  ~enableMIDIControl.(true/false) - Toggle MIDI control".postln;
"  ~applyPreset.(\\presetName) - Apply a preset".postln;
"  ~listPresets.value - List available presets".postln;
"  ~startPresetSequence.value - Start preset sequence".postln;
"  ~stopPresetSequence.value - Stop preset sequence".postln;
)

// Examples of usage:

// Enable looping mode for continuous bend patterns
// ~setLoopingMode.(true);

// Play all tubas together with the default preset
~playAllTubas.value;

// Apply a different preset while playing
// ~applyPreset.(\dramaticBend);

// Enable MIDI control if available
// ~enableMIDIControl.(true);

// Start the preset sequence for an automated performance
// ~startPresetSequence.value;

// Stop all playback
~releaseAllTubas.value;
