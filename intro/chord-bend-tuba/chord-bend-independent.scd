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
        exprEndLevels: ~exprEndLevels.copy
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

        "Loaded preset '%'".format(name).postln;
        "Start chord: %, End chord: %, Bend percentages: %"
        .format(~startChord, ~endChord, ~bendPercents).postln;

        "Expression parameters loaded - CC: %, Start: %, Peak: %"
        .format(~exprCC, ~exprStartLevels, ~exprPeakLevels).postln;

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
            "  %: % → %, bend %%, dur [% → %]"
            .format(
                name,
                preset.startChord,
                preset.endChord,
                preset.bendPercents,
                preset.bendDurations,
                preset.returnDurations
            ).postln;
        };
    } {
        "No presets saved yet.".postln;
    };
};

// Save current settings as a preset for reference
~savePreset.value("default");

// Function to play a sequence of presets
~playPresetSequence = { |presetNames, waitBetween = 2.0|
    var sequenceTask = Task({
        var totalDur; // Declare variable at start of function

        presetNames.do { |name, i|
            "Playing preset % (% of %)".format(name, i+1, presetNames.size).postln;

            // Load the preset
            ~loadPreset.value(name);

            // Play it
            ~chordBendTask.play;

            // Wait for it to complete plus additional wait time
            totalDur = ~bendDurations.maxItem + ~returnDurations.maxItem + waitBetween;
            totalDur.wait;
        };

        "Sequence complete.".postln;
    });

    sequenceTask.play;
    sequenceTask; // Return the task so it can be stopped if needed
};

// Helper function to update parameters
~setBendParams = { |startChordNotes, endChordNotes, bendPercentages, peakDurations, returnDurations, peakCurves, returnCurves,
                   expressionCC, startLevels, attackTimes, peakLevels, releaseTimes, endLevels|
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
};


// ==================== EXAMPLE PRESETS ====================

// Example with stronger bends and different curves
~setBendParams.value(
    [92, 92, 92],
    [92, 92, 92],
    [20, 21, 22],     // Full octave bend peaks
    [5.0, 4.0, 3.5],     // Peak durations
    [5.0, 4.0, 3.5],     // Peak durations
    [\sin, \welch, \exponential],  // Peak curves
    [\sin, \exponential, \welch],   // Return curves
    [17, 17, 17],      // Expression CC numbers (dynamics controller)
    [20, 25, 30],      // Expression start levels
    [5.0, 4.0, 3.5],  // Expression attack times
    [110, 100, 90],    // Expression peak levels
    [5.0, 4.0, 3.5],   // Expression release times
    [20, 25, 30]       // Expression end levels
);
~savePreset.value("fast-wave");

// Create a slow bend preset with longer durations
~setBendParams.value(
    [92, 92, 92],
    [92, 92, 92],
    [20, 21, 22],     // Full octave bend peaks
    [10.0, 7.5, 6],     // Peak durations - longer
    [10.0, 7.5, 6],     // Return durations - longer
    [\sin, \welch, \exponential],  // Peak curves
    [\sin, \exponential, \welch],   // Return curves
    [17, 17, 17],      // Expression CC numbers (dynamics controller)
    [40, 35, 30],      // Expression start levels - higher for slow bend
    [0.5, 0.4, 0.3],   // Expression attack times - slower attack for longer bends
    [100, 105, 110],   // Expression peak levels
    [3.0, 2.5, 2.0],   // Expression release times - longer release for longer bends
    [40, 35, 30]       // Expression end levels - match start levels
);
~savePreset.value("slow-wave");

// Create a G-to-C transition preset
~setBendParams.value(
    [92, 92, 92],
    [92, 92, 92],
    [20, 21, 22],     // Full octave bend peaks
    [10.0, 7.5, 6],     // Peak durations
    [10.0, 7.5, 6],     // Peak durations
    [\sin, \welch, \exponential],  // Peak curves
    [\sin, \exponential, \welch],   // Return curves
    [17, 17, 17],      // Expression CC numbers (dynamics controller)
    [0.5, 0.4, 0.3],   // Expression attack times - slower attack for longer bends
    [100, 105, 110],   // Expression peak levels
    [1.0, 0.9, 0.8],   // Expression decay times - longer decay for longer bends
    [75, 80, 85],      // Expression sustain levels
    [3.0, 2.5, 2.0]    // Expression release times - longer release for longer bends
);
~savePreset.value("slow-wave");
)
~loadPreset.value("fast-wave");
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