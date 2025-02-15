// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// Clean up existing OSC functions
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

// Initialize bend tracking array
~lastBends = Array.fill(6, 8192);  // For 6 VSTs (0-5)

// Define chord progressions for two groups
~chordGroup1 = [
    // [chord_notes, duration_before_bend, bend_duration]
    [[65, 69, 72], 8.0, 1],  // E Major
    [[66, 70, 73], 8.0, 1],  // D Minor 7
];

~chordGroup2 = [
    [[53, 57, 60], 8.0, 1],  // C Major
    [[54, 58, 61], 8.0, 1],  // A Minor
];

// Helper function for bend calculation (same as original)
~calcBendValue = {|fromNote, toNote, currentBend=8192|
    var semitones = toNote - fromNote;
    var unitsPerSemitone = 682;  // 8192/12 = 682.666...
    var bendValue = currentBend + (semitones * unitsPerSemitone);
    bendValue.clip(0, 16383).asInteger;
};

// Task for dual chord progression
~dualChordTask = Task({
    var group1Index = 0, group2Index = 0;
    var activeSynths = List.new;
    var activeNotes = List.new;
    var firstRun = true;

    // Enhanced VST verification
    ["VST Status:"].postln;
    6.do { |vstIndex|
        var vstKey = (\vsti ++ vstIndex).asSymbol;
        var vst = ~vstList[vstKey];
        [
            "VST", vstIndex,
            "Key:", vstKey,
            "Available:", vst.notNil,
            "MIDI:", if(vst.notNil) { vst.midi.notNil } { false },
            "Type:", if(vst.notNil) { vst.class } { "N/A" }
        ].postln;
    };

    loop {
        if(firstRun) {
            // Reset all bends and clear any playing notes
            6.do { |vstIndex|
                var vstKey = (\vsti ++ vstIndex).asSymbol;
                var vst = ~vstList[vstKey];
                if(vst.notNil) {
                    ["Resetting VST", vstIndex].postln;
                    vst.midi.bend(vstIndex, 8192);
                    vst.midi.allNotesOff(vstIndex);
                };
            };

            // Prepare all VSTs first
            6.do { |vstIndex|
                var isGroup2 = vstIndex >= 3;
                var currentChord = if(isGroup2,
                    { ~chordGroup2[0][0][vstIndex-3] },
                    { ~chordGroup1[0][0][vstIndex] }
                );
                var vstKey = (\vsti ++ vstIndex).asSymbol;
                var vst = ~vstList[vstKey];
                var midiChannel = vstIndex;

                if(vst.notNil && vst.midi.notNil) {
                    // Reset and prepare VST
                    vst.midi.allNotesOff(midiChannel);
                    vst.midi.bend(midiChannel, 8192);
                    vst.midi.control(midiChannel, 7, 100);  // Volume
                    vst.midi.control(midiChannel, 11, 127); // Expression
                };
            };

            0.1.wait;

            // Now trigger all notes simultaneously
            ["Triggering all notes simultaneously"].postln;
            6.do { |vstIndex|
                var isGroup2 = vstIndex >= 3;
                var currentChord = if(isGroup2,
                    { ~chordGroup2[0][0][vstIndex-3] },
                    { ~chordGroup1[0][0][vstIndex] }
                );
                var vstKey = (\vsti ++ vstIndex).asSymbol;
                var vst = ~vstList[vstKey];
                var midiChannel = vstIndex;
                var groupNum = if(isGroup2, {2}, {1});

                if(vst.notNil && vst.midi.notNil && currentChord.notNil) {
                    ["Playing note on VST", vstIndex, "Channel:", midiChannel, "Note:", currentChord].postln;
                    vst.midi.noteOn(midiChannel, currentChord, 127);
                    activeNotes.add([vstIndex, currentChord, vst, midiChannel]);
                };
            };

            // Create modulation synths
            ["Creating modulation synths..."].postln;
            ~envelopeGroup1 = Synth.after(~vstList[\vsti2].synth, \postProcess, [
                \bus, 2,
                \amRate, 0.5,  // Modulation every 2 seconds
                \amDepth, 1,
                \phase, 0
            ]);

            ~envelopeGroup2 = Synth.after(~vstList[\vsti5].synth, \postProcess, [
                \bus, 4,
                \amRate, 0.5,
                \amDepth, 1,
                \phase, 0.5  // Offset phase for alternation
            ]);

            firstRun = false;
        };
    ~envelopeGroup1.set(\attack, 0.2, \release, 1.5);
    ~envelopeGroup2.set(\attack, 0.3, \release, 1.0);
        // Wait for the duration before bend
        max(~chordGroup1[group1Index][1], ~chordGroup2[group2Index][1]).wait;

        // Process Group 1 chord changes
        3.do { |vstIndex|
            var currentChord = ~chordGroup1[group1Index][0];
            var nextChord = ~chordGroup1[(group1Index + 1) % ~chordGroup1.size][0];
            var startBend = ~lastBends[vstIndex];
            var targetBend = ~calcBendValue.value(
                currentChord[vstIndex],
                nextChord[vstIndex],
                startBend
            );

            Synth(\BendEnvelope1, [
                \start, startBend,  // Add missing start parameter
                \end, targetBend,
                \dur, ~chordGroup1[group1Index][2],
                \chanIndex, vstIndex
            ]);

            ~lastBends[vstIndex] = targetBend;
        };

        // Process Group 2 chord changes
        3.do { |vstIndex|
            var actualIndex = vstIndex + 3;
            var currentChord = ~chordGroup2[group2Index][0];
            var nextChord = ~chordGroup2[(group2Index + 1) % ~chordGroup2.size][0];
            var startBend = ~lastBends[actualIndex];
            var targetBend = ~calcBendValue.value(
                currentChord[vstIndex],
                nextChord[vstIndex],
                startBend
            );

            Synth(\BendEnvelope1, [
                \start, startBend,
                \end, targetBend,
                \dur, ~chordGroup2[group2Index][2],
                \chanIndex, actualIndex
            ]);

            ~lastBends[actualIndex] = targetBend;
        };

        // Wait for bend completion
        max(~chordGroup1[group1Index][2], ~chordGroup2[group2Index][2]).wait;

        // Update indices
        group1Index = (group1Index + 1) % ~chordGroup1.size;
        group2Index = (group2Index + 1) % ~chordGroup2.size;

        // After the chord changes, trigger the envelopes
        [~envelopeGroup1, ~envelopeGroup2].do { |synth|
            synth.set(\t_trig, 1);  // Send trigger impulse
        };
    };
});
)
// Control commands
~dualChordTask.play;
~dualChordTask.stop;
(
// Cleanup function
~cleanupChords = {
    "Cleaning up dual chords...".postln;
    ~dualChordTask.stop;

    // Free modulation synths if they exist
    if(~envelopeGroup1.notNil) { ~envelopeGroup1.free };
    if(~envelopeGroup2.notNil) { ~envelopeGroup2.free };

    6.do { |index|
        var vstKey = (\vsti ++ index).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            vst.midi.allNotesOff(index);
            vst.midi.bend(index, 8192);
        };
    };
};
)
// Emergency stop
~cleanupChords.value; 