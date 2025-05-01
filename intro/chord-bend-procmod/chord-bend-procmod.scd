// Chord Bend with ProcMod
// This file reimplements the chord-bend-ctk-test.scd functionality
// using ProcMod instead of CTK for high-level gestural control

// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// ===== Helper Functions =====

// Function to calculate bend value from percentage
~calcBendPercent = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range (0-16383, center at 8192)
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383); // Ensure within valid range
};

// ===== Main Implementation =====

// Create a Dictionary to store ProcMod instances for easy access
~bendProcs = Dictionary.new;

// Create an array to store ProcMod instances for ProcEvents
~bendProcArray = [];

// Define the envelope shape for the overall process
~procEnv = Env([0, 1, 1, 0], [0.1, 8, 0.5], \sin, 2);

// Create a ProcMod for each tuba
3.do { |i|
    var vstKey = ("vsti" ++ i).asSymbol;
    var bendProc;
    
    // Create a ProcMod for each tuba's bend and expression control
    bendProc = ProcMod.new(
        ~procEnv,     // Overall amplitude envelope
        1.0,          // Initial amplitude 
        ("tuba" ++ i).asSymbol,  // Unique ID for each tuba
        nil,          // Create a new group
        0,            // addAction
        1,            // target (default group)
        
        // Main function - will be called when the ProcMod is played
        { |group, envbus|
            var vst = ~vstList[vstKey];
            var startChord = [92, 92, 92]; // Default chord - can be modified
            var bendPercents = [20, 20, 20]; // Default bend - can be modified
            var bendDurations = [10.0, 7.5, 6.0]; // Default durations - can be modified
            var exprLevels = [100, 110, 120]; // Default expression levels - can be modified
            var exprDurations = [1.0, 1.2, 1.4]; // Default expression durations - can be modified
            
            var bendValue = ~calcBendPercent.value(bendPercents[i]);
            var note = startChord[i];
            var bendDur = bendDurations[i];
            var exprLevel = exprLevels[i];
            var exprDur = exprDurations[i];
            var bendSynth, exprSynth;
            
            // Keep a reference to this process's synths for control later
            ~bendSynths = ~bendSynths ? Array.newClear(3);
            ~exprSynths = ~exprSynths ? Array.newClear(3);
            
            if(vst.notNil) {
                // Send noteOn to VST
                vst.midi.noteOn(i, note, 100);
                ("Tuba " ++ i ++ " playing note: " ++ note).postln;
                
                // Start bend envelope synth (will send OSC to bend handler)
                bendSynth = Synth(\BendEnvelope, [
                    \start, 8192,         // Center
                    \peak, bendValue,     // Calculated bend
                    \end, 8192,           // Return to center
                    \peakTime, bendDur,   // Time to reach peak
                    \returnTime, 0.5,     // Time to return (customize as needed)
                    \chanIndex, i
                ], group);
                
                // Store reference to the synth
                ~bendSynths[i] = bendSynth;
                
                // Start expression envelope synth (optional)
                exprSynth = Synth(\ExpressionEnvelope, [
                    \start, 0,
                    \peak, exprLevel,
                    \end, 0,
                    \attackTime, exprDur,
                    \releaseTime, 0.5,
                    \chanIndex, i,
                    \ccNum, 17
                ], group);
                
                // Store reference to the synth
                ~exprSynths[i] = exprSynth;
                
                // Return the task that will be executed when the ProcMod is released
                Task({
                    // Wait for the bend to complete
                    (bendDur + 0.5).wait;
                    
                    // Note will be released by onReleaseFunc, but in case process is killed,
                    // schedule a safety noteOff after the bend completes
                    SystemClock.sched(5.0, {
                        if(~bendProcs[("tuba" ++ i).asSymbol].isRunning.not) {
                            ("Safety noteOff for tuba " ++ i).postln;
                            vst.midi.noteOff(i, note, 0);
                        };
                        nil;
                    });
                });
            } {
                ("VST not found for tuba " ++ i).postln;
                nil; // Return nil if no VST
            };
        },
        
        // Release function - executed after the ProcMod has completed its release
        { |group, envbus|
            ("Tuba " ++ i ++ " process completed").postln;
        },
        
        // onReleaseFunc - executed when release is called (before completion)
        { |group, envbus|
            var vst = ~vstList[vstKey];
            var startChord = [92, 92, 92]; // Should match the notes in the main function
            var note = startChord[i];
            
            ("Releasing tuba " ++ i).postln;
            
            // Send noteOff to VST
            if(vst.notNil) {
                vst.midi.noteOff(i, note, 0);
            };
            
            // Free the synths if they exist
            if(~bendSynths.notNil and: { ~bendSynths[i].notNil }) {
                ~bendSynths[i].free;
                ~bendSynths[i] = nil;
            };
            
            if(~exprSynths.notNil and: { ~exprSynths[i].notNil }) {
                ~exprSynths[i].free;
                ~exprSynths[i] = nil;
            };
        }
    );
    
    // Add the ProcMod to the Dictionary for easy access
    ~bendProcs.put(("tuba" ++ i).asSymbol, bendProc);
    
    // Add the ProcMod to the array for ProcEvents
    ~bendProcArray = ~bendProcArray.add(bendProc);
};

// Now create ProcEvents with the array of ProcMods
~chordBendProcEvents = ProcEvents.new(~bendProcArray);

// ===== MIDI Control Extensions =====

// Create a routine to update parameters from MIDI input
~midiControlEnabled = false;
~updateParamsFromMIDI = {
    if(~midiController.notNil and: { ~midiControlEnabled }) {
        3.do { |i|
            var tubaProcKey = ("tuba" ++ i).asSymbol;
            var bendValue, bendDur, exprLevel, exprDur;
            
            // Only update if the process is running
            if(~bendProcs[tubaProcKey].isRunning) {
                // Map sliders 1-3 to bend percentages (0-100%)
                bendValue = ~midiController.getSliderValue(i).linlin(0, 127, 0, 100);
                bendValue = ~calcBendPercent.value(bendValue);
                
                // Map sliders 4-6 to bend durations (0.5-15 seconds)
                bendDur = ~midiController.getSliderValue(i+3).linlin(0, 127, 0.5, 15.0);
                
                // Map slider 7 to expression levels for all channels (0-127)
                exprLevel = ~midiController.getSliderValue(6).linlin(0, 127, 0, 127);
                
                // Map slider 8 to expression durations for all channels (0.1-5.0 seconds)
                exprDur = ~midiController.getSliderValue(7).linlin(0, 127, 0.1, 5.0);
                
                // Update parameters if synths exist
                if(~bendSynths.notNil and: { ~bendSynths[i].notNil }) {
                    ~bendSynths[i].set(\peak, bendValue);
                    ~bendSynths[i].set(\peakTime, bendDur);
                    ~bendSynths[i].set(\returnTime, bendDur * 0.5);
                };
                
                if(~exprSynths.notNil and: { ~exprSynths[i].notNil }) {
                    ~exprSynths[i].set(\peak, exprLevel);
                    ~exprSynths[i].set(\attackTime, exprDur);
                    ~exprSynths[i].set(\releaseTime, exprDur * 0.5);
                };
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

// ===== Control Functions =====

// Function to play all processes together
~playChordBend = {
    // Reset any existing processes
    ~stopChordBend.value;
    
    // Enable MIDI control if MIDIController exists
    if(~midiController.notNil) {
        ~midiControlEnabled = true;
        ~midiUpdateRoutine.reset.play;
        "MIDI control enabled. Use sliders to control bend and expression.".postln;
    };
    
    // Play all processes together - using next method for ProcEvents
    ~chordBendProcEvents.next;
    "Chord bend started.".postln;
};

// Function to stop all processes
~stopChordBend = {
    // Stop MIDI control
    ~midiControlEnabled = false;
    ~midiUpdateRoutine.stop;
    
    // Release all processes
    ~chordBendProcEvents.releaseAll;
    
    // Additional cleanup if needed
    3.do { |i|
        if(~bendSynths.notNil and: { ~bendSynths[i].notNil }) {
            ~bendSynths[i].free;
            ~bendSynths[i] = nil;
        };
        
        if(~exprSynths.notNil and: { ~exprSynths[i].notNil }) {
            ~exprSynths[i].free;
            ~exprSynths[i] = nil;
        };
    };
    
    "Chord bend stopped.".postln;
};

// Function to update parameters programmatically
~updateParams = { |bendPercents, bendDurations, exprLevels, exprDurations|
    3.do { |i|
        var tubaProcKey = ("tuba" ++ i).asSymbol;
        var bendValue, bendDur, exprLevel, exprDur;
        
        // Only update if the process is running
        if(~bendProcs[tubaProcKey].isRunning) {
            // Apply new parameters if provided
            if(bendPercents.notNil) {
                bendValue = ~calcBendPercent.value(bendPercents[i]);
                if(~bendSynths.notNil and: { ~bendSynths[i].notNil }) {
                    ~bendSynths[i].set(\peak, bendValue);
                };
            };
            
            if(bendDurations.notNil) {
                bendDur = bendDurations[i];
                if(~bendSynths.notNil and: { ~bendSynths[i].notNil }) {
                    ~bendSynths[i].set(\peakTime, bendDur);
                    ~bendSynths[i].set(\returnTime, bendDur * 0.5);
                };
            };
            
            if(exprLevels.notNil) {
                exprLevel = exprLevels[i];
                if(~exprSynths.notNil and: { ~exprSynths[i].notNil }) {
                    ~exprSynths[i].set(\peak, exprLevel);
                };
            };
            
            if(exprDurations.notNil) {
                exprDur = exprDurations[i];
                if(~exprSynths.notNil and: { ~exprSynths[i].notNil }) {
                    ~exprSynths[i].set(\attackTime, exprDur);
                    ~exprSynths[i].set(\releaseTime, exprDur * 0.5);
                };
            };
        };
    };
    
    "Parameters updated.".postln;
};

// Function to play individual tubas
~playTuba = { |tubaIndex|
    var tubaProcKey = ("tuba" ++ tubaIndex).asSymbol;
    
    if(~bendProcs[tubaProcKey].notNil) {
        ~bendProcs[tubaProcKey].play;
        ("Tuba " ++ tubaIndex ++ " started.").postln;
    };
};

// Function to stop individual tubas
~releaseTuba = { |tubaIndex|
    var tubaProcKey = ("tuba" ++ tubaIndex).asSymbol;
    
    if(~bendProcs[tubaProcKey].notNil) {
        ~bendProcs[tubaProcKey].release;
        ("Tuba " ++ tubaIndex ++ " released.").postln;
    };
};
)

// Run these commands after the initialization block

// Play all tubas together
~playChordBend.value;

// Update parameters during performance
// ~updateParams.value([30, 20, 10], [5, 8, 12], [90, 100, 110], [0.8, 1.2, 1.6]);

// Stop all tubas
// ~stopChordBend.value;

// Play individual tubas
// ~playTuba.value(0);
// ~playTuba.value(1);
// ~playTuba.value(2);

// Release individual tubas
// ~releaseTuba.value(0);
// ~releaseTuba.value(1);
// ~releaseTuba.value(2);
