	~bend1 = Bus.control;
	SynthDef(\BendEnvelope1, {
		arg start = 0, end = 1, dur = 1, chanIndex = 0;
		var env;
		env = EnvGen.kr(
			Env([start, end], [dur], \sin),
			gate: \gate.tr,
			doneAction: 2
		);
		SendTrig.kr(Impulse.kr(64), id:chanIndex, value:env);  // Send triggers at a control rate of 64 Hz
		// Out.kr(~bend1, env);
	}).add;
// ~bendSynth1 = Synth(\BendEnvelope1, \outbus, ~chordNote1);
~oscFunc.free
// Enhanced OSCFunc with reduced debugging
~oscFunc = OSCFunc({ |msg|
    var index = msg[2];
    var envValue = msg[3];
    var scaledValue = envValue.linlin(0, 1, 0, 16383).asInteger;

    // Only print debug every 32 messages (reduces console spam)
    if ((~messageCount ? 0) % 32 == 0) {
        postf("Bend Update - Channel: %, Value: %\n", index, scaledValue);
    };
    ~messageCount = (~messageCount ? 0) + 1;

    // Send bend to all VSTs
    ~vstList.do { |vst|
        vst.midi.bend(index.asInteger, scaledValue);
    };
}, '/tr', s.addr);

(
// Helper function with minimal debugging
~calcBendValue = {|fromNote, toNote|
    var semitones = toNote - fromNote;
    var bendValue = 8192 + (semitones * (8191/12));
    bendValue.clip(0, 16383).asInteger;
};

~waitTime = 12;

~chordSequence = [
    [ 60, 64, 67, 72 ],  // C major
    [ 65, 69, 72, 77 ]   // F major
];

~chordBend = Task({
    var currentChordIndex = 0;

    loop {
        var currentChord = ~chordSequence[currentChordIndex];
        var nextChord = ~chordSequence[(currentChordIndex + 1) % ~chordSequence.size];

        postf("\n=== Chord Change: % -> %\n",
            currentChord, nextChord);

        currentChord.do {|note, index|
            var bendTarget = ~calcBendValue.(note, nextChord[index]);
            var normalizedTarget = bendTarget.linlin(0, 16383, 0, 1);

            ~noteToChannelMap[index] = index;

            // Play notes through all VSTs
            ~vstList.do { |vst|
                vst.midi.noteOn(index, note, 100);
            };
            0.001.wait;

            Synth(\BendEnvelope1, [
                \gate, 1,
                \chanIndex, index,
                \start, 8192.linlin(0, 16383, 0, 1),
                \end, normalizedTarget,
                \dur, ~waitTime * 0.8
            ]);
        };

        currentChordIndex = (currentChordIndex + 1) % ~chordSequence.size;
        ~waitTime.wait;

        // Optional: turn off previous notes before next chord
        currentChord.do {|note, index|
            ~vstList.do { |vst|
                vst.midi.noteOff(index, note, 0);
            };
        };
    }
});
)

// Control commands remain the same
~chordBend.play;
~chordBend.stop;
~chordBend.reset;

// Emergency cleanup - now affects all VSTs
~vstList.do { |vst|
    (0..15).do { |chan| vst.midi.allNotesOff(chan) };
};
