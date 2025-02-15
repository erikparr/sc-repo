// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// Clean up any existing OSC functions
~oscFunc.free;

// OSC Function for pitch bend
~logCounter = 0;

~oscFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    var vstKey = (\vsti ++ chanIndex).asSymbol;

    ~logCounter = ~logCounter + 1;
    if(~logCounter % 5 == 0) {  // Only print every 5th message
        var replyID = msg[2];
        var chanIndex = msg[3].asInteger;
        var bendValue = msg[4].asInteger;
        var vstKey = (\vsti ++ chanIndex).asSymbol;

        ["OSC Debug:", 
            "ReplyID:", replyID,
            "Chan:", chanIndex, 
            "VST:", vstKey, 
            "Bend:", bendValue
        ].postln;
    };
    
    // Always send the bend value, just don't print it
    if(~vstList[vstKey].notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        ~vstList[vstKey].midi.bend(chanIndex, bendValue);
    };
}, '/bend', s.addr);

// Modified bend envelope
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
)

(
// Helper function for bend calculation
~calcBendValue = {|fromNote, toNote, currentBend=8192|
    var semitones = toNote - fromNote;
    var unitsPerSemitone = 682;  // 8192/12 = 682.666... units per semitone
    var bendOffset = semitones * unitsPerSemitone;
    var bendValue;

    // Calculate relative to current bend position
    bendValue = currentBend + bendOffset;
    bendValue = bendValue.clip(0, 16383).asInteger;

    // For debugging
    ["Bend calculation:", 
        "From:", fromNote, 
        "To:", toNote, 
        "Semitones:", semitones,
        "Current:", currentBend,
        "Offset:", bendOffset,
        "Final:", bendValue
    ].postln;

    bendValue;
};

// Define two melodies using notes from original chord sequence as starting point
~melody1 = [
    // [note, duration before bend, bend duration]
    // alernate between 0.5 and 1 second duration before bend
    [46, 1.0, 0.5],  // Bend 6: 46->53 = 10920 (+7 semitones)
    [53, 2.0, 0.5],  // Bend 7: 53->51 = 10238 (+7 semitones)
    [51, 1.0, 0.5],  // Bend 8: 51->58 = 9556 (+2 semitones)
    [58, 2.0, 0.5],  // Bend 9: 58->54 = 10238 (+7 semitones)
    [54, 1.0, 0.5],  // Bend 10: 54->58 = 10920 (+6 semitones)
    [61, 2.0, 0.5],  // Bend 11: 58->61 = 10920 (+6 semitones)
    [58, 1.0, 0.5],  // Bend 12: 61->58 = 10238 (+7 semitones)
    [65, 2.0, 0.5],  // Bend 13: 58->65 = 10238 (+7 semitones)
];

~melody2 = [
    // [note, duration before bend, bend duration]
    // alernate between 0.5 and 1 second
    [46, 1.0, 0.5],  // Bend 6: 46->53 = 10920 (+7 semitones)
    [53, 2.0, 0.5],  // Bend 7: 53->51 = 10238 (+7 semitones)
    [51, 1.0, 0.5],  // Bend 8: 51->58 = 9556 (+2 semitones)
    [58, 2.0, 0.5],  // Bend 9: 58->54 = 10238 (+7 semitones)
    [54, 1.0, 0.5],  // Bend 10: 54->58 = 10920 (+6 semitones)
    [61, 2.0, 0.5],  // Bend 11: 58->61 = 10920 (+6 semitones)
    [58, 1.0, 0.5],  // Bend 12: 61->58 = 10238 (+7 semitones)
    [65, 2.0, 0.5],  // Bend 13: 58->65 = 10238 (+7 semitones)
];

// Initialize the lastBends array for all VSTs
~lastBends = Array.fill(6, { 8192 });  // Initialize with center value for all 6 VSTs

// Task for playing both melodies simultaneously
~dualMelodyTask = Task({
        var melody1Index = 0;
    var melody2Index = 0;
    var activeSynths = List.new;
    var activeNotes = List.new;
    var firstRun = true;

    // Add VST verification
    ["VST Status:"].postln;
    6.do { |vstIndex|
        var vstKey = (\vsti ++ vstIndex).asSymbol;
        ["VST", vstIndex, ":", 
            "Key:", vstKey, 
            "Available:", ~vstList[vstKey].notNil,
            "MIDI:", if(~vstList[vstKey].notNil) { ~vstList[vstKey].midi.notNil } { false }
        ].postln;
    };


    loop {
        // Only play notes on first run
        if(firstRun) {
            // Reset all bends to center (8192) before playing new notes
            6.do { |vstIndex|
                var vstKey = (\vsti ++ vstIndex).asSymbol;
                var vst = ~vstList[vstKey];
                if(vst.notNil) {
                    vst.midi.bend(vstIndex, 8192);
                };
            };

            // Play initial notes for melody1 (VSTs 0,1,2)
            3.do { |vstIndex|
                var currentNote = ~melody1[0];
                var vstKey = (\vsti ++ vstIndex).asSymbol;
                var vst = ~vstList[vstKey];

                if(vst.notNil && currentNote.notNil) {
                    ["Playing Melody 1:", vstKey, currentNote].postln;
                    vst.midi.noteOn(vstIndex, currentNote[0], 100);
                    activeNotes.add([vstIndex, currentNote[0], vst]);
                };
            };

            // Play initial notes for melody2 (VSTs 3,4,5)
            3.do { |vstIndex|
                var actualVSTIndex = vstIndex + 3;
                var currentNote = ~melody2[0];
                var vstKey = (\vsti ++ actualVSTIndex).asSymbol;
                var vst = ~vstList[vstKey];

                if(vst.notNil && currentNote.notNil) {
                    ["Playing Melody 2:", vstKey, currentNote].postln;
                    vst.midi.noteOn(actualVSTIndex, currentNote[0], 100);
                    activeNotes.add([actualVSTIndex, currentNote[0], vst]);
                };
            };

            firstRun = false;
        };

        // Wait for the duration before bend
        ~melody1[melody1Index][1].wait;

        // Melody 1 (VSTs 0,1,2)
        3.do { |vstIndex|
            var currentNote = ~melody1[melody1Index];
            var nextNote = ~melody1[(melody1Index + 1) % ~melody1.size];
            var startBend = ~lastBends[vstIndex];
            var targetBend = ~calcBendValue.value(currentNote[0], nextNote[0], startBend);
            
            ["Melody1 Synth Args:", 
                "VST:", vstIndex, 
                "Start Bend:", startBend,
                "Target Bend:", targetBend,
                "Duration:", currentNote[2],
                "Chan Index:", vstIndex
            ].postln;
            
            activeSynths.add(
                Synth(\BendEnvelope1, [
                    \start, startBend,
                    \end, targetBend,
                    \dur, currentNote[2],
                    \chanIndex, vstIndex
                ])
            );
            ~lastBends[vstIndex] = targetBend;
        };

        // Melody 2 (VSTs 3,4,5)
        3.do { |vstIndex|
            var actualVSTIndex = vstIndex + 3;
            var currentNote = ~melody2[melody2Index];
            var nextNote = ~melody2[(melody2Index + 1) % ~melody2.size];
            var targetBend = ~calcBendValue.value(currentNote[0], nextNote[0], ~lastBends[actualVSTIndex]);
            var startBend = ~lastBends[actualVSTIndex];
            
            ["Melody2 Synth Args:", 
                "VST:", actualVSTIndex, 
                "Start Bend:", startBend,
                "Target Bend:", targetBend,
                "Duration:", currentNote[2],
                "Chan Index:", actualVSTIndex
            ].postln;
            
            activeSynths.add(
                Synth(\BendEnvelope1, [
                    \start, startBend,
                    \end, targetBend,
                    \dur, currentNote[2],
                    \chanIndex, actualVSTIndex
                ])
            );
            ~lastBends[actualVSTIndex] = targetBend;
        };

        // Wait for bend completion
        [~melody1[melody1Index][2], ~melody2[melody2Index][2]].maxItem.wait;

        // Update indices
        melody1Index = (melody1Index + 1) % ~melody1.size;
        melody2Index = (melody2Index + 1) % ~melody2.size;

        // Short pause between bends
        0.1.wait;
    }
});
)

// Control commands
~dualMelodyTask.play;
~dualMelodyTask.stop;
~cleanupDualMelody.value;
//stop all notes
(
10.do { |note, index|
	var vstKey = (\vsti ++ index).asSymbol;
	var vst = ~vstList[vstKey];

	if(vst.notNil) {
		vst.midi.allNotesOff(index);  // Stop any playing notes
	};
};
)

// Cleanup function
~cleanupDualMelody = {
    ["Cleaning up..."].postln;

    // Stop the task
    ~dualMelodyTask.stop;

    // Reset all VSTs
    6.do { |index|
        var vstKey = (\vsti ++ index).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            ["Resetting VST:", vstKey].postln;
            vst.midi.bend(index, 8192);
            vst.midi.allNotesOff(index);
        };
    };
};
