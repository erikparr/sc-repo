// =====================================================
// Simple ProcMod Sequence Example
// =====================================================
// This file demonstrates how to create two ProcMods and
// sequence them using ProcEvents

// =====================================================
// 1. INITIAL CONFIGURATION - Set up parameters for components
// =====================================================

// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "simple-chord-bend.scd").load;
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "surfacing-procmod.scd").load;

// Configure chord bend parameters to ensure proper operation in the sequence
~configureChordBendParams = {
    // Only update if the updateParams function exists (in case chord-bend isn't loaded yet)
    if(~updateParams.notNil) {
        // Store original params for debugging/comparison
        var originalDuration = if(~params.notNil) { ~params.duration } { "unknown" };

        ~updateParams.value((
            // Set appropriate duration for the sequence context
            duration: 4,              // 8 seconds total duration
            bendTime: 3.5,              // Time to reach peak bend
            returnTime: 3.0,            // Time to return from peak

            // Set chord notes appropriate for the sequence
            chord: [92, 92, 92],        // Use a chord that complements the melody
            bendPercents: [15, 12, 10], // Moderate bend percentages

            // Set appropriate expression levels
            ccLevels: [90, 100, 110],   // Graduated expression levels

            // Use sine curve for smooth movement
            curveShape: \sin
        ));

        "Chord bend parameters configured for sequence:".postln;
        ["  Original duration:", originalDuration].postln;
        ["  New duration:", ~params.duration].postln;
        ["  Notes:", ~params.chord].postln;
    } {
        "Warning: Chord bend parameter update function not available.".postln;
        "Make sure simple-chord-bend.scd is loaded before this file.".postln;
    };
};

// Configure essential surfacing melody parameters
~configureSurfacingMelodyParams = { |noteDur=0.2, noteRst=0.2, fermata=false, melodyRest=false|
    // Only update if core variables exist
    if(~noteDuration.notNil && ~noteRest.notNil) {
        // Store original values for logging
        var origDuration = ~noteDuration;
        var origRest = ~noteRest;

        // Update the core timing parameters
        ~noteDuration = noteDur;
        ~noteRest = noteRst;

        // Update mode flags if they exist
        if(~modes.notNil) {
            if(~modes.includesKey(\fermata)) { ~modes[\fermata] = fermata };
            if(~modes.includesKey(\melodyRest)) { ~modes[\melodyRest] = melodyRest };
        };

        "Surfacing melody parameters configured:".postln;
        ["  Note duration:", ~noteDuration, "(was", origDuration, ")"].postln;
        ["  Note rest:", ~noteRest, "(was", origRest, ")"].postln;
        if(~modes.notNil) {
            ["  Fermata mode:", ~modes[\fermata]].postln;
            ["  Melody rest mode:", ~modes[\melodyRest]].postln;
        };
    } {
        "Warning: Surfacing melody parameters not available.".postln;
    };
};

// Call initialization right away to ensure parameters are set
// before ProcMods are created
~configureChordBendParams.value;
~configureSurfacingMelodyParams.value;

// =====================================================
// 1.5 SEQUENCE TIMING CONFIGURATION - Add timing parameters
// =====================================================

// Create a dictionary to store sequence timing parameters
~sequenceParams = (
    // Transition timing parameters (as proportion of gesture duration)
    melodyToChordOverlap: 0.2,  // Overlap between melody and chord (0.2 = start chord when melody is 80% complete)

    // Minimum durations (to ensure gestures have enough time to develop)
    minMelodyDuration: 0.0,     // Minimum duration for melody gesture (seconds)
    minChordDuration: 6.0,      // Minimum duration for chord gesture (seconds)

    // Safety margins (added to calculated durations)
    transitionSafetyMargin: 0.5, // Extra time for transitions (seconds)
    cleanupSafetyMargin: 2.0,    // Extra time for final cleanup (seconds),

    // Cache for calculated durations (will be populated at runtime)
    calculatedMelodyDuration: nil,
    calculatedChordDuration: nil,
    calculatedTransitionTime: nil,
    calculatedReleaseTime: nil
);

// Function to calculate and configure sequence timing based on current state
~configureSequenceTiming = {
    var melodyDuration, chordDuration, transitionTime, releaseTime;

    // Get the melody duration using the existing calculation function
    // from surfacing-procmod.scd if available
    if(~calcEnvelopeDuration.notNil) {
        melodyDuration = ~calcEnvelopeDuration.value;
        ["Got melody duration from surfacing:", melodyDuration, "seconds"].postln;
    } {
        // Use default if function not available
        melodyDuration = ~sequenceParams.minMelodyDuration;
        ["Using default melody duration:", melodyDuration, "seconds"].postln;
    };

    // NOTE: Removed the minimum duration enforcement to let melody complete naturally
    // Add a small buffer to ensure smooth transition
    melodyDuration = melodyDuration + 0.5;

    // Get chord duration from the chord bend parameters
    if(~params.notNil && ~params.duration.notNil) {
        chordDuration = ~params.duration;
        ["Got chord duration from bend params:", chordDuration, "seconds"].postln;
    } {
        // Use default if not available
        chordDuration = ~sequenceParams.minChordDuration;
        ["Using default chord duration:", chordDuration, "seconds"].postln;
    };

    // Ensure minimum duration for the chord (this one we'll keep)
    chordDuration = max(chordDuration, ~sequenceParams.minChordDuration);

    // Calculate when to transition from melody to chord
    // This is based on the melody duration and overlap factor
    transitionTime = melodyDuration * (1 - ~sequenceParams.melodyToChordOverlap);

    // Add safety margin
    transitionTime = transitionTime + ~sequenceParams.transitionSafetyMargin;

    // Calculate when to release the chord (based on chord duration from transition)
    releaseTime = chordDuration + ~sequenceParams.transitionSafetyMargin;

    // Store calculated values
    ~sequenceParams.calculatedMelodyDuration = melodyDuration;
    ~sequenceParams.calculatedChordDuration = chordDuration;
    ~sequenceParams.calculatedTransitionTime = transitionTime;
    ~sequenceParams.calculatedReleaseTime = releaseTime;

    // Log the calculated timing values
    ["Sequence timing configured:",
     "Melody duration:", melodyDuration,
     "Chord duration:", chordDuration,
     "Transition at:", transitionTime,
     "Release chord at:", releaseTime
    ].postln;

    // Return the timing parameters (for chaining)
    ~sequenceParams;
};

// Function to adjust the sequence timing parameters
~setSequenceTiming = { |paramName, value|
    if(~sequenceParams[paramName].notNil) {
        ~sequenceParams[paramName] = value;
        ["Set sequence timing parameter", paramName, "to", value].postln;

        // Reconfigure timing with new parameters
        ~configureSequenceTiming.value;
    } {
        ["Invalid sequence timing parameter:", paramName].postln;
    };
};

// Function to visualize the sequence timing (for debugging)
~visualizeSequenceTiming = {
    var str = "";
    var melodyStart = 0;
    var chordStart = ~sequenceParams.calculatedTransitionTime;
    var chordEnd = chordStart + ~sequenceParams.calculatedReleaseTime;
    var totalTime = chordEnd + ~sequenceParams.cleanupSafetyMargin;
    var scale = 50 / totalTime; // Scale to fit in 50 characters
    var melodyChars = (chordStart * scale).asInteger;
    var chordChars = ((chordEnd - chordStart) * scale).asInteger;
    var cleanupChars = (totalTime * scale).asInteger - melodyChars - chordChars;

    "Sequence Timeline:".postln;
    ("|" ++ (("-" ! melodyChars).join("")) ++ "|").postln;
    ("0" ++ (" " ! (melodyChars-1)).join("") ++ chordStart.round(0.1) ++
     (" " ! (chordChars-chordStart.round(0.1).asString.size)).join("") ++
     chordEnd.round(0.1) ++
     (" " ! (cleanupChars-chordEnd.round(0.1).asString.size)).join("") ++
     totalTime.round(0.1)).postln;
    ("Melody" ++ (" " ! (melodyChars-6)).join("") ++ "Chord" ++
     (" " ! (chordChars-5)).join("") ++ "Cleanup").postln;

    // Also print actual values
    ["Melody plays from", 0, "to", chordStart, "(", chordStart, "seconds)"].postln;
    ["Chord plays from", chordStart, "to", chordEnd, "(", (chordEnd - chordStart), "seconds)"].postln;
    ["Cleanup from", chordEnd, "to", totalTime, "(", (totalTime - chordEnd), "seconds)"].postln;
    ["Total sequence duration:", totalTime, "seconds"].postln;
};

// =====================================================
// 2. CREATE FIRST PROCMOD - Surfacing Melody
// =====================================================

// Debug function to track ProcMod state changes
~debugProcModState = { |procMod, label|
    var controller = SimpleController(procMod);
    controller.put(\isRunning, { |theChanger, what, values|
        "[%] % - isRunning: %".format(label, procMod.id, values).postln;
    });
    controller.put(\amp, { |theChanger, what, values|
        "[%] % - amp: % dB".format(label, procMod.id, values.ampdb.round(0.1)).postln;
    });
    controller
};

// Create a ProcMod that uses the surfacing functionality
~surfacingMod = ProcMod.new(
    // Simple envelope with release node
    Env([0, 1, 0], [1, 1], \sin, 1),
    // Amplitude
    0.7,
    // ID
    \surfacingMelody,
    // Group, etc.
    nil, 0, 1,

    // Main function - call the existing surfacing functionality
    { |group, envbus, server|
        var melodyDone = Condition(false);

        "Starting surfacing melody...".postln;

        // Create a melody completion callback
        ~onMelodyComplete = {
            "Melody complete callback triggered".postln;
            melodyDone.test = true;
            melodyDone.signal;
        };

        // Return a Task that plays one melody from surfacing-procmod
        Task({
            // Play melody with callback
            ~playMelody.value(\set1);

            // Wait for the melody to actually complete via condition
            melodyDone.wait;

            "Surfacing melody task completed after melody finished".postln;
        });
    },

    // Release function - executed after ProcMod is fully released
    { |group, envbus|
        "Released surfacing melody".postln;
    },

    // onRelease function - executed when release is initiated
    { |group, envbus|
        "Releasing surfacing melody...".postln;
        // Use the existing stop function
        ~stopAllMelodies.value;
    }
);

// Add debug controller
~surfacingController = ~debugProcModState.(~surfacingMod, "SURFACING");

// =====================================================
// 3. CREATE SECOND PROCMOD - Chord Bend
// =====================================================

// =====================================================
// 3. DIRECT ACCESS FUNCTIONS - Access melody and chord ProcMods directly
// =====================================================

// =====================================================
// Function to get melody ProcMod for direct use in the sequence
// =====================================================

// This function gets or creates a melody ProcMod for direct use in the sequence
~getMelodyProcMod = { |melodyKey=\set1|
    var melodyProc;
    
    // Ensure we have access to the melody functions
    if(~melodyProcs.isNil || ~createMelodyProc.isNil) {
        "ERROR: Missing required melody functions from surfacing-procmod.scd".postln;
        nil;
    } {
        // Check if this melody already exists
        melodyProc = ~melodyProcs[melodyKey];
        
        // If not, or if it's currently running, create a new instance
        if(melodyProc.isNil || melodyProc.isRunning) {
            ["Creating new melody ProcMod for", melodyKey].postln;
            melodyProc = ~createMelodyProc.(melodyKey);
            ~melodyProcs[melodyKey] = melodyProc;
        } {
            ["Using existing melody ProcMod for", melodyKey].postln;
        };
        
        melodyProc;
    };
};

// =====================================================
// 4. DIRECT CONTROL FUNCTIONS - Methods for playing melody and chord
// =====================================================

// Function to play the chord bend directly without wrapper ProcMod
~playDirectChordBend = { |chordNotes, duration=4, bendPercents|
    // Set default values inside the function
    chordNotes = chordNotes ?? [92, 92, 92];
    bendPercents = bendPercents ?? [15, 12, 10];
    
    // Configure parameters
    ~updateParams.value((
        chord: chordNotes,
        duration: duration,
        bendPercents: bendPercents,
        bendTime: duration * 0.7,
        returnTime: duration * 0.6
    ));
    
    // Clean up any existing notes
    ~cleanupAllChordNotes.value;
    
    // Play the chord directly
    ~playChord.value;
    
    // Return a message confirming playback
    "Playing direct chord bend with % notes, duration: %".format(
        chordNotes.size, duration
    ).postln;
};

// Function to play melody with chord bend in synchronized manner
~playMelodyWithChord = { |melodyKey=\set1, chordNotes|
    var melodyProc;

    // Set default values inside the function
    chordNotes = chordNotes ?? [92, 92, 92];

    "Starting synchronized melody and chord sequence...".postln;

    // Configure chord bend parameters
    ~updateParams.value((
        chord: chordNotes,
        duration: 4,
        bendTime: 3.5,
        returnTime: 3.0,
        bendPercents: [15, 12, 10]
    ));

    // Get the melody proc
    melodyProc = ~getMelodyProcMod.(melodyKey);

    if(melodyProc.isNil) {
        "Failed to get melody ProcMod - cannot play".postln;
        ^nil;
    };

    // Clean up existing tasks and notes
    ~scheduledTasks.do { |task| task.cancel };
    ~scheduledTasks.clear;
    ~cleanupAllChordNotes.value;

    // Release any currently running instances
    if(melodyProc.isRunning) {
        "Releasing running melody...".postln;
        melodyProc.release(0.1);
    };

    // Configure timing for sequence
    ~configureSequenceTiming.value;

    // Wait a moment to ensure clean state
    SystemClock.sched(0.2, {
        // Play just the melody directly
        "Starting melody: %".format(melodyKey).postln;
        melodyProc.play;

        // Schedule the chord bend to start at transition time
        ~scheduledTasks[\startChord] = SystemClock.sched(~sequenceParams.calculatedTransitionTime, {
            "Starting chord bend while melody plays...".postln;
            ~playChord.value;

            // Schedule melody release
            ~scheduledTasks[\releaseMelody] = SystemClock.sched(~sequenceParams.calculatedMelodyDuration * 0.2, {
                "Releasing melody, keeping chord bend...".postln;
                melodyProc.release;

                // Schedule chord release
                ~scheduledTasks[\releaseChord] = SystemClock.sched(~sequenceParams.calculatedChordDuration, {
                    "Releasing chord bend...".postln;
                    ~releaseChord.value;

                    // Final cleanup
                    ~scheduledTasks[\cleanup] = SystemClock.sched(~sequenceParams.cleanupSafetyMargin, {
                        "Performing final cleanup...".postln;
                        ~cleanupAllChordNotes.value;
                        nil;
                    });

                    nil;
                });

                nil;
            });

            nil;
        });

        nil;
    });

    "Sequence scheduled. Melody will play now, chord bend will join in % seconds.".format(
        ~sequenceParams.calculatedTransitionTime.round(0.1)
    ).postln;
};

// =====================================================
// 5. EXECUTION CONTROLS - Functions to play/control sequence
// =====================================================

// Store references to scheduled tasks for clean cancellation
~scheduledTasks = Dictionary.new;

// Function to play the direct sequence without the wrapper ProcMod
~playDirectSequence = { |melodyKey=\set1|
    var directSequence, melodyProc;
    
    "Starting direct sequence with melody %...".format(melodyKey).postln;
    
    // Get the melody proc
    melodyProc = ~getMelodyProcMod.(melodyKey);
    
    if(melodyProc.isNil) {
        "Failed to get melody ProcMod - cannot play".postln;
        ^nil;
    };
    
    // Configure sequence timing based on current state
    ~configureSequenceTiming.value;
    
    // Visualize the timing (for debugging)
    ~visualizeSequenceTiming.value;
    
    // Cancel any previously scheduled tasks
    ~scheduledTasks.do { |task| task.cancel };
    ~scheduledTasks.clear;
    
    // Clean up any chord notes to avoid hanging notes
    ~cleanupAllChordNotes.value;
    
    // Release any currently running instances
    if(melodyProc.isRunning) {
        "Releasing running melody...".postln;
        melodyProc.release(0.1);
    };
    
    // Wait a moment for releases to complete
    SystemClock.sched(0.2, {
        // Play just the melody directly
        "Starting melody: %".format(melodyKey).postln;
        melodyProc.play;
        
        // Schedule the chord bend to start at transition time
        ~scheduledTasks[\startChord] = SystemClock.sched(~sequenceParams.calculatedTransitionTime, {
            "Starting chord bend...".postln;
            ~playChord.value;
            
            // Schedule melody release
            ~scheduledTasks[\releaseMelody] = SystemClock.sched(~sequenceParams.calculatedMelodyDuration * 0.2, {
                "Releasing melody, keeping chord bend...".postln;
                melodyProc.release;
                
                // Schedule chord release
                ~scheduledTasks[\releaseChord] = SystemClock.sched(~sequenceParams.calculatedChordDuration, {
                    "Releasing chord bend...".postln;
                    ~releaseChord.value;
                    
                    // Final cleanup
                    ~scheduledTasks[\cleanup] = SystemClock.sched(~sequenceParams.cleanupSafetyMargin, {
                        "Performing final cleanup...".postln;
                        ~cleanupAllChordNotes.value;
                        nil;
                    });
                    
                    nil;
                });
                
                nil;
            });
            
            nil;
        });
        
        nil;
    });
    
    "Sequence scheduled. Melody will play now, chord bend will join in % seconds.".format(
        ~sequenceParams.calculatedTransitionTime.round(0.1)
    ).postln;
};

// Function to clean up everything
~cleanup = {
    "Cleaning up all objects...".postln;

    // Cancel any scheduled tasks
    ~scheduledTasks.do { |task| task.cancel };
    ~scheduledTasks.clear;

    // Remove controllers
    ~surfacingController.remove;
    if(~melodyChordController.notNil) {
        ~melodyChordController.remove;
    };

    // Clean up all melodies and chord notes
    ~stopAllMelodies.value;
    ~releaseChord.value;
    ~cleanupAllChordNotes.value;

    // Release surfacing ProcMod directly if running
    if(~surfacingMod.isRunning) {
        "Releasing running surfacing melody...".postln;
        ~surfacingMod.release(0.1);
    };

    "Cleanup complete.".postln;
};

// Function to reconfigure chord bend parameters (can be called at any time)
~updateChordBendForSequence = { |duration=8.0, bendTime=3.5, returnTime=3.0|
    if(~updateParams.notNil) {
        ~updateParams.value((
            duration: duration,
            bendTime: bendTime,
            returnTime: returnTime
        ));
        ["Updated chord bend parameters:", "Duration:", duration,
         "Bend time:", bendTime, "Return time:", returnTime].postln;

        // Reconfigure sequence timing after parameter change
        ~configureSequenceTiming.value;
    } {
        "Warning: Could not update chord bend parameters.".postln;
    };
};

// =====================================================
// 6. INSTRUCTIONS
// =====================================================
// ~playMelodyWithChord.(\set1, [92, 92, 92]);
"=================================================".postln;
"MELODY + CHORD BEND SEQUENCE EXAMPLE READY".postln;
"=================================================".postln;
"Run these commands to test the sequence:".postln;
"  ~playDirectSequence.value;   // Play melody followed by chord bend".postln;
"  ~playDirectSequence.(\set2); // Play with a different melody".postln;
"  ~playDirectChordBend.value;  // Play just the chord bend directly".postln;
"  ~playDirectChordBend.([60, 64, 67], 6); // Play chord bend with custom notes and duration".postln;
"  ~playMelodyWithChord.value;  // Play melody and chord bend with synchronized timing".postln;
"  ~playMelodyWithChord.(\\set2, [60, 64, 67]); // Play with custom melody and chord".postln;
"  ~cleanup.value;              // Clean up all objects".postln;
"  ~updateChordBendForSequence.(duration, bendTime, returnTime); // Modify chord bend timing".postln;
"  ~setSequenceTiming.(\melodyToChordOverlap, 0.3); // Adjust overlap between gestures".postln;
"  ~visualizeSequenceTiming.value; // See the timing of sequence components".postln;
"=================================================".postln;
"DIRECT CONTROL APPROACH:".postln;
"  This implementation accesses ProcMods directly".postln;
"  It provides more accurate timing and eliminates unnecessary code layers".postln;
"=================================================".postln;
"AVAILABLE FUNCTIONS:".postln;
"  ~playDirectSequence - Play melody followed by chord bend".postln;
"  ~playDirectChordBend - Play just the chord bend directly".postln;
"  ~playMelodyWithChord - Synchronize melody and chord with precise timing".postln;
"  ~cleanup - Clean up all resources".postln;
"=================================================".postln;
