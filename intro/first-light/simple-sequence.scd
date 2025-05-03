// simple-sequence.scd
// A simplified implementation to sequence melodies and chord bends

// Load required files if not already loaded
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "simple-chord-bend.scd").load;
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "surfacing-procmod.scd").load;

// Simple sequence parameters
~sequenceConfig = (
    // Timing parameters
    melodyToChordDelay: 1.0,   // How long to wait after starting melody before chord (seconds)
    chordDuration: 4.0,        // How long to sustain the chord (seconds)
    cleanupDelay: 0.5,         // How long to wait after chord release before final cleanup
    
    // Default musical parameters
    defaultMelody: \set1,      // Which melody to play from melodyDict
    defaultChord: [92, 92, 92], // Default chord notes
    defaultBendPercents: [15, 12, 10] // Default bend percentages
);

// Dictionary to track scheduled events (for cancellation)
~scheduledEvents = Dictionary.new;

// Main function to play a melody followed by a chord bend
~playSequence = { |melodyKey, chordNotes, bendPercents, startDelay=0.2|
    // Use default values if parameters not provided
    melodyKey = melodyKey ?? ~sequenceConfig.defaultMelody;
    chordNotes = chordNotes ?? ~sequenceConfig.defaultChord;
    bendPercents = bendPercents ?? ~sequenceConfig.defaultBendPercents;
    
    // Cancel any previously scheduled events
    ~scheduledEvents.do { |task| task.stop };
    ~scheduledEvents.clear;
    
    // Clean up any existing sounds
    ~stopAllMelodies.value;
    if(~cleanupAllChordNotes.notNil) { ~cleanupAllChordNotes.value };
    
    // Start the sequence after a brief delay
    SystemClock.sched(startDelay, {
        // Play the melody using existing function from surfacing-procmod.scd
        "Playing melody: %".format(melodyKey).postln;
        ~playMelody.value(melodyKey);
        
        // Schedule the chord bend to start after the specified delay
        ~scheduledEvents[\chord] = SystemClock.sched(~sequenceConfig.melodyToChordDelay, {
            // Play the chord using existing function from simple-chord-bend.scd
            "Playing chord bend with notes: %".format(chordNotes).postln;
            
            // Set chord parameters if the function exists
            if(~updateParams.notNil) {
                ~updateParams.value((
                    chord: chordNotes,
                    bendPercents: bendPercents,
                    duration: ~sequenceConfig.chordDuration
                ));
            };
            
            // Play the chord
            if(~playChord.notNil) { ~playChord.value };
            
            // Schedule chord release
            ~scheduledEvents[\releaseChord] = SystemClock.sched(~sequenceConfig.chordDuration, {
                "Releasing chord".postln;
                if(~releaseChord.notNil) { ~releaseChord.value };
                
                // Schedule final cleanup
                ~scheduledEvents[\cleanup] = SystemClock.sched(~sequenceConfig.cleanupDelay, {
                    "Performing final cleanup".postln;
                    if(~cleanupAllChordNotes.notNil) { ~cleanupAllChordNotes.value };
                    nil;
                });
                
                nil;
            });
            
            nil;
        });
        
        nil;
    });
    
    // Return a message confirming playback
    "Sequence scheduled: melody % followed by chord after % seconds".format(
        melodyKey, ~sequenceConfig.melodyToChordDelay
    );
};

// Function to stop everything
~stopSequence = {
    "Stopping all sounds and scheduled events".postln;
    
    // Cancel scheduled events
    ~scheduledEvents.do { |task| task.stop };
    ~scheduledEvents.clear;
    
    // Stop sounds
    ~stopAllMelodies.value;
    if(~cleanupAllChordNotes.notNil) { ~cleanupAllChordNotes.value };
    if(~releaseChord.notNil) { ~releaseChord.value };
    
    "Sequence stopped";
};

// Function to update sequence timing parameters
~setSequenceTiming = { |paramName, value|
    if(~sequenceConfig[paramName].notNil) {
        ~sequenceConfig[paramName] = value;
        "Updated % to %".format(paramName, value);
    } {
        "Unknown parameter: %".format(paramName);
    };
};

// Print usage instructions
"SIMPLE SEQUENCE READY:".postln;
"  ~playSequence.value;  // Play with default settings".postln;
"  ~playSequence.(\\set2, [60, 64, 67]);  // Play with custom melody and chord".postln;
"  ~stopSequence.value;  // Stop everything".postln;
"  ~setSequenceTiming.(\\melodyToChordDelay, 2.0);  // Change timing parameters".postln; 