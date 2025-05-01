// =====================================================
// Simple ProcMod Sequence Example
// =====================================================
// This file demonstrates how to create two ProcMods and
// sequence them using ProcEvents

// =====================================================
// 1. INITIAL CONFIGURATION - Set up parameters for components
// =====================================================

// Configure chord bend parameters to ensure proper operation in the sequence
~configureChordBendParams = {
    // Only update if the updateParams function exists (in case chord-bend isn't loaded yet)
    if(~updateParams.notNil) {
        // Store original params for debugging/comparison
        var originalDuration = if(~params.notNil) { ~params.duration } { "unknown" };
        
        ~updateParams.value((
            // Set appropriate duration for the sequence context
            duration: 8.0,              // 8 seconds total duration 
            bendTime: 3.5,              // Time to reach peak bend
            returnTime: 3.0,            // Time to return from peak
            
            // Set chord notes appropriate for the sequence
            chord: [60, 55, 50],        // Use a chord that complements the melody
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

// Call initialization right away to ensure parameters are set
// before ProcMods are created
~configureChordBendParams.value;

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
        "Starting surfacing melody...".postln;

        // Return a Task that plays one melody from surfacing-procmod
        Task({
            // Simply call the existing function directly
            ~playMelody.value(\set1);

            // Wait for it to complete (approximate time)
            5.wait;

            "Surfacing melody complete".postln;
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

// Create a wrapper ProcMod for the chord bend
~chordBendMod = ProcMod.new(
    // Simple envelope with release node
    Env([0, 1, 0], [1, 1], \sin, 1),
    // Amplitude
    0.7,
    // ID
    \chordBend,
    // Group, etc.
    nil, 0, 1,

    // Main function - call the existing chord bend functionality
    { |group, envbus, server|
        "Starting chord bend...".postln;

        // Log the current parameter settings to verify
        ["Using chord bend with duration:", ~params.duration].postln;

        // Return a Task that plays the chord bend
        Task({
            // Simply call the existing function directly
            ~playChord.value;

            // Wait for the full duration plus a safety margin
            // This ensures ProcMod doesn't complete before the chord is fully released
            (~params.duration + 0.5).wait;

            "Chord bend complete".postln;
        });
    },

    // Release function - executed after ProcMod is fully released
    { |group, envbus|
        "Released chord bend".postln;
    },

    // onRelease function - executed when release is initiated
    { |group, envbus|
        "Releasing chord bend...".postln;
        // Use the existing release function which handles note/synth cleanup
        ~releaseChord.value;
    }
);

// Add debug controller
~chordBendController = ~debugProcModState.(~chordBendMod, "CHORD_BEND");

// =====================================================
// 4. CREATE PROCEVENTS - Sequence the two ProcMods
// =====================================================

// ProcEvents takes an array of events to play and release
// Format: [ProcMod to play, ProcMod to release]
~procSequence = ProcEvents.new([
    // Start with surfacing melody
    [~surfacingMod, nil],

    // Then transition to chord bend, releasing surfacing
    [~chordBendMod, ~surfacingMod],

    // Finally release chord bend
    [nil, ~chordBendMod]
],
// Default amplitude for all events
1.0,

// Init module (optional) - runs before the first event
nil,

// Kill module (optional) - runs when ProcEvents is killed
{ 
    "Sequence completed".postln; 
    // Ensure all chord notes are cleaned up when the sequence is killed
    ~cleanupAllChordNotes.value;
},

// ID for this ProcEvents instance
\melodyChordSequence,

// Server to use (defaults to Server.default if nil)
s
);

// Add a SimpleController to track ProcEvents state
~procEventsController = SimpleController(~procSequence);
~procEventsController.put(\indexPlaying, { |theChanger, what, values|
    "[SEQUENCE] Current event index: %".format(values).postln;
});

// =====================================================
// 5. EXECUTION CONTROLS - Functions to play/control sequence
// =====================================================

// Function to play the entire sequence
~playFullSequence = {
    "Starting full sequence...".postln;

    // Verify chord bend parameters before starting
    if(~params.notNil) {
        ["Verified chord bend parameters - Duration:", ~params.duration, 
         "Chord:", ~params.chord, "Bend times:", ~params.bendTime, ~params.returnTime].postln;
    };

    // Start the first event
    ~procSequence.play(0);

    // Schedule advancement through the sequence
    // Allow more time for the surfacing melody to play
    SystemClock.sched(8, {  // Time for melody to play
    var chordBendTime;
        "Advancing to chord bend...".postln;
        ~procSequence.next;

        // Get the current duration setting for the chord bend
         chordBendTime = ~params.duration + 1.0; // Add extra safety margin

        ["Scheduling final cleanup after", chordBendTime, "seconds"].postln;

        // Schedule the final advancement based on chord bend duration
        SystemClock.sched(chordBendTime, {
            "Advancing to final event (cleanup)...".postln;
            ~procSequence.next;
            
            // Add a final safety check to ensure all notes are released
            SystemClock.sched(2.0, {
                "Performing final note cleanup check...".postln;
                ~cleanupAllChordNotes.value;
                nil; // Don't reschedule
            });
            
            nil; // Don't reschedule
        });

        nil; // Don't reschedule
    });
};

// Function to manually step through the sequence
~stepSequence = {
    "Stepping to next event...".postln;
    ~procSequence.next;
};

// Function to reset the sequence
~resetSequence = {
    "Resetting sequence...".postln;
    ~procSequence.reset;

    // Also stop any playing melodies and chords
    ~stopAllMelodies.value;
    ~releaseChord.value;
    ~cleanupAllChordNotes.value; // Ensure all chord notes are cleaned up
};

// Function to clean up everything
~cleanup = {
    "Cleaning up all objects...".postln;
    ~surfacingController.remove;
    ~chordBendController.remove;
    ~procEventsController.remove;
    ~procSequence.killAll;
    ~stopAllMelodies.value;
    ~releaseChord.value;
    ~cleanupAllChordNotes.value; // Ensure all chord notes are cleaned up
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
    } {
        "Warning: Could not update chord bend parameters.".postln;
    };
};

// =====================================================
// 6. INSTRUCTIONS
// =====================================================

"=================================================".postln;
"MELODY + CHORD BEND SEQUENCE EXAMPLE READY".postln;
"=================================================".postln;
"Run these commands to test the sequence:".postln;
"  ~playFullSequence.value; // Play the full automated sequence".postln;
"  ~stepSequence.value;     // Manually advance to next step".postln;
"  ~resetSequence.value;    // Reset the sequence".postln;
"  ~cleanup.value;          // Clean up all objects".postln;
"  ~updateChordBendForSequence.(duration, bendTime, returnTime); // Modify chord bend timing".postln;
"=================================================".postln; 