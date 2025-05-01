// ==================== CHORD BEND LOOPING DEMONSTRATION ====================
// This file demonstrates how to use the looping functionality of the chord bend system

// Load the main chord bend system
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "chord-bend-independent.scd").load;

// Ensure everything is reset
~cleanupChordBend.value;

// ==================== SIMPLE LOOPING DEMONSTRATION ====================
(
// Simple demo of looping bend
"Setting up simple looping demo with default parameters".postln;

// Set up default notes and parameters
~startChord = [92, 92, 92];  // Default to note 92 for each tuba
~bendPercents = [20, 25, 30]; // Different bend percentages for each tuba
~bendDurations = [1.0, 1.2, 1.4]; // Time to reach peak bend
~returnDurations = [1.0, 1.2, 1.4]; // Time to return from peak
~bendCurves = [\sin, \welch, \exponential]; // Different curve shapes
~returnCurves = [\sin, \exponential, \welch]; // Return curve shapes

// Set up expression parameters
~exprCC = [17, 17, 17]; // Use CC 17 (dynamics) for all tubas
~exprStartLevels = [20, 25, 30]; // Starting expression levels
~exprAttackTimes = [0.5, 0.6, 0.7]; // Time to reach peak expression
~exprPeakLevels = [100, 110, 120]; // Peak expression levels
~exprReleaseTimes = [0.5, 0.6, 0.7]; // Time to return from peak expression
~exprEndLevels = [20, 25, 30]; // Ending expression levels

// Set up the looping system with a 4 second total loop duration
~setupLoopingChordBend.value(4);

"Ready to start looping with ~startLoopingBend.value;".postln;
"Stop with ~stopLoopingBend.value;".postln;
)

// Start the looping
~startLoopingBend.value;

// ... listen for a while ...

// Stop the looping
~stopLoopingBend.value;

// ==================== USING PRESETS WITH LOOPING ====================
(
// 1. Load and play a preset with looping enabled
"Loading and playing the 'looping-moderate' preset".postln;
~loadPreset.value("looping-moderate");

// Start the looping bend using preset's loop duration
~setupLoopingChordBend.value(~loopDuration);
~startLoopingBend.value;
)

// Stop the moderate looping preset
~stopLoopingBend.value;

// Load and play the fast looping preset
(
"Loading and playing the 'looping-fast' preset".postln;
~loadPreset.value("looping-fast");

// Start the looping bend using preset's loop duration
~setupLoopingChordBend.value(~loopDuration);
~startLoopingBend.value;
)

// Stop the fast looping preset
~stopLoopingBend.value;

// ==================== CREATE A CUSTOM LOOPING PRESET ====================
(
// Create a custom looping preset with custom parameters
~setBendParams.value(
    [92, 92, 92],     // Start notes for each tuba
    [92, 92, 92],     // End notes for each tuba
    [10, 15, 20],     // Bend percentages (% of octave)
    [0.3, 0.3, 0.3],  // Bend durations (time to reach peak bend)
    [0.7, 0.7, 0.7],  // Return durations (time to return from peak)
    [\sin, \sin, \sin],  // Bend curves
    [\sin, \sin, \sin],  // Return curves
    [17, 17, 17],     // Expression CC numbers (dynamics controller)
    [30, 30, 30],     // Expression start levels (0-127)
    [0.2, 0.2, 0.2],  // Expression attack times (time to reach peak)
    [90, 90, 90],     // Expression peak levels (0-127)
    [0.5, 0.5, 0.5],  // Expression release times (time to return from peak)
    [40, 40, 40],     // Expression end levels (0-127)
    true,             // Looping enabled
    2.0               // Loop duration in seconds (2 seconds per cycle)
);

// Save this as a new preset
~savePreset.value("custom-looping");

// Start the looping
~setupLoopingChordBend.value(~loopDuration);
~startLoopingBend.value;
)

// Stop the custom looping
~stopLoopingBend.value;

// ==================== PLAYING A SEQUENCE OF PRESETS WITH MIXED LOOPING ====================
(
// Create a task to play a sequence of presets, some with looping
var sequenceTask = Task({
    // 1. Play a non-looping preset
    "Playing non-looping preset 'fast-wave'".postln;
    ~loadPreset.value("fast-wave");
    ~chordBendTask.play;
    (~bendDurations.maxItem + ~returnDurations.maxItem + 1).wait;
    
    // 2. Play a looping preset
    "Playing looping preset 'looping-fast'".postln;
    ~loadPreset.value("looping-fast");
    ~setupLoopingChordBend.value(~loopDuration);
    ~startLoopingBend.value;
    (4 * ~loopDuration).wait; // Play for 4 full loops
    ~stopLoopingBend.value;
    2.wait; // Pause between presets
    
    // 3. Play another non-looping preset
    "Playing non-looping preset 'slow-wave'".postln;
    ~loadPreset.value("slow-wave");
    ~chordBendTask.play;
    (~bendDurations.maxItem + ~returnDurations.maxItem + 1).wait;
    
    // 4. Finish with custom looping preset
    "Playing custom looping preset".postln;
    ~loadPreset.value("custom-looping");
    ~setupLoopingChordBend.value(~loopDuration);
    ~startLoopingBend.value;
    (3 * ~loopDuration).wait; // Play for 3 full loops
    ~stopLoopingBend.value;
    
    "Sequence complete.".postln;
});

// You can manually execute the task
"Ready to play preset sequence. Run sequenceTask.play; to start".postln;

// Make it accessible
~demoSequence = sequenceTask;
)

// Start the demo sequence
~demoSequence.play;

// If needed, stop the sequence before it completes
// ~demoSequence.stop;

// Final cleanup
~cleanupChordBend.value;