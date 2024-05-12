
~vsti1.midi.allNotesOff(0);
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
			~vsti.midi.noteOn(index, note,  ~knob4Val.linlin(0,127,0,100).asInteger);
			if(~vsti1 != nil){
				~vsti1.midi.noteOn(index, note,  ~knob4Val.linlin(0,127,0,100).asInteger);
			};
			// Then bend the note
			// Synth(\BendEnvelope1, [ \gate, 1, \chanIndex, index, \start, start, \end, end, \dur, bendDur ]);

			// Schedule noteOff after the bend is finished
			fork {
				dur.wait;
				// ~vsti.midi.noteOff(index, note,0);
			};
		};
	}
}, '/chordOn');
)



)// same idea but with Tendency

// bend a single note
~noteBendOn.free;
~noteBendOff.free;
~f1.free;
~f2.free;
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
	~vsti.midi.noteOn(chan, note, ~knob4Val.linlin(0, 127, 1, 100).asInteger);
	~vsti1.midi.noteOn(chan, note, ~knob4Val.linlin(0, 127, 1, 100).asInteger);

	// Store each Synth instance in the Dictionary with the note as the key
	~synthDict.put(note, Synth(\BendEnvelopeLoop, [ \gate, 1, \chanIndex, chan, \start, start, \end, end, \dur, bendDur ]));
	// Log output for debugging
	note.postln;
	"start: ".post; start.postln;
	"end: ".post; end.postln;
});

~noteBendOff = MIDIFunc.noteOff({ |veloc, note, chan|
	~vsti.midi.noteOff(chan, note, 0);
	~vsti1.midi.noteOff(chan, note, 0);
	// Free the Synth associated with the note and remove it from the Dictionary
	~synthDict.at(note).free;
	~synthDict.removeAt(note);
});


)
~ctrlsynth.free;
~ctrlsynth.set(\gate, 1); // alternatively, you can write a.release;
~noteBend.free// Define a SynthDef with a looping envelope
