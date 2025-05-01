// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "chord-bend-independentTask.scd").load;

(
// Test the bend calculation directly
"Testing bend calculation function:".postln;
~calcBendPercent.value(50);   // Should be above 8192
~calcBendPercent.value(-30);  // Should be below 8192
~calcBendPercent.value(75);   // Should be well above 8192

// Define chords and bend specs
~startChord = [92, 92, 92];   // Starting notes for each tuba
~endChord = [92, 92, 92];     // End/final notes for each tuba
~bendPercents = [20, 20, 20];  // Peak bend percentages for each tuba
~bendDurations = [10.0, 7.5, 6.0];  // Time to reach peak bend
~returnDurations = [10.0, 7.5, 6.0];     // Time to return from peak to end
~bendCurves = [\sin, \welch, \exponential];  // Curve shapes for bend up/down
~returnCurves = [\sin, \sine, \welch];  // Curve shapes for return

// Define expression envelope parameters
~exprCC = [17, 17, 17];       // Expression CC number for each tuba (default: 17 - dynamics controller)
~exprStartLevels = [11, 11, 11];  // Starting level for expression (0-127)
~exprAttackTimes = [0.1, 0.15, 0.2];    // Attack time in seconds
~exprPeakLevels = [100, 110, 120];      // Peak level (0-127)
~exprReleaseTimes = [1.0, 1.2, 1.4];    // Release time in seconds
~exprEndLevels = [25, 25, 25];   // Ending level for expression (0-127)

)

// Control commands
~chordBendTask.play;          // Start the chord transition
~chordBendTask.stop;          // Stop transition (if needed)

// Cleanup function to reset everything
(
~cleanupChordBend = {
    // Stop the task
    ~chordBendTask.stop;

    // Reset all VSTs and turn off any notes
    3.do { |index|
        var vstKey = (\vsti ++ index).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            vst.midi.bend(index, 8192);   // Reset pitch bend
            vst.midi.allNotesOff(index);  // Turn off any playing notes
            "Reset tuba %".format(index).postln;
        };
    };
    "All tubas reset.".postln;
};
)

// Execute cleanup
~cleanupChordBend.value;

// ==================== LOOPING CHORD BEND TASK ====================
(
// Create a looping version of the chord bend task
~setupLoopingChordBend = { |loopDuration=4|
    var loopingSynths = Array.newClear(3);
    var loopingExprSynths = Array.newClear(3);
    var activeNotes = Array.newClear(3);
    var isRunning = false;

    // Initialize expression parameters if not already defined
    if(~exprCC.isNil) { ~exprCC = [17, 17, 17] };
    if(~exprStartLevels.isNil) { ~exprStartLevels = [0, 0, 0] };
    if(~exprAttackTimes.isNil) { ~exprAttackTimes = [0.1, 0.1, 0.1] };
    if(~exprPeakLevels.isNil) { ~exprPeakLevels = [100, 100, 100] };
    if(~exprReleaseTimes.isNil) { ~exprReleaseTimes = [1.0, 1.0, 1.0] };
    if(~exprEndLevels.isNil) { ~exprEndLevels = [0, 0, 0] };

    // Task to start/stop the looping bend
    ~loopingChordBendTask = Task({
        var targetBends = Array.newClear(3);
        var vstKey, vst;

        if(isRunning) {
            "Stopping looping chord bend...".postln;

            // Free all synths
            loopingSynths.do { |synth| if(synth.notNil) { synth.free } };
            loopingExprSynths.do { |synth| if(synth.notNil) { synth.free } };

            // Turn off all notes
            activeNotes.do { |noteData|
                if(noteData.notNil) {
                    var vstIndex = noteData[0], note = noteData[1], vst = noteData[2];
                    vst.midi.noteOff(vstIndex, note, 0);
                    "Turned off note % on tuba %".format(note, vstIndex).postln;
                };
            };

            // Reset all bends to center
            3.do { |vstIndex|
                vstKey = (\vsti ++ vstIndex).asSymbol;
                vst = ~vstList[vstKey];
                if(vst.notNil) {
                    vst.midi.bend(vstIndex, 8192);  // Center position
                    "Reset bend for tuba % to center".format(vstIndex).postln;
                };
            };

            isRunning = false;
            "Looping chord bend stopped.".postln;
            ^this;
        };

        "Starting looping chord bend...".postln;
        "Using start chord: %".format(~startChord).postln;
        "Using peak bend percentages: %".format(~bendPercents).postln;
        "Using loop duration: % seconds".format(loopDuration).postln;

        isRunning = true;

        // Pre-calculate all bend values and store in array
        3.do { |i|
            targetBends[i] = ~calcBendPercent.value(~bendPercents[i]);
            "Pre-calculated bend for tuba %: %".format(i, targetBends[i]).postln;
        };

        // Reset all VSTs to center bend
        3.do { |vstIndex|
            vstKey = (\vsti ++ vstIndex).asSymbol;
            vst = ~vstList[vstKey];
            if(vst.notNil) {
                vst.midi.bend(vstIndex, 8192);  // Center position
                "Reset bend for % to center (8192)".format(vstKey).postln;
            } {
                "Warning: VST not found for %".format(vstKey).postln;
            };
        };

        // Short wait to ensure reset is applied
        0.1.wait;

        // Play notes and set up looping bend and expression envelopes
        3.do { |vstIndex|
            vstKey = (\vsti ++ vstIndex).asSymbol;
            vst = ~vstList[vstKey];

            if(vst.notNil) {
                var startNote = ~startChord[vstIndex];
                var bendPercent = ~bendPercents[vstIndex];
                var bendDuration = ~bendDurations[vstIndex];
                var returnDuration = ~returnDurations[vstIndex];
                var bendCurve = ~bendCurves[vstIndex];
                var returnCurve = ~returnCurves[vstIndex];
                var targetBend = targetBends[vstIndex];
                var cycleDuration = bendDuration + returnDuration;

                // Expression envelope parameters with safeguards against nil
                var exprCC = ~exprCC[vstIndex] ? 17;  // Default to CC 17 (dynamics) if nil
                var exprStartLevel = ~exprStartLevels[vstIndex] ? 0;
                var attackTime = ~exprAttackTimes[vstIndex] ? 0.1;
                var peakLevel = ~exprPeakLevels[vstIndex] ? 100;
                var releaseTime = ~exprReleaseTimes[vstIndex] ? (bendDuration + returnDuration - 0.5).max(0.1);
                var exprEndLevel = ~exprEndLevels[vstIndex] ? 0;

                // Play the note
                vst.midi.noteOn(vstIndex, startNote, 100);  // Velocity 100
                activeNotes[vstIndex] = [vstIndex, startNote, vst];
                "Playing note % on tuba %".format(startNote, vstIndex).postln;

                // Start the looping bend envelope
                loopingSynths[vstIndex] = Synth(\BendEnvelopeLoop, [
                    \start, 8192,              // Start at center
                    \peak, targetBend,         // Peak bend from calculation
                    \end, 8192,                // Return to center
                    \peakTime, bendDuration,   // Time to reach peak
                    \returnTime, returnDuration, // Time to return from peak
                    \loopDuration, loopDuration, // Total duration of one loop cycle
                    \chanIndex, vstIndex,      // Which VST to control
                    \peakCurve, bendCurve,     // Curve for reaching peak
                    \returnCurve, returnCurve  // Curve for returning
                ]);

                // Start the looping expression envelope
                loopingExprSynths[vstIndex] = Synth(\ExpressionEnvelopeLoop, [
                    \start, exprStartLevel,    // Use configured start level
                    \peak, peakLevel,          // Uses ~exprPeakLevels
                    \end, exprEndLevel,        // Use configured end level
                    \attackTime, attackTime,   // Uses ~exprAttackTimes
                    \releaseTime, releaseTime, // Uses ~exprReleaseTimes
                    \loopDuration, loopDuration, // Total duration of one loop cycle
                    \chanIndex, vstIndex,
                    \ccNum, exprCC,
                    \attackCurve, bendCurve,
                    \releaseCurve, returnCurve
                ]);

                "Tuba %: Looping bend between center and %% (bend value: %) with % sec cycle"
                .format(vstIndex, bendPercent, targetBend, loopDuration).postln;

                "Tuba %: Looping expression - CC: %, range: % to % to %"
                .format(vstIndex, exprCC, exprStartLevel, peakLevel, exprEndLevel).postln;
            } {
                "Error: VST not found for tuba %".format(vstIndex).postln;
            };
        };
    });

    // Method to start the looping
    ~startLoopingBend = {
        if(isRunning) {
            "Looping bend already running. Stop it first.".postln;
        } {
            ~loopingChordBendTask.reset.play;
        };
    };

    // Method to stop the looping
    ~stopLoopingBend = {
        if(isRunning) {
            ~loopingChordBendTask.reset.play;  // This will execute the stop logic
        } {
            "Looping bend not running.".postln;
        };
    };

    // Return the task for convenience
    ~loopingChordBendTask;
};

// Setup with a default loop duration of 4 seconds
~setupLoopingChordBend.value(4);

"Looping chord bend system initialized.".postln;
"Use ~startLoopingBend.value; to start and ~stopLoopingBend.value; to stop".postln;
)

// ==================== PRESET MANAGEMENT SYSTEM ====================
(
// Store presets in a dictionary with descriptive names
~bendPresets = Dictionary.new;

// Function to save a preset with all current parameters
~savePreset = { |name|
    var preset = (
        startChord: ~startChord.copy,
        endChord: ~endChord.copy,
        bendPercents: ~bendPercents.copy,
        bendDurations: ~bendDurations.copy,
        returnDurations: ~returnDurations.copy,
        bendCurves: ~bendCurves.copy,
        returnCurves: ~returnCurves.copy,

        // Add expression parameters
        exprCC: ~exprCC.copy,
        exprStartLevels: ~exprStartLevels.copy,
        exprAttackTimes: ~exprAttackTimes.copy,
        exprPeakLevels: ~exprPeakLevels.copy,
        exprReleaseTimes: ~exprReleaseTimes.copy,
        exprEndLevels: ~exprEndLevels.copy,

        // Add looping parameters
        loopEnabled: ~loopEnabled ? false,
        loopDuration: ~loopDuration ? 4
    );

    ~bendPresets[name] = preset;
    "Saved preset '%'".format(name).postln;
    preset;
};

// Function to load a preset by name
~loadPreset = { |name|
    var preset = ~bendPresets[name];

    if(preset.notNil) {
        ~startChord = preset.startChord.copy;
        ~endChord = preset.endChord.copy;
        ~bendPercents = preset.bendPercents.copy;
        ~bendDurations = preset.bendDurations.copy;
        ~returnDurations = preset.returnDurations.copy;
        ~bendCurves = preset.bendCurves.copy;
        ~returnCurves = preset.returnCurves.copy;

        // Load expression parameters if they exist in the preset
        if(preset.exprCC.notNil) { ~exprCC = preset.exprCC.copy; };
        if(preset.exprStartLevels.notNil) { ~exprStartLevels = preset.exprStartLevels.copy; };
        if(preset.exprAttackTimes.notNil) { ~exprAttackTimes = preset.exprAttackTimes.copy; };
        if(preset.exprPeakLevels.notNil) { ~exprPeakLevels = preset.exprPeakLevels.copy; };
        if(preset.exprReleaseTimes.notNil) { ~exprReleaseTimes = preset.exprReleaseTimes.copy; };
        if(preset.exprEndLevels.notNil) { ~exprEndLevels = preset.exprEndLevels.copy; };

        // Load looping parameters if they exist in the preset
        if(preset.loopEnabled.notNil) { ~loopEnabled = preset.loopEnabled; };
        if(preset.loopDuration.notNil) { ~loopDuration = preset.loopDuration; };

        "Loaded preset '%'".format(name).postln;
        "Start chord: %, End chord: %, Bend percentages: %"
        .format(~startChord, ~endChord, ~bendPercents).postln;

        "Expression parameters loaded - CC: %, Start: %, Peak: %"
        .format(~exprCC, ~exprStartLevels, ~exprPeakLevels).postln;

        if(preset.loopEnabled.notNil && preset.loopEnabled) {
            "Looping mode enabled with duration: % seconds"
            .format(~loopDuration).postln;
        };

        preset;
    } {
        "Preset '%' not found!".format(name).error;
        nil;
    };
};

// Function to list all saved presets
~listPresets = {
    if(~bendPresets.size > 0) {
        "Available presets:".postln;
        ~bendPresets.keysValuesDo { |name, preset|
            var loopStr = if(preset.loopEnabled == true, "loop: %s", "");
            "  %: % → %, bend %%, dur [% → %]%"
            .format(
                name,
                preset.startChord,
                preset.endChord,
                preset.bendPercents,
                preset.bendDurations,
                preset.returnDurations,
                if(preset.loopEnabled == true, ", loop: %s".format(preset.loopDuration), "")
            ).postln;
        };
    } {
        "No presets saved yet.".postln;
    };
};

// Function to play a sequence of presets
~playPresetSequence = { |presetNames, waitBetween = 2.0|
    var sequenceTask = Task({
        var totalDur; // Declare variable at start of function

        presetNames.do { |name, i|
            "Playing preset % (% of %)".format(name, i+1, presetNames.size).postln;

            // Load the preset
            ~loadPreset.value(name);

            // Check if this preset should be played in looping mode
            if(~loopEnabled == true) {
                // First ensure any previous non-looping task is stopped
                ~chordBendTask.stop;

                // Setup looping with the preset's duration
                ~setupLoopingChordBend.value(~loopDuration);

                // Start the looping bend
                ~startLoopingBend.value;

                // Wait for the specified duration plus loop duration
                totalDur = waitBetween + ~loopDuration;
                totalDur.wait;

                // Stop the looping bend
                ~stopLoopingBend.value;
            } {
                // Play regular non-looping bend
            ~chordBendTask.play;

            // Wait for it to complete plus additional wait time
            totalDur = ~bendDurations.maxItem + ~returnDurations.maxItem + waitBetween;
            totalDur.wait;
            };
        };

        "Sequence complete.".postln;
    });

    sequenceTask.play;
    sequenceTask; // Return the task so it can be stopped if needed
};

// Helper function to update parameters
~setBendParams = { |startChordNotes, endChordNotes, bendPercentages, peakDurations, returnDurations, peakCurves, returnCurves,
                   expressionCC, startLevels, attackTimes, peakLevels, releaseTimes, endLevels,
                   enableLooping=false, loopingDuration=4|
    ~startChord = startChordNotes;

    if(endChordNotes.notNil) {
        ~endChord = endChordNotes;
    };

    if(bendPercentages.notNil) {
        ~bendPercents = bendPercentages;
    };

    if(peakDurations.notNil) {
        ~bendDurations = peakDurations;
    };

    if(returnDurations.notNil) {
        ~returnDurations = returnDurations;
    };

    if(peakCurves.notNil) {
        ~bendCurves = peakCurves;
    };

    if(returnCurves.notNil) {
        ~returnCurves = returnCurves;
    };

    // Update expression parameters if provided
    if(expressionCC.notNil) {
        ~exprCC = expressionCC;
    };

    if(startLevels.notNil) {
        ~exprStartLevels = startLevels;
    };

    if(attackTimes.notNil) {
        ~exprAttackTimes = attackTimes;
    };

    if(peakLevels.notNil) {
        ~exprPeakLevels = peakLevels;
    };

    if(releaseTimes.notNil) {
        ~exprReleaseTimes = releaseTimes;
    };

    if(endLevels.notNil) {
        ~exprEndLevels = endLevels;
    };

    // Update looping parameters
    ~loopEnabled = enableLooping;
    ~loopDuration = loopingDuration;

    "Parameters updated: ".postln;
    "Start notes: %".format(startChordNotes).postln;
    "End notes: %".format(~endChord).postln;
    "Bend percentages: %".format(~bendPercents).postln;
    "Peak durations: %".format(~bendDurations).postln;
    "Return durations: %".format(~returnDurations).postln;
    "Peak curves: %".format(~bendCurves).postln;
    "Return curves: %".format(~returnCurves).postln;

    "Expression parameters:".postln;
    "CC numbers: %".format(~exprCC).postln;
    "Start levels: %".format(~exprStartLevels).postln;
    "Attack times: %".format(~exprAttackTimes).postln;
    "Peak levels: %".format(~exprPeakLevels).postln;
    "Release times: %".format(~exprReleaseTimes).postln;
    "End levels: %".format(~exprEndLevels).postln;

    if(enableLooping) {
        "Looping enabled with duration: % seconds".format(loopingDuration).postln;
    } {
        "Looping disabled".postln;
    };
};


// ==================== EXAMPLE PRESETS ====================

// Example with stronger bends and different curves
~setBendParams.value(
    [92, 92, 92],     // Start notes for each tuba
    [92, 92, 92],     // End notes for each tuba
    [20, 21, 22],     // Bend percentages (% of octave)
    [5.0, 4.0, 3.5],  // Bend durations (time to reach peak bend)
    [5.0, 4.0, 3.5],  // Return durations (time to return from peak)
    [\sin, \welch, \exponential],  // Bend curves
    [\sin, \exponential, \welch],  // Return curves
    [17, 17, 17],     // Expression CC numbers (dynamics controller)
    [20, 25, 30],     // Expression start levels (0-127)
    [5.0, 4.0, 3.5],  // Expression attack times (time to reach peak)
    [110, 100, 127],  // Expression peak levels (0-127)
    [5.0, 4.0, 3.5],  // Expression release times (time to return from peak)
    [20, 25, 30],     // Expression end levels (0-127)
    false,            // Looping disabled
    4                 // Default loop duration (not used when looping disabled)
);
~savePreset.value("fast-wave");

// Create a slow bend preset with longer durations
~setBendParams.value(
    [92, 92, 92],     // Start notes for each tuba
    [92, 92, 92],     // End notes for each tuba
    [20, 21, 22],     // Bend percentages (% of octave)
    [10.0, 7.5, 6],   // Bend durations (time to reach peak bend)
    [10.0, 7.5, 6],   // Return durations (time to return from peak)
    [\sin, \welch, \exponential],  // Bend curves
    [\sin, \exponential, \welch],  // Return curves
    [17, 17, 17],     // Expression CC numbers (dynamics controller)
    [40, 35, 30],     // Expression start levels (0-127)
    [0.5, 0.4, 0.3],  // Expression attack times (time to reach peak)
    [100, 105, 110],  // Expression peak levels (0-127)
    [3.0, 2.5, 2.0],  // Expression release times (time to return from peak)
    [40, 35, 30],     // Expression end levels (0-127)
    false,            // Looping disabled
    4                 // Default loop duration (not used when looping disabled)
);
~savePreset.value("slow-wave");

// Create a looping preset with moderate speed
~setBendParams.value(
    [92, 92, 92],     // Start notes for each tuba
    [92, 92, 92],     // End notes for each tuba
    [20, 21, 22],     // Bend percentages (% of octave)
    [1.5, 1.25, 1.0], // Bend durations (time to reach peak bend)
    [1.5, 1.25, 1.0], // Return durations (time to return from peak)
    [\sin, \welch, \exponential],  // Bend curves
    [\sin, \exponential, \welch],  // Return curves
    [17, 17, 17],     // Expression CC numbers (dynamics controller)
    [40, 35, 30],     // Expression start levels (0-127)
    [0.2, 0.15, 0.1], // Expression attack times (time to reach peak)
    [100, 105, 110],  // Expression peak levels (0-127)
    [0.2, 0.15, 0.1], // Expression release times (time to return from peak)
    [40, 35, 30],     // Expression end levels (0-127)
    true,             // Looping enabled
    3                 // Loop duration in seconds
);
~savePreset.value("looping-moderate");

// Create a fast looping preset with short cycles
~setBendParams.value(
    [92, 92, 92],     // Start notes for each tuba
    [92, 92, 92],     // End notes for each tuba
    [15, 16, 17],     // Bend percentages (% of octave)
    [0.5, 0.4, 0.3],  // Bend durations (time to reach peak bend)
    [0.5, 0.4, 0.3],  // Return durations (time to return from peak)
    [\sin, \sin, \sin],  // Bend curves
    [\sin, \sin, \sin],  // Return curves
    [17, 17, 17],     // Expression CC numbers (dynamics controller)
    [40, 35, 30],     // Expression start levels (0-127)
    [0.1, 0.08, 0.06], // Expression attack times (time to reach peak)
    [80, 85, 90],     // Expression peak levels (0-127)
    [0.1, 0.08, 0.06], // Expression release times (time to return from peak)
    [40, 35, 30],     // Expression end levels (0-127)
    true,             // Looping enabled
    1.5               // Loop duration in seconds (fast cycle)
);
~savePreset.value("looping-fast");
)
~loadPreset.value("slow-wave");
~chordBendTask.play;
~chordBendTask.stop;

// For quick reference
(
"To run the chord bend system:".postln;
"~chordBendTask.play; - Start the chord bend".postln;
"~cleanupChordBend.value; - Reset everything".postln;
"~savePreset.value(\"my-preset\"); - Save current settings as preset".postln;
"~loadPreset.value(\"my-preset\"); - Load a preset".postln;
"~listPresets.value; - List all available presets".postln;
"~playPresetSequence.value([\"fast-major\", \"g-to-c\"]); - Play multiple presets in sequence".postln;
)