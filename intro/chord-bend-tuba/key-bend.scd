// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// Clear any previous handlers
if(~noteOnFunc.notNil) { ~noteOnFunc.free };
if(~noteOffFunc.notNil) { ~noteOffFunc.free };
if(~ccFunc1.notNil) { ~ccFunc1.free };
if(~ccFunc2.notNil) { ~ccFunc2.free };
if(~sliderFunc1.notNil) { ~sliderFunc1.free };
if(~oscFunc.notNil) { ~oscFunc.free };

// Disable the MIDIController's note handling
if(~midiController.notNil) {
    ~midiController.setNoteHandlingEnabled(false);
    ["MIDIController note handling disabled for", ~midiController].postln;
} {
    "WARNING: MIDIController not found!".postln;
};

// Define the OSC function for pitch bend
~oscFunc = OSCFunc({ |msg|
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    var vstKey = (\vsti ++ chanIndex).asSymbol;
    
    // Apply the bend to the appropriate VST
    if(~vstList[vstKey].notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        ~vstList[vstKey].midi.bend(chanIndex, bendValue);
        
        // Log less frequently to avoid console spam
        if(~logCounter % 30 == 0) {
            ["Bend value:", bendValue, "Chan:", chanIndex, "VST:", vstKey].postln;
        };
        ~logCounter = ~logCounter + 1;
    };
}, '/bend', s.addr);

// Ensure the BendEnvelope1 SynthDef is defined
SynthDef(\BendEnvelope1, {
    arg start = 8192, end = 8192, dur = 1, chanIndex = 0;
    var env;
    
    env = EnvGen.kr(
        Env.new(
            levels: [start, end],
            times: [dur],
            curve: \sin
        ),
        doneAction: 2
    );
    
    SendReply.kr(
        Impulse.kr(100),
        '/bend',
        [chanIndex, env],
        replyID: chanIndex  // Unique replyID for each channel
    );
}).add;

// Track active notes and variables
~activeNotes = Dictionary.new;
~bendAmount = 0; // Default to no bend
~logCounter = 0;

// MIDI note-on handler
~noteOnFunc = MIDIFunc.noteOn({ |velocity, noteNum, channel, srcID|
    var vstIndex = ~activeNotes.size % 3;
    var vstKey = (\vsti ++ vstIndex).asSymbol;
    var vst = ~vstList[vstKey];
    
    // Get timing parameters from sliders
    var bendDelay = ~midiController.sliderValues[0].linlin(0, 127, 0.001, 2.0);
    var bendDur = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 4.0);
    
    ["Playing note", noteNum, "on", vstKey, vstIndex].postln;
    ["Using bend delay:", bendDelay, "seconds, bend duration:", bendDur, "seconds"].postln;
    
    if(vst.notNil) {
        // Play the note
        vst.midi.noteOn(vstIndex, noteNum, velocity);
        
        // Store the note info
        ~activeNotes[noteNum] = (\vstIndex: vstIndex, \vstKey: vstKey);
        
        // Schedule the bend after the delay
        SystemClock.sched(bendDelay, {
            // Only bend if note is still active
            if(~activeNotes[noteNum].notNil) {
                var semitones = ~bendAmount;
                var startBend = 8192; // Center position
                var targetBend = 8192 + (semitones * 682);
                
                ["Starting bend for note", noteNum, "by", semitones, "semitones over", bendDur, "seconds"].postln;
                
                // Create the bend envelope synth using the proper SynthDef
                Synth(\BendEnvelope1, [
                    \start, startBend, 
                    \end, targetBend,
                    \dur, bendDur,
                    \chanIndex, vstIndex
                ]);
            };
            nil; // Don't reschedule
        });
    };
});

// MIDI note-off handler
~noteOffFunc = MIDIFunc.noteOff({ |velocity, noteNum, channel, srcID|
    var noteData = ~activeNotes[noteNum];
    
    if(noteData.notNil) {
        var vstIndex = noteData[\vstIndex];
        var vstKey = noteData[\vstKey];
        var vst = ~vstList[vstKey];
        
        ["Note off", noteNum, "on", vstKey].postln;
        
        if(vst.notNil) {
            // Just release the note at its current bend position
            // Don't bend back to center
            vst.midi.noteOff(vstIndex, noteNum, 0);
            
            // Remove from active notes
            ~activeNotes.removeAt(noteNum);
        };
    };
});

// Knob 1 (CC 16) controls bend amount
~ccFunc1 = MIDIFunc.cc({ |val|
    ~bendAmount = val.linlin(0, 127, 0, 12);
    ["Bend amount set to", ~bendAmount, "semitones"].postln;
}, 16);

// Slider monitoring function - just for logging
~sliderFunc1 = MIDIFunc.cc({ |val, num|
    if(num == 2) { // Slider 3 (CC 2) controls bend amount
        ~bendAmount = val.linlin(0, 127, -12, 12);
        ["Bend amount set to", ~bendAmount, "semitones"].postln;
    } {
        ["Slider", num, "set to", val].postln;
    };
}, (0..7), 0);  // All 8 sliders on channel 0

// Cleanup function
~cleanup = {
    // Re-enable MIDIController note handling if it exists
    if(~midiController.notNil) {
        ~midiController.setNoteHandlingEnabled(true);
        "MIDIController note handling re-enabled".postln;
    };

    // Free our handlers
    if(~noteOnFunc.notNil) { ~noteOnFunc.free };
    if(~noteOffFunc.notNil) { ~noteOffFunc.free };
    if(~ccFunc1.notNil) { ~ccFunc1.free };
    if(~ccFunc2.notNil) { ~ccFunc2.free };
    if(~sliderFunc1.notNil) { ~sliderFunc1.free };
    if(~oscFunc.notNil) { ~oscFunc.free };
    
    // Reset all VSTs
    3.do { |i|
        var vstKey = (\vsti ++ i).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            vst.midi.bend(i, 8192);
            vst.midi.allNotesOff(i);
        };
    };
    
    ~activeNotes.clear;
    "Cleaned up".postln;
};

"Ready to play. Using sliders for timing control:".postln;
"Slider 1 (CC 0): Controls bend delay (0.001-2.0 seconds)".postln;
"Slider 2 (CC 1): Controls bend duration (0.001-4.0 seconds)".postln;
"Slider 3 (CC 2): Controls bend amount (-12 to +12 semitones)".postln;
"Run ~cleanup.value to restore normal MIDIController operation.".postln;
)

// Run this to clean up and restore MIDIController
// ~cleanup.value;