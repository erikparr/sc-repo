// looping-sequence.scd
// A looping implementation to sequence melodies and chord bends

// Load required files if not already loaded
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "simple-chord-bend.scd").load;
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "surfacing-procmod.scd").load;

// Looping sequence configuration
~loopConfig = (
    // Basic timing parameters
    melodyToChordDelay: 1.0,    // How long after melody to start chord (seconds)
    chordDuration: 4.0,         // How long to sustain the chord (seconds)
    cleanupDelay: 0.5,          // Wait time after chord before cleanup
    loopDelay: 2.0,             // Delay between loops (seconds)

    // Loop control
    iterations: inf,            // Number of iterations (inf for unlimited)
    currentIteration: 0,        // Current iteration counter

    // Sequence configuration
    melodies: [\set1, \set2],   // Array of melodies to play in sequence
    currentMelodyIndex: 0,      // Current index in the melody sequence

    // Default musical parameters
    defaultChord: [92, 92, 92], // Default chord notes
    defaultBendPercents: [15, 12, 10], // Default bend percentages

    // State
    isLooping: false            // Whether the loop is currently running
);

// Dictionary to track scheduled events
~loopEvents = Dictionary.new;

// The main loop task
~loopTask = nil;

// Start the looping sequence
~startLoopingSequence = { |iterations, melodies, chordNotes, bendPercents|
    // Allow overriding parameters
    iterations = iterations ?? ~loopConfig.iterations;
    melodies = melodies ?? ~loopConfig.melodies;
    chordNotes = chordNotes ?? ~loopConfig.defaultChord;
    bendPercents = bendPercents ?? ~loopConfig.defaultBendPercents;

    // Stop any existing loop
    ~stopLoopingSequence.value(false);

    // Reset loop state
    ~loopConfig.currentIteration = 0;
    ~loopConfig.currentMelodyIndex = 0;
    ~loopConfig.isLooping = true;
    ~loopConfig.iterations = iterations;
    ~loopConfig.melodies = melodies;

    // Create the main loop task
    ~loopTask = Task({
        var keepLooping = true;

        "Starting looping sequence with % melodies, % iterations".format(
            melodies.size,
            if(iterations == inf, "infinite", iterations)
        ).postln;

        // Main loop - continues until iterations complete or manually stopped
        while {
            keepLooping and: {
                ~loopConfig.currentIteration < ~loopConfig.iterations
            } and: {
                ~loopConfig.isLooping
            }
        } {
            var currentMelody = ~loopConfig.melodies[~loopConfig.currentMelodyIndex];
            var totalCycleTime;

            // Log the current iteration
            "Loop iteration: %, melody: %".format(
                ~loopConfig.currentIteration + 1,
                currentMelody
            ).postln;

            // Clean up any existing sounds
            ~stopAllMelodies.value;
            if(~cleanupAllChordNotes.notNil) { ~cleanupAllChordNotes.value };

            // Check if melody exists before playing
            if(~melodyDict.notNil && ~melodyDict[currentMelody].notNil) {
                "Playing melody: %".format(currentMelody).postln;
                ~playMelody.value(currentMelody);
            } {
                "Skipping unknown melody: %".format(currentMelody).postln;
            };

            // Wait, then play the chord
            ~loopConfig.melodyToChordDelay.wait;

            // Update parameters and play chord
            if(~updateParams.notNil) {
                ~updateParams.value((
                    chord: chordNotes,
                    bendPercents: bendPercents,
                    duration: ~loopConfig.chordDuration
                ));
            };

            if(~playChord.notNil) { ~playChord.value };

            // Wait for chord to complete
            ~loopConfig.chordDuration.wait;

            // Release chord
            if(~releaseChord.notNil) { ~releaseChord.value };

            // Wait for cleanup
            ~loopConfig.cleanupDelay.wait;

            // Perform cleanup
            if(~cleanupAllChordNotes.notNil) { ~cleanupAllChordNotes.value };

            // Advance to next melody in sequence
            ~loopConfig.currentMelodyIndex = (~loopConfig.currentMelodyIndex + 1) % ~loopConfig.melodies.size;

            // If we've gone through all melodies, count as a complete iteration
            if(~loopConfig.currentMelodyIndex == 0) {
                ~loopConfig.currentIteration = ~loopConfig.currentIteration + 1;

                // Add delay between complete iterations
                if(~loopConfig.currentIteration < ~loopConfig.iterations) {
                    "Completed iteration %, waiting % seconds before next".format(
                        ~loopConfig.currentIteration, ~loopConfig.loopDelay
                    ).postln;

                    ~loopConfig.loopDelay.wait;
                }
            }
        };

        // Clean up when loop finishes
        ~loopConfig.isLooping = false;
        "Looping sequence complete after % iterations".format(~loopConfig.currentIteration).postln;
    });

    // Start the loop task
    ~loopTask.play;

    // Return confirmation message
    "Looping sequence started with % melodies, % iterations".format(
        melodies.size,
        if(iterations == inf, "infinite", iterations)
    );
};

// Stop the looping sequence
~stopLoopingSequence = { |fadeOut=true|
    if(~loopTask.notNil and: { ~loopTask.isPlaying }) {
        "Stopping looping sequence".postln;

        // Stop the loop task
        ~loopTask.stop;
        ~loopTask = nil;

        // Update state
        ~loopConfig.isLooping = false;

        // Clean up sounds
        ~stopAllMelodies.value;
        
        // Handle chord release and cleanup
        if(~releaseChord.notNil and: fadeOut) {
            ~releaseChord.value;
        };
        
        // Always try to cleanup chord notes
        if(~cleanupAllChordNotes.notNil) {
            ~cleanupAllChordNotes.value;
        };
    } {
        "No looping sequence is currently running".postln;
    };

    // Return confirmation
    "Looping sequence stopped";
};

// Set loop configuration parameters
~setLoopParameter = { |paramName, value|
    if(~loopConfig.includesKey(paramName)) {
        ~loopConfig[paramName] = value;
        "Updated loop parameter % to %".format(paramName, value);
    } {
        "Unknown loop parameter: %".format(paramName);
    };
};

// Print usage instructions
"LOOPING SEQUENCE READY:".postln;
"  ~startLoopingSequence.value;  // Start with default settings".postln;
"  ~startLoopingSequence.(3);    // Loop 3 times with default melodies".postln;
"  ~startLoopingSequence.(inf, [\\set1, \\set3, \\set5]);  // Infinite loop with custom melody sequence".postln;
"  ~stopLoopingSequence.value;   // Stop the loop".postln;
"  ~setLoopParameter.(\\loopDelay, 4.0);  // Set delay between iterations".postln; 