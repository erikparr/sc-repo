    // Simple Chord Bend Implementation
// A simplified version that plays chords with synchronous start/end and unified envelopes

// Load setup files
// (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;

// ===== CONFIGURATION =====

// Default parameters
~params = (
    // Notes for each tuba (MIDI note numbers)
    chord: [92, 92, 92],    // C3, G2, C2

    // Bend amount in percentage (+/- 100%)
    bendPercents: [20, 15, 10],

    // Time parameters (seconds)
    duration: 10.0,         // Total duration of the gesture
    bendTime: 4.0,          // Time to reach peak bend
    returnTime: 3.0,        // Time to return from peak

    // Expression levels for each tuba (0-127)
    ccLevels: [100, 110, 120],

    // Envelope shape
    curveShape: \sin
);

// ===== HELPER FUNCTIONS =====

// Function to calculate bend value from percentage
~calcBendValue = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range (0-16383, center at 8192)
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383); // Ensure within valid range
};

// Function to recalculate envelope timing based on total duration
~calculateEnvelopeTiming = {
    var totalEnvTime = ~params.duration - 0.5; // Reserve 0.5s for final release
    var remainingTime, bendPortion, returnPortion;

    // Determine proportion between bend and return
    bendPortion = ~params.bendTime / (~params.bendTime + ~params.returnTime);
    returnPortion = ~params.returnTime / (~params.bendTime + ~params.returnTime);

    // Calculate new times maintaining proportions
    ~params.bendTime = totalEnvTime * bendPortion;
    ~params.returnTime = totalEnvTime * returnPortion;

    ["Adjusted timing - Duration:", ~params.duration,
     "Bend time:", ~params.bendTime,
     "Return time:", ~params.returnTime].postln;
};

// ===== OSC RESPONDER SETUP =====

// Remove any existing OSC responders for chord bend to avoid duplicates
OSCdef(\chordNoteOn).free;
OSCdef(\chordNoteOff).free;
OSCdef(\chordRelease).free;

// OSC responder for playing chord notes
OSCdef(\chordNoteOn, { |msg, time, addr, recvPort|
    var chordId = msg[1]; // Unique ID for this chord instance
    var vstIndex = msg[2].asInteger;
    var note = msg[3].asInteger;
    var velocity = msg[4].asInteger;
    var bendPercent = msg[5].asFloat;
    var ccLevel = msg[6].asInteger;
    var duration = msg[7].asFloat;
    var curveShape = msg[8];
    var bendTime = msg[9].asFloat;
    var returnTime = msg[10].asFloat;
    
    var vstKey = ("vsti" ++ vstIndex).asSymbol;
    var vst = ~vstList[vstKey];
    var bendValue = ~calcBendValue.(bendPercent);
    var bendSynth, ccSynth;
    var noteKey;
    
    if(vst.notNil) {
        // Log the action
        ("Chord " ++ chordId ++ " - Tuba " ++ vstIndex ++ " playing note: " ++ note).postln;
        
        // Send note on to VST
        vst.midi.noteOn(vstIndex, note, velocity);
        
        // Initialize registry if needed
        if(~chordNoteRegistry.isNil) { ~chordNoteRegistry = Dictionary.new };
        
        // Create a unique key for this note
        noteKey = chordId ++ "_" ++ vstIndex;
        
        // If a note with this key already exists, release it first
        if(~chordNoteRegistry[noteKey].notNil) {
            var oldData = ~chordNoteRegistry[noteKey];
            ("Cleaning up existing note: " ++ oldData.note).postln;
            
            // Release the old note
            oldData.vst.midi.noteOff(oldData.vstIndex, oldData.note, 0);
            
            // Free any associated synths
            if(oldData.bendSynth.notNil) { oldData.bendSynth.free; };
            if(oldData.ccSynth.notNil) { oldData.ccSynth.free; };
        };
        
        // Store the note data in the global registry with the chord ID
        ~chordNoteRegistry[noteKey] = (
            chordId: chordId,
            vstIndex: vstIndex,
            note: note,
            vst: vst
        );
        
        // Create bend envelope synth with proper error handling
        try {
            bendSynth = Synth(\BendEnvelope, [
                \start, 8192,              // Center
                \peak, bendValue,          // Calculated bend
                \end, 8192,                // Return to center
                \peakTime, bendTime,
                \returnTime, returnTime,
                \chanIndex, vstIndex,
                \peakCurve, curveShape,
                \returnCurve, curveShape
            ]);
            
            // Store the synth in the registry
            ~chordNoteRegistry[noteKey].bendSynth = bendSynth;
        } { |error|
            ("Error creating bend synth: " ++ error.errorString).postln;
        };
        
        // Create CC envelope synth with proper error handling
        try {
            ccSynth = Synth(\ccEnvelope, [
                \start, 0,
                \peak, ccLevel,
                \end, 0,
                \attackTime, bendTime,     // Same timing as bend
                \releaseTime, returnTime,  // Same timing as bend
                \chanIndex, vstIndex,
                \ccNum, 17,                // Expression control CC number
                \attackCurve, curveShape,
                \releaseCurve, curveShape
            ]);
            
            // Store the synth in the registry
            ~chordNoteRegistry[noteKey].ccSynth = ccSynth;
        } { |error|
            ("Error creating CC synth: " ++ error.errorString).postln;
        };
        
        // Schedule auto-release if duration is provided
        if(duration > 0) {
            SystemClock.sched(duration, {
                // Only auto-release if the note is still in the registry
                if(~chordNoteRegistry[noteKey].notNil) {
                    // Auto-release after duration
                    NetAddr.localAddr.sendMsg('/chord/noteOff', chordId, vstIndex, note);
                };
                nil; // Don't reschedule
            });
        };
    } {
        ("ERROR: VST not found for tuba " ++ vstIndex).postln;
    };
}, '/chord/noteOn');

// OSC responder for releasing chord notes
OSCdef(\chordNoteOff, { |msg, time, addr, recvPort|
    var chordId = msg[1];
    var vstIndex = msg[2].asInteger;
    var note = msg[3].asInteger;
    var noteKey = chordId ++ "_" ++ vstIndex;
    
    // Find the note in the registry
    if(~chordNoteRegistry.notNil && ~chordNoteRegistry[noteKey].notNil) {
        var noteData = ~chordNoteRegistry[noteKey];
        
        // Release the note with error handling
        try {
            ("Chord " ++ chordId ++ " - Releasing tuba " ++ vstIndex ++ " note " ++ note).postln;
            noteData.vst.midi.noteOff(vstIndex, note, 0);
        } { |error|
            ("Error releasing note: " ++ error.errorString).postln;
            // Send all-notes-off as a failsafe
            noteData.vst.midi.allNotesOff(vstIndex);
        };
        
        // Free any associated synths with error handling
        if(noteData.bendSynth.notNil) {
            try {
                noteData.bendSynth.free;
            } { |error|
                ("Error freeing bend synth: " ++ error.errorString).postln;
            };
        };
        
        if(noteData.ccSynth.notNil) {
            try {
                noteData.ccSynth.free;
            } { |error|
                ("Error freeing CC synth: " ++ error.errorString).postln;
            };
        };
        
        // Remove from registry
        ~chordNoteRegistry.removeAt(noteKey);
    } {
        ("WARNING: Note not found in registry: " ++ noteKey).postln;
        
        // Try to release the note anyway as a failsafe
        try {
            var vstKey = ("vsti" ++ vstIndex).asSymbol;
            var vst = ~vstList[vstKey];
            
            if(vst.notNil) {
                ("Failsafe release for tuba " ++ vstIndex ++ " note " ++ note).postln;
                vst.midi.noteOff(vstIndex, note, 0);
            };
        } { |error|
            ("Error in failsafe release: " ++ error.errorString).postln;
        };
    };
}, '/chord/noteOff');

// OSC responder for releasing an entire chord
OSCdef(\chordRelease, { |msg, time, addr, recvPort|
    var chordId = msg[1];
    var keysToRemove = List.new;
    
    // Find all notes for this chord ID
    if(~chordNoteRegistry.notNil) {
        ("Processing release for chord " ++ chordId).postln;
        
        ~chordNoteRegistry.keysValuesDo { |key, noteData|
            if(noteData.chordId == chordId) {
                // Release the note with error handling
                try {
                    ("Releasing chord " ++ chordId ++ " - Tuba " ++ noteData.vstIndex ++ " note " ++ noteData.note).postln;
                    noteData.vst.midi.noteOff(noteData.vstIndex, noteData.note, 0);
                } { |error|
                    ("Error releasing note: " ++ error.errorString).postln;
                    // Send all-notes-off as a failsafe
                    noteData.vst.midi.allNotesOff(noteData.vstIndex);
                };
                
                // Free any associated synths with error handling
                if(noteData.bendSynth.notNil) {
                    try {
                        noteData.bendSynth.free;
                    } { |error|
                        ("Error freeing bend synth: " ++ error.errorString).postln;
                    };
                };
                
                if(noteData.ccSynth.notNil) {
                    try {
                        noteData.ccSynth.free;
                    } { |error|
                        ("Error freeing CC synth: " ++ error.errorString).postln;
                    };
                };
                
                // Mark for removal
                keysToRemove.add(key);
            };
        };
        
        // Remove all processed keys
        keysToRemove.do { |key|
            ~chordNoteRegistry.removeAt(key);
        };
        
        ("Released all notes for chord " ++ chordId ++ " - total: " ++ keysToRemove.size).postln;
    };
}, '/chord/release');

// Initialize the chord note registry if needed
if(~chordNoteRegistry.isNil) { ~chordNoteRegistry = Dictionary.new };

// ===== PROCMOD IMPLEMENTATION =====

// Function to create a fresh ProcMod for the chord bend
~createChordProcMod = {
    ProcMod.new(
        Env([0, 1, 1, 0], [0.1, ~params.duration - 0.6, 0.5], \sin, 2),
        1.0,              // Amplitude
        \chordBend,       // ID
        nil,              // Group (create new)
        0,                // addAction
        1,                // target

        // Main function - will be called when ProcMod is played
        { |group, envbus, server|
            var chordId = "chord_" ++ Main.elapsedTime.round(0.001);
            var result;

            // Recalculate timing based on current duration
            ~calculateEnvelopeTiming.value;
            
            // Store the chordId for this instance
            ~currentChordId = chordId;
            
            // Log start time and chord ID
            ("Starting chord bend " ++ chordId ++ " with duration " ++ ~params.duration).postln;

            // Play each note in the chord via OSC
            3.do { |i|
                var note = ~params.chord[i];
                var bendPercent = ~params.bendPercents[i];
                var ccLevel = ~params.ccLevels[i];
                
                // Send OSC message to play this note
                NetAddr.localAddr.sendMsg(
                    '/chord/noteOn', 
                    chordId,             // Unique ID for this chord
                    i,                   // VST index
                    note,                // MIDI note
                    100,                 // Velocity
                    bendPercent,         // Bend percentage
                    ccLevel,             // CC level
                    ~params.duration,    // Duration
                    ~params.curveShape,  // Curve shape
                    ~params.bendTime,    // Bend time
                    ~params.returnTime   // Return time
                );
            };

            // Return a task that completes when everything is done
            result = Task({
                // Wait for the full duration plus a small buffer
                (~params.duration + 0.5).wait;
                
                // Don't release notes here - that should happen in onRelease or through auto-release
                ("Chord bend " ++ chordId ++ " task completed").postln;
            });

            result;
        },

        // Release function - runs after the ProcMod has fully released
        { |group, envbus|
            var chordId = ~currentChordId;
            
            if(chordId.notNil) {
                ("Chord bend " ++ chordId ++ " completed").postln;
                ~currentChordId = nil; // Clear the reference
            } {
                "Chord bend completed (no ID)".postln;
            };
        },

        // onReleaseFunc - runs when release is triggered
        { |group, envbus|
            var chordId = ~currentChordId;
            
            if(chordId.notNil) {
                ("Releasing chord bend " ++ chordId).postln;
                
                // Send OSC message to release the entire chord
                NetAddr.localAddr.sendMsg('/chord/release', chordId);
            } {
                "Warning: Releasing chord bend with no ID".postln;
                
                // Fallback: if no chord ID, try to release any active notes
                if(~chordNoteRegistry.notNil && ~chordNoteRegistry.size > 0) {
                    "Attempting to release all registered chord notes...".postln;
                    ~chordNoteRegistry.keysValuesDo { |key, noteData|
                        noteData.vst.midi.noteOff(noteData.vstIndex, noteData.note, 0);
                        if(noteData.bendSynth.notNil) { noteData.bendSynth.free; };
                        if(noteData.ccSynth.notNil) { noteData.ccSynth.free; };
                    };
                    ~chordNoteRegistry.clear;
                };
            };
        }
    );
};

// ===== PLAYBACK CONTROL FUNCTIONS =====

// Store the active ProcMod
~activeChordProcMod = nil;

// Play the chord - now creates a fresh ProcMod instance each time
~playChord = {
    "Playing chord with bend".postln;
    
    // Release any existing chord ProcMod
    if(~activeChordProcMod.notNil) {
        "Releasing previous chord ProcMod".postln;
        ~activeChordProcMod.release;
    };
    
    // Create a fresh ProcMod and play it
    ~activeChordProcMod = ~createChordProcMod.value;
    ~activeChordProcMod.play;
};

// Release the chord
~releaseChord = {
    "Releasing chord".postln;
    if(~activeChordProcMod.notNil && ~activeChordProcMod.isRunning) {
        ~activeChordProcMod.release;
    };
};

// Function to clean up all chord notes regardless of state
~cleanupAllChordNotes = {
    "Cleaning up all chord notes...".postln;
    
    // Clear any existing notes in the registry
    if(~chordNoteRegistry.notNil) {
        var count = 0;
        
        ~chordNoteRegistry.keysValuesDo { |key, noteData|
            // Increment count for logging
            count = count + 1;
            
            // Release the note with error handling
            try {
                ("Cleaning up: Tuba " ++ noteData.vstIndex ++ " note " ++ noteData.note).postln;
                noteData.vst.midi.noteOff(noteData.vstIndex, noteData.note, 0);
            } { |error|
                ("Error releasing note: " ++ error.errorString).postln;
            };
            
            // Free any associated synths with error handling
            if(noteData.bendSynth.notNil) {
                try {
                    noteData.bendSynth.free;
                } { |error|
                    ("Error freeing bend synth: " ++ error.errorString).postln;
                };
            };
            
            if(noteData.ccSynth.notNil) {
                try {
                    noteData.ccSynth.free;
                } { |error|
                    ("Error freeing CC synth: " ++ error.errorString).postln;
                };
            };
        };
        
        // Clear the registry after processing all entries
        ~chordNoteRegistry.clear;
        
        ("Cleaned up " ++ count ++ " chord notes from registry").postln;
    };
    
    // All-notes-off message to all VSTs as a failsafe
    ~vstList.do { |vst, i|
        5.do { |chan|
            try {
                vst.midi.allNotesOff(chan);
            } { |error|
                ("Error sending all-notes-off: " ++ error.errorString).postln;
            };
        };
    };
    
    // Reset the current chord ID as well
    ~currentChordId = nil;
    
    "Chord cleanup completed".postln;
};

// Function to update parameters
~updateParams = { |newParams|
    // Update parameters with new values
    newParams.keysValuesDo { |key, value|
        if(~params.includesKey(key)) {
            ~params[key] = value;
        };
    };

    "Parameters updated".postln;
};

// Function to set the gesture duration directly
~setDuration = { |seconds|
    ~params.duration = seconds;
    ["Gesture duration set to", seconds, "seconds"].postln;
};

// ===== PRESET SYSTEM =====

// Storage for presets
~presets = Dictionary.new;

// Add the default preset
~presets.put(\default, ~params.copy);

// Create some example presets
~presets.put(\gentle, (
    chord: [60, 55, 48],        // C3, G2, C2
    bendPercents: [10, 7, 5],   // Smaller bends
    duration: 12.0,             // Longer total duration
    bendTime: 6.0,              // Slower bend
    returnTime: 4.0,            // Slower return
    ccLevels: [80, 90, 100],    // Lower expression
    curveShape: \sin
));

~presets.put(\dramatic, (
    chord: [60, 55, 48],        // C3, G2, C2
    bendPercents: [40, 30, 20], // Larger bends
    duration: 6.0,              // Shorter total duration
    bendTime: 2.0,              // Faster bend
    returnTime: 1.5,            // Faster return
    ccLevels: [110, 115, 120],  // Higher expression
    curveShape: \exp            // More exponential curve
));

~presets.put(\unison, (
    chord: [48, 48, 48],        // All C2
    bendPercents: [20, -15, 10], // Mixed directions
    duration: 12.0,             // Longer total duration
    bendTime: 5.0,              // Slower bend
    returnTime: 4.0,            // Slower return
    ccLevels: [100, 100, 100],  // Equal expression
    curveShape: \sin
));

// Function to apply a preset
~applyPreset = { |presetName|
    var preset = ~presets[presetName];

    if(preset.notNil) {
        ~params = preset.copy;
        ("Applied preset: " ++ presetName).postln;
    } {
        ("Preset not found: " ++ presetName).postln;
    };
};

// Function to list all presets
~listPresets = {
    "Available presets:".postln;
    ~presets.keys.do { |key|
        key.postln;
    };
};

// Function to save the current settings as a preset
~savePreset = { |presetName|
    ~presets.put(presetName, ~params.copy);
    ("Saved preset: " ++ presetName).postln;
};

"Simple Chord Bend system initialized.".postln;
"Available commands:".postln;
"  ~playChord.value - Play the chord with bend".postln;
"  ~releaseChord.value - Release the chord manually".postln;
"  ~cleanupAllChordNotes.value - Force cleanup of all chord notes".postln;
"  ~setDuration.(seconds) - Set the total gesture duration".postln;
"  ~applyPreset.(\\presetName) - Apply a preset".postln;
"  ~listPresets.value - List available presets".postln;
"  ~savePreset.(\\presetName) - Save current settings as a preset".postln;


// Examples of usage:

// Play a chord with the default preset (automatically releases after duration)
// ~playChord.value;

// Set a custom duration and play
// ~setDuration.(15);
// ~playChord.value;

// Try different presets
// ~applyPreset.(\gentle);
// ~playChord.value;

// ~applyPreset.(\dramatic); // Has a shorter duration
// ~playChord.value;

// ~applyPreset.(\unison);
// ~playChord.value;

// Manual release is still available but not usually needed
// ~releaseChord.value;