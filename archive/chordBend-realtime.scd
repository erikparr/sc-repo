SynthDef(\BendEnvelopeLoop, {
	arg start = 0, end = 1, dur = 1, chanIndex = 0;
	var env;
	env = EnvGen.kr(
		Env( [start, start, end, end, start], [dur*0.4, dur*0.1, dur*0.4, dur*0.1], \sin),
		gate: Trig.kr(Impulse.kr(1), dur),
		doneAction: 0
	);
	SendTrig.kr(Impulse.kr(64), id:chanIndex, value:env);  // Send triggers at a control rate of 64 Hz
	// Out.kr(~bend1, env);
}).add;

// ~oscFunc.free
~oscFunc = OSCFunc({ |msg|
    var index = msg[2];  // 'index' from trigger ID
    var envValue = msg[3];  // 'envValue' from trigger
	// postf("envValue: %, index: %", envValue, index);

	~vstList.at(\vsti).midi.bend(index.asInteger, envValue.asInteger);  // 0 - 16383 (14bits, the midpoint is 8192)
	// ~vstList.at(\vsti1).midi.bend(index.asInteger, envValue.asInteger);  // 0 - 16383 (14bits, the midpoint is 8192)
	// ~vstList.at(\vstiRoute).midi.bend(index.asInteger, envValue);  // 0 - 16383 (14bits, the midpoint is 8192)
}, '/tr', s.addr);


~vstList.at(\vsti).midi.allNotesOff(0);
~chordList.postln
~chordOn.free
~chordList = []
~chordList.postln;

// ~chordOn works with music-loader.py to receive chords from a score and play them
(
~dur = 6;
~chordList = []; // Initialize chord list for demonstration
~appendChords = true; // Assuming we want to append chords by default
~playNotes = true; // Assuming we want to play notes by default

// Example OSCdef setup with MIDI bend functionality
~chordOn = OSCdef(\receiveChord, {
	|msg, time, addr, recvPort|
	var bendDur = ~dur/2;
	var chordNotes = msg[1..]; // Extracting the MIDI notes from the message
	var chordArray = chordNotes.collect { |byte| byte.asInteger };
	~chord = chordNotes; // Assign the notes to ~chord
	~chord.postln;

	// If ~appendChords is true, append the chord to ~chordList
	if (~appendChords) {
		~chordList = ~chordList.add(chordNotes);
		if (~chordList.size > 2) {
			"Chord list remove: %".format(~chordList.size).postln;
			~chordList.removeAt(0); // Ensure this removes the first element correctly
		};
		"Chord list updated: %".format(~chordList).postln;
		// send it back to the keyboard app to visualize
		// n.sendMsg('/chordOn', [60,61,62]);
	};

	// Proceed if there are at least two arrays and they are of the same size
	if (~chordList.size > 1 && ~chordList.at(~chordList.size-1).size == ~chordList.at(~chordList.size-2).size && ~playNotes) {
		"playing: %".format(~chordList.at(~chordList.size-1)).postln;
		~chordList.at(~chordList.size-1).do { |note, index|
			var previousNote = ~chordList.at(~chordList.size-2).at(index);
			var noteDifference = note - previousNote;
			var start, end;
			var dur = ~dur; // Duration of the bend in seconds

			// Map the note difference to MIDI bend range
			if (noteDifference.abs <= 12) { // Within 1 octave
				start = 8192 - (noteDifference * (16383 / 24.0)).round;
				end = 8192; // Assuming end is the center point for no bend
			} {
				start = 8192; // Default to no bend if outside 1 octave or other cases
				end = 8192;
			};

			// First turn the note on
			~knob4Val.linlin(0,127,0,100).postln;
			// ~vstList.at(\vsti1).midi.noteOn(index, note,  100);
			~vstList.at(\vsti).midi.noteOn(index, note, 100);
			// Then bend the note
			Synth(\BendEnvelope1, [ \gate, 1, \chanIndex, index, \start, start, \end, end, \dur, bendDur ]);

			// Schedule noteOff after the bend is finished
			fork {
				dur.wait;
				// ~vsti.midi.noteOff(index, note,0);
			};
		};
	}
}, '/chordOn');
)



)

// bend a single note
~noteBendOn.free;
~noteBendOff.free;
~f1.free;
~f2.free;
~chordOn.free
(
// Initialize a Dictionary to store synth instances
~synthDict = Dictionary.new;
~noteBendOn = MIDIFunc.noteOn({ |veloc, note, chan|
	var targetNote, noteDifference, start, end, bendDur;
	bendDur = 16;
	targetNote = note-2;
	noteDifference = note - targetNote;
	chan = 0;
	if (noteDifference.abs <= 12) { // Within 1 octave
		end = 8192 - (noteDifference * (8192 / 12.0)).asInteger;
		start = 8192; // Assuming end is the center point for no bend
	} {
		start = 8192; // Default to no bend if outside 1 octave or other cases
		end = 8192;
	};
	// ~vstList.at(\vsti1).midi.noteOn(chan, note, ~knob4Val.linlin(0, 127, 1, 100).asInteger);
	~vstList.at(\vsti).midi.noteOn(chan, note, ~knob4Val.linlin(0, 127, 1, 100).asInteger);

	// Store each Synth instance in the Dictionary with the note as the key
	~synthDict.put(note, Synth(\BendEnvelopeLoop, [ \gate, 1, \chanIndex, chan, \start, start, \end, end, \dur, bendDur ]));
	// Log output for debugging
	note.postln;
	"start: ".post; start.postln;
	"end: ".post; end.postln;
});

~noteBendOff = MIDIFunc.noteOff({ |veloc, note, chan|
	~vsti.midi.noteOff(chan, note, 0);
	// ~vsti1.midi.noteOff(chan, note, 0);
	// Free the Synth associated with the note and remove it from the Dictionary
	~synthDict.at(note).free;
	~synthDict.removeAt(note);
});


)
~ctrlsynth.free;
~ctrlsynth.set(\gate, 1); // alternatively, you can write a.release;
~noteBend.free// Define a SynthDef with a looping envelope



//test
// Initialize VST and MIDI if not already done
(
// Clear any existing chords and reset
~vstList.at(\vsti1).midi.allNotesOff(0);
~chordList = [];
~dur = 4; // Set duration for the bend

// Test function to send chord messages
~testChordBend = { |chord1, chord2|
    // Send first chord
    n.sendMsg('/chordOn', *chord1);

    // Wait a moment, then send second chord
    SystemClock.sched(0.1, {
        n.sendMsg('/chordOn', *chord2);
    });
};

// Example usage - bend from C4,E4 to G4,B4
// MIDI notes: C4=60, E4=64, G4=67, B4=71
~testChordBend.value([60,64], [67,71]);
)

// Alternative test with different notes
// Bend from D4,F4 to A4,C5
// MIDI notes: D4=62, F4=65, A4=69, C5=72
~testChordBend.value([62,65], [69,72]);

// First set up OSC communication
(
// Create NetAddr for local OSC communication
n = NetAddr("127.0.0.1", 57120); // Local host, SC's default port

// Make sure previous OSCdefs are freed
~chordOn.free;

// Set parameters
~dur = 4; // Bend duration in seconds
~chordList = []; // Initialize empty chord list
~appendChords = true;
~playNotes = true;

// Create the OSCdef to receive chords
~chordOn = OSCdef(\receiveChord, {
    |msg, time, addr, recvPort|
    var bendDur = ~dur/2;
    var chordNotes = msg[1..]; // Extract MIDI notes from message
    var chordArray = chordNotes.collect { |byte| byte.asInteger };
    ~chord = chordNotes;
    ~chord.postln;

    // Append chord to list
    if (~appendChords) {
        ~chordList = ~chordList.add(chordNotes);
        if (~chordList.size > 2) {
            ~chordList.removeAt(0);
        };
        "Chord list updated: %".format(~chordList).postln;
    };

    // Play if we have two chords
    if (~chordList.size > 1 && ~playNotes) {
        "Playing: %".format(~chordList.at(~chordList.size-1)).postln;
        ~chordList.at(~chordList.size-1).do { |note, index|
            var previousNote = ~chordList.at(~chordList.size-2).at(index);
            var noteDifference = note - previousNote;
            var start, end;

            // Map note difference to MIDI bend range
            if (noteDifference.abs <= 12) {
                start = 8192 - (noteDifference * (16383 / 24.0)).round;
                end = 8192;
            } {
                start = 8192;
                end = 8192;
            };

            // Play note and apply bend
			// ~vstList.at(\vsti1).midi.noteOn(index, note, 100);
            ~vstList.at(\vsti).midi.noteOn(index, note, 100);

            // Schedule note off
            SystemClock.sched(~dur, {
				// ~vstList.at(\vsti1).midi.noteOff(index, note, 0);
                ~vstList.at(\vsti).midi.noteOff(index, note, 0);
                nil;
            });
        };
    };
}, '/chordOn');
)

// First set up OSC communication
(
// Create NetAddr for local OSC communication
n = NetAddr("127.0.0.1", 57120); // Local host, SC's default port

// Make sure previous OSCdefs are freed
~chordOn.free;

// Set parameters
~dur = 4; // Bend duration in seconds
~chordList = []; // Initialize empty chord list
~appendChords = true;
~playNotes = true;

// Create the OSCdef to receive chords
~chordOn = OSCdef(\receiveChord, {
    |msg, time, addr, recvPort|
    var bendDur = ~dur/2;
    var chordNotes = msg[1..]; // Extract MIDI notes from message
    var chordArray = chordNotes.collect { |byte| byte.asInteger };
    ~chord = chordNotes;
    ~chord.postln;

    // Append chord to list
    if (~appendChords) {
        ~chordList = ~chordList.add(chordNotes);
        if (~chordList.size > 2) {
            ~chordList.removeAt(0);
        };
        "Chord list updated: %".format(~chordList).postln;
    };

    // Play if we have two chords
    if (~chordList.size > 1 && ~playNotes) {
        "Playing: %".format(~chordList.at(~chordList.size-1)).postln;
        ~chordList.at(~chordList.size-1).do { |note, index|
            var previousNote = ~chordList.at(~chordList.size-2).at(index);
            var noteDifference = note - previousNote;
            var start, end;

            // Map note difference to MIDI bend range
            if (noteDifference.abs <= 12) {
                start = 8192 - (noteDifference * (16383 / 24.0)).round;
                end = 8192;
            } {
                start = 8192;
                end = 8192;
            };

            // Play note and apply bend
			// ~vstList.at(\vsti1).midi.noteOn(index, note, 100);
            ~vstList.at(\vsti).midi.noteOn(index, note, 100);

            // Schedule note off
            SystemClock.sched(~dur, {
                ~vstList.at(\vsti1).midi.noteOff(index, note, 0);
				// ~vstList.at(\vsti).midi.noteOff(index, note, 0);
                nil;
            });
        };
    };
}, '/chordOn');
)

// Now test the chord bending
// First set up OSC communication
(
// Create NetAddr for local OSC communication
n = NetAddr("127.0.0.1", 57120); // Local host, SC's default port

// Make sure previous OSCdefs are freed
~chordOn.free;

// Set parameters
~dur = 4; // Bend duration in seconds
~chordList = []; // Initialize empty chord list
~appendChords = true;
~playNotes = true;

// Create the OSCdef to receive chords
~chordOn = OSCdef(\receiveChord, {
    |msg, time, addr, recvPort|
    var bendDur = ~dur/2;
    var chordNotes = msg[1..]; // Extract MIDI notes from message
    var chordArray = chordNotes.collect { |byte| byte.asInteger };
    ~chord = chordNotes;
    ~chord.postln;

    // Append chord to list
    if (~appendChords) {
        ~chordList = ~chordList.add(chordNotes);
        if (~chordList.size > 2) {
            ~chordList.removeAt(0);
        };
        "Chord list updated: %".format(~chordList).postln;
    };

    // Play if we have two chords
    if (~chordList.size > 1 && ~playNotes) {
        "Playing: %".format(~chordList.at(~chordList.size-1)).postln;
        ~chordList.at(~chordList.size-1).do { |note, index|
            var previousNote = ~chordList.at(~chordList.size-2).at(index);
            var noteDifference = note - previousNote;
            var start, end;

            // Map note difference to MIDI bend range
            if (noteDifference.abs <= 12) {
                start = 8192 - (noteDifference * (16383 / 24.0)).round;
                end = 8192;
            } {
                start = 8192;
                end = 8192;
            };

            // Play note and apply bend
            ~vstList.at(\vsti1).midi.noteOn(index, note, 100);
            ~vstList.at(\vsti).midi.noteOn(index, note, 100);

            // Schedule note off
            SystemClock.sched(~dur, {
                ~vstList.at(\vsti1).midi.noteOff(index, note, 0);
                ~vstList.at(\vsti).midi.noteOff(index, note, 0);
                nil;
            });
        };
    };
}, '/chordOn');
)





