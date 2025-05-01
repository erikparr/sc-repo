// Chord Bend Granular System with ProcMod
// This file implements a granular triggering system that continuously creates new notes
// when the previous note finishes, with a fixed duration per note and global process duration

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
    // Notes for each tuba (MIDI note numbers) - will be expanded as needed
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
    initialGrainDuration: 0.5,    // Starting duration of each note/grain in seconds
    finalGrainDuration: 3.0,      // Ending duration of each note/grain in seconds  
    globalDuration: 4.0,          // Total duration of the granular process
    grainOverlapRatio: 0.2,       // Overlap between grains as proportion of grain duration
    
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

// Create envelope for grain duration evolution
~createGrainDurationEnv = {
    Env(
        [~defaultParams.initialGrainDuration, ~defaultParams.finalGrainDuration],
        [~defaultParams.globalDuration],
        \lin
    );
};

// ===== GRANULAR SYSTEM IMPLEMENTATION =====

// State variables for granular system - dynamically sized to number of instruments
~grainState = Array.fill(~numInstruments, { 
    (
        noteIndex: 0,            // Index in the note array
        grainCount: 0            // Count of played grains
    )
});

// ===== PROCMOD IMPLEMENTATION =====

// Container for ProcMods - dynamically sized to number of instruments
~granularProcMods = Array.newClear(~numInstruments);

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
    vst.midi.noteOn(tubaIndex, note, 100);
    
    // Create bend envelope synth
    Synth(\BendEnvelope, [
        \start, 8192,
        \peak, bendValue,
        \end, 8192,
        \peakTime, bendDur,
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
        \attackTime, exprDur,
        \releaseTime, exprDur * 0.5,
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

// Create ProcMods for each tuba - dynamically based on number of instruments
~numInstruments.do { |i|
    var tubaProcMod;
    
    // Create the amplitude envelope
    ~procEnv = Env([0, 1, 1, 0], 
                   [~defaultParams.attackTime, 
                    ~defaultParams.globalDuration - ~defaultParams.attackTime - ~defaultParams.releaseTime, 
                    ~defaultParams.releaseTime], 
                   [\sin, \lin, \sin], 
                   1);  // Sustain node index
    
    // Create a ProcMod for this tuba
    tubaProcMod = ProcMod.new(
        ~procEnv,                 // Envelope
        1.0,                      // Amplitude
        ("tubagrain" ++ i).asSymbol,  // ID
        nil,                      // Group (create new)
        0,                        // addAction
        1,                        // target
        
        // Main function - plays granular notes with evolving durations
        { |group, envbus|
            var vst = ~vstList[("vsti" ++ i).asSymbol];
            var state = ~grainState[i];
            var resultTask;
            var durationEnv = ~createGrainDurationEnv.value;
            
            if(vst.isNil) {
                ("VST not found for tuba " ++ i).postln;
                ^nil;
            };
            
            // Reset the grain counter
            state.grainCount = 0;
            
            // Create a task for managing the granular process
            resultTask = Task({
                var startTime = SystemClock.seconds;
                var elapsed = 0;
                var totalDuration = ~defaultParams.globalDuration;
                var waitTime, currentGrainDuration, grain, note, normalizedTime;
                
                // Run until we reach the global duration
                while { elapsed < totalDuration } {
                    note = ~defaultParams.noteArrays[i][0]; // Just use the first note
                    normalizedTime = elapsed / totalDuration; // 0 to 1
                    
                    // Sample the envelope to get current grain duration
                    currentGrainDuration = durationEnv.at(normalizedTime);
                    
                    // Debug output - less frequent to reduce console spam
                    if(state.grainCount % 3 == 0) {
                        ("Current grain duration for tuba " ++ i ++ ": " ++ currentGrainDuration.round(0.001)).postln;
                    };
                    
                    // Play the grain with the current duration
                    grain = ~playGrain.(i, note, currentGrainDuration);
                    
                    // Count this grain
                    state.grainCount = state.grainCount + 1;
                    
                    // Debug output for every grain
                    ("Tuba " ++ i ++ " grain " ++ state.grainCount ++ 
                     ": note " ++ note ++ 
                     ", duration " ++ currentGrainDuration.round(0.001) ++ 
                     "s, elapsed " ++ elapsed.round(0.01) ++ "s").postln;
                    
                    // Calculate wait time (grain duration minus overlap)
                    waitTime = currentGrainDuration * (1 - ~defaultParams.grainOverlapRatio);
                    waitTime = waitTime.max(0.05); // Ensure minimum wait
                    
                    // Schedule note release just before next grain
                    SystemClock.sched(waitTime - 0.05, {
                        if(vst.notNil) {
                            vst.midi.noteOff(i, grain.note, 0);
                        };
                        nil;
                    });
                    
                    // Wait for next grain
                    waitTime.wait;
                    elapsed = elapsed + waitTime;
                };
                
                ("Tuba " ++ i ++ " granular process completed with " ++ 
                 state.grainCount ++ " grains").postln;
            });
            
            // Return the task - ProcMod handles it
            resultTask;
        },
        
        // releaseFunc - runs after the process is complete
        { |group, envbus|
            var vst = ~vstList[("vsti" ++ i).asSymbol];
            
            ("ProcMod for tuba " ++ i ++ " granular process completed").postln;
            
            // Additional cleanup if needed
        }
    );
    
    // Store in our array
    ~granularProcMods[i] = tubaProcMod;
};

// ===== PLAYBACK CONTROL FUNCTIONS =====

// Play a single tuba granular process
~playGranularTuba = { |tubaIndex|
    if((tubaIndex >= 0) && (tubaIndex < ~numInstruments) && ~granularProcMods[tubaIndex].notNil) {
        // Only play if not already running
        if(~granularProcMods[tubaIndex].isRunning.not) {
            ("Starting granular process for tuba " ++ tubaIndex).postln;
            ~granularProcMods[tubaIndex].play;
        } {
            ("Tuba " ++ tubaIndex ++ " granular process already running").postln;
        };
    };
};

// Release a single tuba granular process
~releaseGranularTuba = { |tubaIndex|
    if((tubaIndex >= 0) && (tubaIndex < ~numInstruments) && ~granularProcMods[tubaIndex].notNil) {
        if(~granularProcMods[tubaIndex].isRunning) {
            ("Releasing granular process for tuba " ++ tubaIndex).postln;
            ~granularProcMods[tubaIndex].release;
        } {
            ("Tuba " ++ tubaIndex ++ " granular process not running").postln;
        };
    };
};

// Play all tubas (with optional offset)
~playAllGranularTubas = { |withOffset=true|
    ~numInstruments.do { |i|
        var delay = if(withOffset, i * 0.15, 0);
        
        SystemClock.sched(delay, {
            ~playGranularTuba.(i);
            nil;
        });
    };
};

// Play a subset of tubas (start index, count, with optional offset)
~playGranularTubaGroup = { |startIdx=0, count=3, withOffset=true|
    count = min(count, ~numInstruments - startIdx);
    count.do { |i|
        var idx = startIdx + i;
        var delay = if(withOffset, i * 0.15, 0);
        
        SystemClock.sched(delay, {
            ~playGranularTuba.(idx);
            nil;
        });
    };
};

// Release all tubas (with optional offset)
~releaseAllGranularTubas = { |withOffset=true|
    ~numInstruments.do { |i|
        var delay = if(withOffset, i * 0.15, 0);
        
        SystemClock.sched(delay, {
            ~releaseGranularTuba.(i);
            nil;
        });
    };
};

// Update parameters for the granular process
~updateGranularParams = { |paramName, value|
    if(~defaultParams[paramName].notNil) {
        ~defaultParams[paramName] = value;
        ("Updated granular parameter: " ++ paramName ++ " = " ++ value).postln;
    } {
        ("Unknown parameter: " ++ paramName).postln;
    };
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

// Update grain duration envelope
~setGrainDurationRange = { |initialDur, finalDur|
    ~defaultParams.initialGrainDuration = initialDur;
    ~defaultParams.finalGrainDuration = finalDur;
    ("Grain duration will evolve from " ++ initialDur ++ " to " ++ finalDur ++ " seconds").postln;
};

"Granular ProcMod system initialized with " ++ ~numInstruments ++ " tubas.".postln;
"Available commands:".postln;
"  ~playGranularTuba.(0-" ++ (~numInstruments-1) ++ ") - Play individual tuba granular process".postln;
"  ~releaseGranularTuba.(0-" ++ (~numInstruments-1) ++ ") - Release individual tuba granular process".postln;
"  ~playAllGranularTubas.value - Play all tubas with granular process".postln;
"  ~playGranularTubaGroup.(startIdx, count) - Play a subset of tubas".postln;
"  ~releaseAllGranularTubas.value - Release all tubas".postln;
"  ~updateGranularParams.(\\paramName, value) - Update granular parameters".postln;
"  ~setNotes.(tubaIndex, note) - Set note for a tuba".postln;
"  ~setAllNotes.(note) - Set the same note for all tubas".postln;
"  ~setChord.([noteArray]) - Set different notes to create a chord".postln;
"  ~setGrainDurationRange.(initialDur, finalDur) - Set range for grain duration evolution".postln;
)

// Examples of usage (uncomment to use):

// Example 1: Simple test with all tubas using default settings
~playAllGranularTubas.value;
// ~releaseAllGranularTubas.value;

// Example 2: Customize notes for tubas to create a chord
/*
~setChord.([92, 86, 83, 89, 95, 77]);  // Six different notes
~playAllGranularTubas.value;
*/

// Example 3: Play just the first 3 tubas
/*
~playGranularTubaGroup.(0, 3);
*/

// Example 4: Play just the second 3 tubas
/*
~playGranularTubaGroup.(3, 3);
*/

// Example 5: Change grain duration evolution
/*
~setGrainDurationRange.(0.2, 4.0);  // More extreme evolution
~playAllGranularTubas.value;
*/

// Example 6: Adjust granular parameters
/*
~updateGranularParams.(\grainOverlapRatio, 0.3);  // More overlap
~updateGranularParams.(\globalDuration, 8.0);     // Longer global duration
~playAllGranularTubas.value;
*/
