(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;
(
// Clean up any existing OSC functions
~oscFunc.free;
~ccFunc.free;
~rawEnvFunc.free;

// OSC Function for pitch bend with improved handling
~logCounter = 0;

~oscFunc = OSCFunc({ |msg|
    var chanIndex = msg[3].asInteger;  // First value in our array
    var bendValue = msg[4].asInteger;  // Second value in our array
    var vstIndex = chanIndex % ~vstList.size;
    var vstKey = (\vsti ++ vstIndex).asSymbol;
    var midiChannel = vstIndex;

    if(~vstList[vstKey].notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        if ((~logCounter ? 0) % 32 == 0) {
            ["Pitch Bend:", vstKey, midiChannel, bendValue].postln;
        };
        ~logCounter = (~logCounter ? 0) + 1;
        ~vstList[vstKey].midi.bend(midiChannel, bendValue);
    };
}, '/bend', s.addr);  // Listen specifically for bend messages

~ccFunc = OSCFunc({ |msg|
    var chanIndex = msg[3].asInteger;  // First value in our array
    var envValue = msg[4].asInteger;   // Second value in our array
    var vstIndex = chanIndex % ~vstList.size;
    var vstKey = (\vsti ++ vstIndex).asSymbol;
    var midiChannel = vstIndex;

    if(~vstList[vstKey].notNil) {
        ["Bow Control:", vstKey, midiChannel, envValue].postln;
        ~vstList[vstKey].midi.control(midiChannel, 18, envValue);
    };
}, '/bow', s.addr);  // Listen specifically for bow messages

// Modified bend envelope with looping support and proper gate control
SynthDef(\BendEnvelope1, {
    arg start = 8192, end = 8192, dur = 1, chanIndex = 0, loopMode = 0;
    var env, gate;

    gate = \gate.kr(1);

    env = EnvGen.kr(
        Env.new(
            levels: [start, end, start],
            times: [dur * 0.5, dur * 0.5],
            curve: \sin,
            releaseNode: 1,
            loopNode: loopMode
        ),
        gate,
        doneAction: 2
    );

    SendReply.kr(
        Impulse.kr(100),
        '/bend',
        [chanIndex, env]
    );
}).add;

// Bowing CC envelope with reduced message rate
SynthDef(\BowEnvelope, {
    arg start = 0, end = 127, dur = 1, chanIndex = 0;
    var env;
    env = EnvGen.kr(
        Env([start, end * 0.8, end * 0.6, end], [dur * 0.2, dur * 0.3, dur * 0.5], \sin),
        doneAction: 2
    );
    SendReply.kr(
        Impulse.kr(30),  // Reduce rate for bow control - still smooth but less spammy
        '/bow',
        [chanIndex, env]
    );
}).add;

// Modified bow envelope with proper gate control
SynthDef(\BowEnvelopeStroke, {
    arg start = 0, end = 127, dur = 1, chanIndex = 0, loopMode = 0;
    var env, gate;

    gate = \gate.kr(1);

    env = EnvGen.kr(
        Env.new(
            levels: [start, end, start],
            times: [dur * 0.5, dur * 0.5],
            curve: \sin,
            releaseNode: 1,
            loopNode: loopMode
        ),
        gate,
        doneAction: 2
    );

    SendReply.kr(
        Impulse.kr(30),
        '/bow',
        [chanIndex, env]
    );
}).add;
)
(
// Helper function with improved debugging
~calcBendValue = {|fromNote, toNote|
    var semitones = toNote - fromNote;
    var bendRange = 4096;  // Half of 8192 for up/down range
    var unitsPerSemitone = bendRange / 12;  // Divide range by octave
    var bendValue = 8192 + (semitones * unitsPerSemitone);

    // Clip to valid range and convert to integer
    bendValue = bendValue.clip(0, 16383).asInteger;

    // Enhanced debugging
    [
        "Bend calculation:",
        "From note:", fromNote,
        "To note:", toNote,
        "Semitones:", semitones,
        "Bend value:", bendValue,
        "Direction:", if(bendValue > 8192, "UP", if(bendValue < 8192, "DOWN", "CENTER"))
    ].postln;

    bendValue;
};

// Add a global variable to track bow direction
~bowDirection = 0;  // 0 = up bow (0->127), 1 = down bow (127->0)
// Define a richer chord sequence
~chordSequence = [
    [
        [51, 58, 51, 58],
        [54, 61, 54, 61]
    ],
    [
        [54, 61, 54, 61],
        [51, 58, 51, 58]
	]
    ];

// Test bending chords across multiple VSTs
~multiVSTBendTest = Task({
    var noteDuration = 6;
    var currentPairIndex = 0;
    var detacheMode = false;  // Enable detaché bowing
    var bendLoopMode = true; // Enable continuous bend loop
    var fullCycleTime = 10;   // Time for complete loop (there and back)
    var activeSynths = List.new;  // Keep track of all active synths

    loop {
        var startChord = ~chordSequence[currentPairIndex][0];
        var targetChord = ~chordSequence[currentPairIndex][1];
        var bendSynths = List.new;
        var bowSynths = List.new;

        // First, free any previous synths
        activeSynths.do(_.free);
        activeSynths.clear;

        ["=== Playing Chord Pair", currentPairIndex + 1, "of", ~chordSequence.size, "==="].postln;
        ["Start chord:", startChord, "-> Target chord:", targetChord].postln;
        ["Bow direction:", if(~bowDirection == 0, "UP", "DOWN")].postln;

        // Play each note on a different VST
        startChord.do { |note, index|
            var vstKey = (\vsti ++ index).asSymbol;
            var vst = ~vstList[vstKey];
            var bendTarget;
            var bowStart, bowEnd;

            if(vst.notNil) {
                // Calculate bend target for this note
                bendTarget = ~calcBendValue.value(note, targetChord[index]);

                // Determine bow direction for this note
                if(detacheMode) {
                    # bowStart, bowEnd = if(~bowDirection == 0,
                        [0, 127],  // Up bow
                        [127, 0]   // Down bow
                    );
                } {
                    # bowStart, bowEnd = [0, 127];  // Always up bow if not in detaché mode
                };

                ["VST:", vstKey, "Note:", note, "Target:", targetChord[index],
                 "Bow:", bowStart, "->", bowEnd].postln;

                // Play the note
                vst.midi.noteOn(index, note, 100);

                if(bendLoopMode) {
                    var bendSynth, bowSynth;
                    // Create looping pitch bend envelope
                    bendSynth = Synth(\BendEnvelope1, [
                        \start, 8192,
                        \end, bendTarget,
                        \dur, fullCycleTime * 0.5,
                        \chanIndex, index,
                        \loopMode, 1
                    ]);
                    activeSynths.add(bendSynth);

                    // Create continuous bow envelope
                    bowSynth = Synth(\BowEnvelopeStroke, [
                        \chanIndex, index,
                        \start, bowStart,
                        \end, bowEnd,
                        \dur, fullCycleTime,
                        \loopMode, 1
                    ]);
                    activeSynths.add(bowSynth);
                } {
                    // Original non-looping envelopes
                    bendSynths.add(
                        Synth(\BendEnvelope1, [
                            \start, 8192,
                            \end, bendTarget,
                            \dur, noteDuration * 0.9,
                            \chanIndex, index
                        ])
                    );

                    // Create bow envelope with slight delay
                    0.05.wait;
                    bowSynths.add(
                        Synth(\BowEnvelopeStroke, [
                            \chanIndex, index,
                            \start, bowStart,
                            \end, bowEnd,
                            \dur, noteDuration * 0.9
                        ])
                    );
                };
            } {
                ["VST not found:", vstKey].postln;
            };
        };

        // Wait for appropriate duration
        if(bendLoopMode) {
            fullCycleTime.wait;
        } {
            noteDuration.wait;
        };

        // Cleanup
        activeSynths.do(_.free);  // Free all synths
        activeSynths.clear;

        startChord.do { |note, index|
            var vstKey = (\vsti ++ index).asSymbol;
            var vst = ~vstList[vstKey];

            if(vst.notNil) {
                ["Cleaning up VST:", vstKey].postln;
                vst.midi.bend(index, 8192);
                vst.midi.noteOff(index, note, 0);
            };
        };

        // Toggle bow direction for next chord if in detaché mode
        if(detacheMode) {
            ~bowDirection = 1 - ~bowDirection;
        };

        // Short pause between chord pairs
        0.5.wait;

        // Move to next chord pair
        currentPairIndex = (currentPairIndex + 1) % ~chordSequence.size;
    }
});
)

// Control commands for the multi-VST test
~multiVSTBendTest.play;
~multiVSTBendTest.stop;
~multiVSTBendTest.reset;

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
// Add cleanup function
~cleanupMultiVSTBend = {
    ["Cleaning up synths..."].postln;
    ~activeSynths.do { |synth|
        synth.set(\gate, 0);  // Release the envelope
    };

    // Reset all VSTs
    ~chordSequence[0][0].size.do { |index|
        var vstKey = (\vsti ++ index).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            ["Resetting VST:", vstKey].postln;
            vst.midi.bend(index, 8192);  // Reset pitch bend to center
            vst.midi.allNotesOff(index);  // Stop any playing notes
        };
    };
};