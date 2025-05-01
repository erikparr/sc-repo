// Chord Bend Granular System with ProcMod - Ripple Effect Version
// This file implements a granular triggering system with envelope-controlled timing between instances

// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// ===== CONFIGURATION =====

// Function to count available VST instruments
~countVSTInstruments = {
    var count = 0;
    if(~vstList.notNil) {
        ~vstList.keysValuesDo { |key, val|
            if(key.asString.beginsWith("vsti")) {
                count = count + 1;
            };
        };
    };
    count;
};

// Get number of VST instruments
~numInstruments = ~countVSTInstruments.value;
("Number of VST instruments found: " ++ ~numInstruments).postln;

// Default parameters
~defaultParams = (
    // Notes for each tuba (MIDI note numbers)
    noteArrays: Array.fill(~numInstruments, { [92, 92, 92, 92, 92] }), // Same note for each tuba

    // Bend amount in percentage (+/- 100%)
    bendPercents: Array.fill(~numInstruments, 20),

    // Relative durations (will be multiplied by grain duration)
    bendTimeRatios: Array.fill(~numInstruments, { |i|
        0.3 + (i / ~numInstruments * 0.6);  // Spread from 0.3 to 0.9
    }),

    // Expression levels for each tuba (0-127)
    exprLevels: Array.fill(~numInstruments, { |i|
        90 + (i * 5);  // Spread from 90 to 90+(n-1)*5
    }),

    // Relative durations (will be multiplied by grain duration)
    exprTimeRatios: Array.fill(~numInstruments, { |i|
        0.6 - (i / ~numInstruments * 0.4);  // Spread from 0.6 down to 0.2
    }),

    // Granular parameters
    initialGrainDuration: 5,    // Starting duration of each note/grain in seconds
    finalGrainDuration: 5,      // Ending duration of each note/grain in seconds
    globalDuration: 60.0,         // Total duration of the granular process

    // Ripple timing parameters
    initialInstanceDelay: 0.0,    // Initial delay between instances (seconds)
    peakInstanceDelay: 2.5,       // Peak delay between instances (seconds)
    finalInstanceDelay: 5.0,      // Final delay between instances (seconds)

    // Timing for ripple envelope
    riseTime: 0.4,                // Portion of total time to rise to peak (0-1)
    fallTime: 0.4,                // Portion of total time to fall from peak (0-1)

    // After playing all instances, how long to wait before next round
    initialCycleDelay: 0.5,       // Initial delay after a complete cycle (seconds)
    peakCycleDelay: 0.5,          // Peak delay after a complete cycle (seconds)
    finalCycleDelay: 0.5,         // Final delay after a complete cycle (seconds)

    // Envelope settings
    attackTime: 0.01,
    releaseTime: 0.05,

    // Bend and expression curve shapes
    bendCurve: \sin,
    exprCurve: \sin
);

// Function to calculate bend value from percentage
~calcBendPercent = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range (0-16383, center at 8192)
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383); // Ensure within valid range
};

// Create an envelope for grain duration evolution - properly normalized
~createGrainDurationEnv = {
    Env(
        [~defaultParams.initialGrainDuration, ~defaultParams.finalGrainDuration],
        [1.0], // Normalized duration (0-1)
        \lin
    );
};

// Create an envelope for controlling the delay between instruments - properly normalized
~createInstanceDelayEnv = {
    var riseTime = ~defaultParams.riseTime;
    var fallTime = ~defaultParams.fallTime;
    var sustainTime = 1.0 - riseTime - fallTime;

    // Create envelope with normalized times (0-1) and correct curves
    Env(
        [~defaultParams.initialInstanceDelay, ~defaultParams.peakInstanceDelay,
         ~defaultParams.peakInstanceDelay, ~defaultParams.finalInstanceDelay],
        [riseTime, sustainTime, fallTime],
        [\sin, \sin, \sin]
    );
};

// Create an envelope for controlling the delay between cycles - properly normalized
~createCycleDelayEnv = {
    var riseTime = ~defaultParams.riseTime;
    var fallTime = ~defaultParams.fallTime;
    var sustainTime = 1.0 - riseTime - fallTime;

    // Create envelope with normalized times (0-1) and correct curves
    Env(
        [~defaultParams.initialCycleDelay, ~defaultParams.peakCycleDelay,
         ~defaultParams.peakCycleDelay, ~defaultParams.finalCycleDelay],
        [riseTime, sustainTime, fallTime],
        [\sin, \sin, \sin]
    );
};

// Debug the envelope values
~testEnvelopeOutput = {
    var instanceDelayEnv = ~createInstanceDelayEnv.value;
    var cycleDelayEnv = ~createCycleDelayEnv.value;
    var totalDuration = ~defaultParams.globalDuration;

    10.do { |i|
        var normalizedTime = i / 9; // 0 to 1
        var instanceDelay = instanceDelayEnv.at(normalizedTime);
        var cycleDelay = cycleDelayEnv.at(normalizedTime);

        ("Time " ++ (normalizedTime * totalDuration).round(0.1) ++
         "s (" ++ (normalizedTime * 100).round(1) ++ "%) - " ++
         "Instance delay: " ++ instanceDelay.round(0.001) ++ "s, " ++
         "Cycle delay: " ++ cycleDelay.round(0.001) ++ "s").postln;
    };
};

// Force rebuild the ripple master to use new envelope values
~rebuildRippleMaster = {
    if(~rippleMaster.notNil && ~rippleMaster.isRunning) {
        ~rippleMaster.release;
    };
    ~rippleMaster = nil;
    ~rippleMaster = ~createRippleMaster.value;
    "Ripple master rebuilt with new envelope settings".postln;
};

// ===== GRANULAR SYSTEM IMPLEMENTATION =====

// State variables for granular system - dynamically sized to number of instruments
~grainState = Array.fill(~numInstruments, {
    (
        noteIndex: 0,            // Index in the note array
        grainCount: 0,           // Count of played grains
        currentProcMod: nil      // Reference to current ProcMod
    )
});

// The monophonic grain function - plays a single grain
~playGrain = { |tubaIndex, note, grainDuration|
    var vstKey = ("vsti" ++ tubaIndex).asSymbol;
    var vst = ~vstList[vstKey];
    var bendPercent = ~defaultParams.bendPercents[tubaIndex];
    var bendTimeRatio = ~defaultParams.bendTimeRatios[tubaIndex];
    var exprLevel = ~defaultParams.exprLevels[tubaIndex];
    var exprTimeRatio = ~defaultParams.exprTimeRatios[tubaIndex];

    // Calculate actual durations based on the current grain duration
    var bendDur = grainDuration * bendTimeRatio;
    var exprDur = grainDuration * exprTimeRatio;
    var bendValue = ~calcBendPercent.(bendPercent);

    // Play note
    vst.midi.noteOn(tubaIndex, note, 30);

    // Create bend envelope synth
    Synth(\BendEnvelope, [
        \start, 8192,
        \peak, bendValue,
        \end, 8192,
        \peakTime, bendDur * 0.5,
        \returnTime, bendDur * 0.5,
        \chanIndex, tubaIndex,
        \peakCurve, ~defaultParams.bendCurve,
        \returnCurve, ~defaultParams.bendCurve
    ]);

    // Create expression envelope synth
    Synth(\ExpressionEnvelope, [
        \start, 0,
        \peak, exprLevel,
        \end, 0,
        \attackTime, bendDur * 0.5,
        \releaseTime, bendDur * 0.5,
        \chanIndex, tubaIndex,
        \ccNum, 11,
        \attackCurve, ~defaultParams.exprCurve,
        \releaseCurve, ~defaultParams.exprCurve
    ]);

    // Return the grain info
    (
        note: note,
        duration: grainDuration
    );
};

// ===== ENSEMBLE RIPPLE IMPLEMENTATION =====

// Master ProcMod for controlling the entire ripple process
~rippleMaster = nil;

// Create the master ripple process controller
~createRippleMaster = {
    var masterProcEnv;

    // Create the overall envelope for the master process
    masterProcEnv = Env([0, 1, 1, 0],
                   [~defaultParams.attackTime,
                    ~defaultParams.globalDuration - ~defaultParams.attackTime - ~defaultParams.releaseTime,
                    ~defaultParams.releaseTime],
                   [\sin, \lin, \sin],
                   1);  // Sustain node index

    // Create the master ProcMod
    ~rippleMaster = ProcMod.new(
        masterProcEnv,       // Envelope
        1.0,                 // Amplitude
        \rippleMaster,       // ID
        nil,                 // Group (create new)
        0,                   // addAction
        1,                   // target

        // Main function - controls the ripple process
        { |group, envbus|
            var resultTask;
            var durationEnv = ~createGrainDurationEnv.value;
            var instanceDelayEnv = ~createInstanceDelayEnv.value;
            var cycleDelayEnv = ~createCycleDelayEnv.value;

            ("Starting ripple granular process with " ++ ~numInstruments ++ " tubas").postln;
            ("Will run until full envelope shape (100%) is completed, regardless of time").postln;

            // Create a task for managing the ensemble ripple process
            resultTask = Task({
                var startTime = SystemClock.seconds;
                var elapsedSeconds = 0;
                var totalDuration = ~defaultParams.globalDuration;
                var instanceDelay, cycleDelay, currentGrainDuration;
                var normalizedTime = 0, cycleCount = 0;
                var progressPerCycle, estimatedCycles, waitTime;

                // Calculate progress increment and estimated cycle count
                if(~numInstruments > 0) {
                    var avgDelay = (~defaultParams.initialInstanceDelay + ~defaultParams.peakInstanceDelay) / 2;
                    var avgCycleDelay = (~defaultParams.initialCycleDelay + ~defaultParams.peakCycleDelay) / 2;
                    var estimatedCycleDuration = (avgDelay * ~numInstruments) + avgCycleDelay;

                    if(estimatedCycleDuration > 0) {
                        progressPerCycle = estimatedCycleDuration / totalDuration;
                        estimatedCycles = (1.0 / progressPerCycle).round(1).asInteger;
                        ("Estimated " ++ estimatedCycles ++ " cycles to complete full envelope").postln;
                    };
                };

                // Run until normalized time reaches 1.0 (100% completion)
                while { normalizedTime < 1.0 } {
                    // Get current timing parameters from envelopes at this normalized time
                    currentGrainDuration = durationEnv.at(normalizedTime);
                    instanceDelay = instanceDelayEnv.at(normalizedTime);
                    cycleDelay = cycleDelayEnv.at(normalizedTime);

                    // Debug output for every cycle
                    ("Cycle " ++ cycleCount ++
                     " - Elapsed: " ++ elapsedSeconds.round(0.1) ++ "s (" ++ (normalizedTime * 100).round(1) ++ "%)" ++
                     " - Grain dur: " ++ currentGrainDuration.round(0.001) ++
                     "s, Instance delay: " ++ instanceDelay.round(0.001) ++
                     "s, Cycle delay: " ++ cycleDelay.round(0.001) ++ "s").postln;

                    // Play through all instruments with current timing
                    ~numInstruments.do { |i|
                        var note = ~defaultParams.noteArrays[i][0];
                        var vst = ~vstList[("vsti" ++ i).asSymbol];
                        var state = ~grainState[i];

                        if(vst.notNil) {
                            // Create a grain for this instrument
                            var grain = ~playGrain.(i, note, currentGrainDuration);

                            // Count this grain
                            state.grainCount = state.grainCount + 1;

                            // Debug output (less frequent)
                            if(state.grainCount % 5 == 0) {
                                ("Tuba " ++ i ++ " grain " ++ state.grainCount ++
                                 ": note " ++ note ++
                                 ", duration " ++ currentGrainDuration.round(0.001) ++ "s").postln;
                            };

                            // Schedule note release just before next grain
                            SystemClock.sched(currentGrainDuration - 0.05, {
                                if(vst.notNil) {
                                    vst.midi.noteOff(i, grain.note, 0);
                                };
                                nil;
                            });

                            // Wait between instrument activations (ripple effect)
                            if(i < (~numInstruments-1)) {
                                instanceDelay.wait;
                            };
                        };
                    };

                    // Wait for the full grain duration before starting the next cycle
                    // This ensures we don't start a new cycle until the current notes have fully played
                     waitTime = max(currentGrainDuration - (~numInstruments * instanceDelay).abs, 0) + cycleDelay;
                    ("Waiting " ++ waitTime.round(0.01) ++ "s before next cycle (grain: " ++ currentGrainDuration ++ "s, cycle delay: " ++ cycleDelay ++ "s)").postln;
                    waitTime.wait;

                    // Wait after completing a full cycle through all instruments
                    //cycleDelay.wait;

                    // Update elapsed time based on real clock time
                    elapsedSeconds = SystemClock.seconds - startTime;
                    cycleCount = cycleCount + 1;

                    // Calculate normalized time based on progress through cycles, not just time
                    // This ensures we complete the full envelope shape
                    if(estimatedCycles.notNil && (estimatedCycles > 0)) {
                        normalizedTime = min(cycleCount / estimatedCycles, 1.0);
                    }  {
                        // Fallback to time-based normalization if we can't estimate cycles
                        normalizedTime = elapsedSeconds / totalDuration;
                    };
                };

                ("Ripple granular process completed with " ++ cycleCount ++ " cycles").postln;
                ("Total duration: " ++ elapsedSeconds.round(0.1) ++ "s").postln;
            });

            // Return the task - ProcMod handles it
            resultTask;
        },

        // releaseFunc - runs after the process is complete
        { |group, envbus|
            ("Ripple granular process completed").postln;

            // Make sure all notes are released
            ~numInstruments.do { |i|
                var vstKey = ("vsti" ++ i).asSymbol;
                var vst = ~vstList[vstKey];
                if(vst.notNil) {
                    vst.midi.allNotesOff(i);
                };
            };
        }
    );

    ~rippleMaster;  // Return the created ProcMod
};

// ===== PLAYBACK CONTROL FUNCTIONS =====

// Start the ripple granular process
~startRippleProcess = {
    // Create the ripple master if not already created
    if(~rippleMaster.isNil) {
        ~rippleMaster = ~createRippleMaster.value;
    };

    // Only play if not already running
    if(~rippleMaster.isRunning.not) {
        "Starting ripple granular process".postln;
        ~rippleMaster.play;
    } {
        "Ripple granular process is already running".postln;
    };
};

// Stop the ripple granular process
~stopRippleProcess = {
    if(~rippleMaster.notNil && ~rippleMaster.isRunning) {
        "Stopping ripple granular process".postln;
        ~rippleMaster.release;
    } {
        "Ripple granular process is not running".postln;
    };
};

// Update parameters for the ripple process
~updateRippleParams = { |paramName, value|
    if(~defaultParams[paramName].notNil) {
        ~defaultParams[paramName] = value;
        ("Updated ripple parameter: " ++ paramName ++ " = " ++ value).postln;
    } {
        ("Unknown parameter: " ++ paramName).postln;
    };
};

// Set ripple timing parameters
~setRippleTiming = { |initialDelay=0.0, peakDelay=0.5, finalDelay=0.0,
                     initialCycleDelay=0.5, peakCycleDelay=2.0, finalCycleDelay=0.5|
    ~defaultParams.initialInstanceDelay = initialDelay;
    ~defaultParams.peakInstanceDelay = peakDelay;
    ~defaultParams.finalInstanceDelay = finalDelay;
    ~defaultParams.initialCycleDelay = initialCycleDelay;
    ~defaultParams.peakCycleDelay = peakCycleDelay;
    ~defaultParams.finalCycleDelay = finalCycleDelay;
    "Updated ripple timing parameters".postln;
};

// Set notes for a specific tuba
~setNotes = { |tubaIndex, note|
    if((tubaIndex >= 0) && (tubaIndex < ~numInstruments)) {
        ~defaultParams.noteArrays[tubaIndex] = Array.fill(5, note);
        ("Set note for tuba " ++ tubaIndex ++ " to: " ++ note).postln;
    };
};

// Set note for all tubas
~setAllNotes = { |note|
    ~numInstruments.do { |i|
        ~defaultParams.noteArrays[i] = Array.fill(5, note);
    };
    ("Set all tubas to note: " ++ note).postln;
};

// Create a chord with given notes (provides notes for as many tubas as available)
~setChord = { |noteArray|
    var len = min(noteArray.size, ~numInstruments);
    len.do { |i|
        ~defaultParams.noteArrays[i] = Array.fill(5, noteArray[i]);
    };
    ("Set chord with notes: " ++ noteArray).postln;
};

// Update grain duration evolution
~setGrainDurationRange = { |initialDur, finalDur|
    ~defaultParams.initialGrainDuration = initialDur;
    ~defaultParams.finalGrainDuration = finalDur;
    ("Grain duration will evolve from " ++ initialDur ++ " to " ++ finalDur ++ " seconds").postln;
};

// Set the overall duration for the process
~setDuration = { |seconds|
    ~defaultParams.globalDuration = seconds;
    ("Set global duration to " ++ seconds ++ " seconds").postln;
};

// Set the envelope shape for timing evolution
~setRippleEnvelopeShape = { |riseTimePortion=0.4, fallTimePortion=0.4|
    ~defaultParams.riseTime = riseTimePortion.clip(0.0, 1.0);
    ~defaultParams.fallTime = fallTimePortion.clip(0.0, (1.0 - ~defaultParams.riseTime));
    ("Ripple envelope shape set to rise: " ++ ~defaultParams.riseTime ++
     ", fall: " ++ ~defaultParams.fallTime).postln;
};

"Ripple Granular System initialized with " ++ ~numInstruments ++ " tubas.".postln;
"Available commands:".postln;
"  ~startRippleProcess.value - Start the ripple granular process".postln;
"  ~stopRippleProcess.value - Stop the ripple granular process".postln;
"  ~setRippleTiming.(initialDelay, peakDelay, finalDelay, initialCycleDelay, peakCycleDelay, finalCycleDelay) - Set timing parameters".postln;
"  ~setDuration.(seconds) - Set the total duration".postln;
"  ~setRippleEnvelopeShape.(riseTime, fallTime) - Set the envelope shape for timing evolution".postln;
"  ~setNotes.(tubaIndex, note) - Set note for a tuba".postln;
"  ~setAllNotes.(note) - Set the same note for all tubas".postln;
"  ~setChord.([noteArray]) - Set different notes to create a chord".postln;
"  ~setGrainDurationRange.(initialDur, finalDur) - Set range for grain duration evolution".postln;
"  ~testEnvelopeOutput.value - Test envelope output".postln;
"  ~rebuildRippleMaster.value - Rebuild the ripple master".postln;
)
// Examples of usage (uncomment to use):

// Example 1: Start with default settings
~startRippleProcess.value;

// Example 2: Set chord and start
/*
~setChord.([92, 86, 83, 89, 95, 77]);  // Six different notes
~startRippleProcess.value;
*/

// Example 3: Set timing for more extreme ripple effect
/*
~setRippleTiming.(0.0, 1.0, 0.0, 0.2, 4.0, 0.2); // More extreme timing changes
~startRippleProcess.value;
*/

// Example 4: Set envelope shape to have a quick rise and long fall
/*
~setRippleEnvelopeShape.(0.2, 0.6);  // Quick rise, long fall
~startRippleProcess.value;
*/

// Example 5: Shorter grains with longer duration
/*
~setGrainDurationRange.(0.2, 1.0);  // Shorter grains
~setDuration.(30.0);                // Longer overall duration
~startRippleProcess.value;
*/
