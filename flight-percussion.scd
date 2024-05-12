
~f1 = MIDIFunc.noteOn({arg veloc, pitch, chan;
	chan = 0;
	~vstList.do { |item, i| item.midi.noteOn(chan, pitch, ~knob2Val); };
	n.sendMsg('/keyOn', chan, pitch);
	~numNotesPlaying = ~numNotesPlaying + 1;
	pitch.postln;
});
~f2 = MIDIFunc.noteOff({arg veloc, pitch, chan;
	var freq = pitch.midicps; // Convert MIDI note number to frequency
	chan =0;
	~vstList.do { |item, i| item.midi.noteOff(chan, pitch, ~knob2Val); };
	n.sendMsg('/keyOff', chan, pitch);
	// ~numNotesPlaying = ~numNotesPlaying - 1;
	~numNotesPlaying = 0;
});
~f1.free;
~f2.free;


/* ACCENDING ARPEGGIA */
(
~bpm = 298;
~stop = false;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[63,67], [58]];
	var chordList1 = [[61,66], [58]];
	/*ASCENDING ARPEGGIA*/
	var arpeg1 = [ [[54,61], [51]], [[54, 58], [49]],  [[58,61], [51]]];
	var arpeg2 = [ [[63,58], [54]], [[58, 61], [54]],  [[61,66], [54]]];
	var arpeg3 = [ [[66,70], [58]], [[63, 66], [54]],  [[61,70], [58]]];
	var arpeg4 = [ [[70,73], [63]], [[66, 70], [61]],  [[70,75], [63]]];
	var arpeg5 = [ [[70,75], [66]], [[73, 75], [66]],  [[75,78], [66]]];
	var arpeg6 = [ [[75,78], [70]], [[78,82], [66]],  [[70,78], [66]]];
	var arpeg7 = [ [[78,85], [73]], [[82,87], [78]],  [[82,87], [78]]];
	var arpegList = [arpeg1, arpeg2, arpeg3, arpeg4, arpeg5, arpeg6, arpeg7];
	var nextArpegSet = arpeg1;
	var nextChordsSet = nextArpegSet[0];
	var currentNotes = nextChordsSet[0];
	/*time*/
	var bpmOffset = Env([-200, 0, -200],[7, 7], \sin);
	var	duration = 20;
	var barIndex = 1;
	var beatIndex = 1;
	var measureIndex = 1;
	var noteIndex = 0;
	var chordIndex = 0;
	var arpegIndex = 0;
	var startTime = Main.elapsedTime;
	~stop = false;
	0.25.wait;
	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlLow1, \end, ctrlHi1, \dur, duration ]);
	loop({
		var now = Main.elapsedTime - startTime;
		var bpm = ~knob1Val.linlin(0, 127, 200, 800); // + bpmOffset.at(now);
		ts.setBPM(bpm);
		// (bpm).postln;
		waittime = ts.getBeatDuration;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOn(0, note, ~knob2Val); };
			note.post; " ".post;
		};
		"".postln;
		// if (now >= duration) {
		// 	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlHi1, \end, ctrlLow1, \dur, duration ]);
		// 	now = now - duration;
		// 	startTime = Main.elapsedTime - now;
		// 	//switch chords
		// 	nextChordsSet = if(nextChordsSet == chordList1) { chordList } { chordList1 };
		// 	"repeat".postln;
		// 	// currentNotes = if(currentNotes == notes1) { notes2 } { notes1 };
		// };



		postf(" waiting %\n ", waittime);
		waittime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%2;
		currentNotes = nextChordsSet[noteIndex];
		postf(" nextChordsSet index: %\n ", noteIndex);

		if(ts.measure != measureIndex){
			chordIndex = (chordIndex+1)%nextArpegSet.size;
			nextChordsSet = nextArpegSet[chordIndex];
		};
		postf(" nextArpegSet index: %\n ", chordIndex);

		if(ts.bar != barIndex){
			arpegIndex = (arpegIndex+1)%arpegList.size;
			nextArpegSet = arpegList[arpegIndex];
		};
		postf(" arpegList index: %\n ", arpegIndex);

		beatIndex = ts.beat;
		measureIndex = ts.measure;
		barIndex = ts.bar;

		ts.advance;


		// currentNotes = if(currentNotes == nextChordsSet[0]) { nextChordsSet[1] } { nextChordsSet[0] };
		if(~stop == true){
			~burst.stop;
		};
	});
});
)
~burst.play;
~stop = true;
~burst.stop;
~stop = false;


/*TRILL RHYTHMIC PART*/
/* ACCENDING ARPEGGIA */
(
~bpm = 298;
~stop = false;
~chordIndex = 0;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[70,65], [63]];
	var chordList1 = [[66,70], [61]];
	var arpegList = [chordList, chordList1];
	var nextChordsSet = chordList;
	var currentNotes = nextChordsSet[0];
	/*time*/
	var bpmOffset = Env([-200, 0, -200],[7, 7], \sin);
	var	duration = 20;
	var barIndex = 1;
	var beatIndex = 1;
	var measureIndex = 1;
	var noteIndex = 0;
	var chordIndex = 0;
	var arpegIndex = 0;
	var startTime = Main.elapsedTime;
	~stop = false;
	0.25.wait;
	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlLow1, \end, ctrlHi1, \dur, duration ]);
	loop({
		var now = Main.elapsedTime - startTime;
		var bpm = ~knob1Val.linlin(0, 127, 60, 400); // + bpmOffset.at(now);
		ts.setBPM(bpm);
		// (bpm).postln;
		waittime = ts.getBeatDuration;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOn(0, note, ~knob2Val); };
			note.post; " ".post;
		};
		"".postln;
		// if (now >= duration) {
		// 	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlHi1, \end, ctrlLow1, \dur, duration ]);
		// 	now = now - duration;
		// 	startTime = Main.elapsedTime - now;
		// 	//switch chords
		// 	nextChordsSet = if(nextChordsSet == chordList1) { chordList } { chordList1 };
		// 	"repeat".postln;
		// 	// currentNotes = if(currentNotes == notes1) { notes2 } { notes1 };
		// };



		postf(" waiting %\n ", waittime);
		waittime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%2;
		currentNotes = nextChordsSet[noteIndex];
		postf(" nextChordsSet index: %\n ", noteIndex);

		// if(ts.measure != measureIndex){
		// 	chordIndex = (chordIndex+1)%nextArpegSet.size;
		// 	nextChordsSet = nextArpegSet[chordIndex];
		// };
		// postf(" nextArpegSet index: %\n ", chordIndex);

		// if(ts.bar%2 == 0){
		// 	chordIndex = (chordIndex+1)%arpegList.size;
		// 	// 	nextChordsSet = nextArpegSet[chordIndex];
		// };
		// postf(" arpegList index: %\n ", arpegIndex);

		nextChordsSet = arpegList[~chordIndex]; // control index manually
		beatIndex = ts.beat;
		measureIndex = ts.measure;
		barIndex = ts.bar;

		ts.advance;


		// currentNotes = if(currentNotes == nextChordsSet[0]) { nextChordsSet[1] } { nextChordsSet[0] };
		if(~stop == true){
			~burst.stop;
		};
	});
});
)
~burst.play;
~stop = true;
~burst.stop;
~stop = false;

// BUTTON FOR CHORD CHANGE
~bt2 = MIDIFunc.cc({|val, ccNum, chan, src|
	if(val == 0){
		~chordIndex = 0;
		"0 index".postln;
	}{
		~chordIndex = 1;
		"1 index".postln;
	};
}, 49); // match cc 23


~bt2.free;


/* CHORD BEND */


~vsti1.midi.allNotesOff(0);
~chordList.postln
~chordOn.free
~chordList = [[70,63], [66,61]]
~chordList.postln;
~chordOn.free;
// ~chordOn works with music-loader.py to receive chords from a score and play them

(
var chordBendValues;
var dur = 4;
~chordOnIndex = 0;
z = NetAddr("localhost", 57120);

// Example OSCdef setup with MIDI bend functionality
~chordOn = OSCdef(\playChord, {
	|msg, time, addr, recvPort|
	var startIndex = 0;
	var chordNotes = msg[1..]; // Extracting the MIDI notes from the message

	~chordList.at(startIndex).do { |note, index|
		// note on midi message
		~vstList.do { |item, i| item.midi.noteOn(index, note, ~knob2Val); };
	};
	~isPlaying = true;

}, '/chordOn');

~chordBend = OSCdef(\bendChord, {
    |msg, time, addr, recvPort|
    var bendDur;
    var timeVariance = dur*0.2;
    var startIndex = 0;
    var endIndex = 1;

    // Proceed if there are at least two arrays and they are of the same size
    if (~chordList.size > 1 && ~chordList.at(startIndex).size == ~chordList.at(endIndex).size) {
        chordBendValues = Array.newClear(~chordList.size);

        ~chordList.at(endIndex).do { |note, index|
            var previousNote = ~chordList.at(startIndex).at(index);
            var noteDifference = note - previousNote;
            var mappedBendValue = (noteDifference * (8192 / 12.0)).round + 8192; // Center at 8192
            var start, end;

            bendDur = dur + (0.rrand(timeVariance));
            // Debug output for detailed insights
            postf("Note: %, Previous Note: %, Note Difference: %\n", note, previousNote, noteDifference);
            postf("Initial mappedBendValue: %\n", mappedBendValue);
            mappedBendValue = mappedBendValue.clip(0, 16384);
            postf("Clipped mappedBendValue: %\n", mappedBendValue);

            if (noteDifference.abs <= 12) { // Within 1 octave
                "bend chord".postln;
                if((~chordOnIndex%2) == 0){
                    start = mappedBendValue;
                    end = 8192;
                    postf("Bending from % to 8192 (upward or less downward)\n", mappedBendValue);
                } {
                    start = 8192;
                    end = mappedBendValue;
                    postf("Bending from 8192 to % (downward or less upward)\n", mappedBendValue);
                };
            } {
                "outside range".postln;
                start = 8192; // Default to no bend if outside 1 octave or other cases
                end = 8192;
            };
                    postf("\chanIndex: % \n", index);
            // Then bend the note
            Synth(\BendEnvelope1, [ \gate, 1, \chanIndex, index, \start, start, \end, end, \dur, bendDur ]);
        };
    }
}, '/chordBend');

)

~chordOn.free;
~chordBend.free;
~chordList = [ [70,63],[66,61]]
~chordList = [ [70,66],[66,60]]
~chordList = [ [66,70],[65,70]]

// PLAY IT IN A TIMED LOOP
~bendLoop.play;
~bendLoop.stop;
(
~chordOnIndex=0;
~bendLoop = Task({
	var dur = 10;
	0.25.wait;
	z.sendMsg('/chordOn',0); // turn chord on
	2.wait;
	// Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlLow1, \end, ctrlHi1, \dur, duration ]);
	loop({
		//turn chord on once
		//loop chord bend
		z.sendMsg('/chordBend',0); // Send the constructed message
		~chordOnIndex = ~chordOnIndex + 1;
		dur.wait;
	});
});
)

~bendLoop.play;
~bendLoop.stop;

~cello1.midi.bend(1,8192);  // 0 - 16383 (14bits, the midpoint is 8192)
~cello2.midi.bend(1,8192);  // 0 - 16383 (14bits, the midpoint is 8192)
~pigments.midi.bend(1,0);
~vstList.at(\vsti).midi.bend(0, envValue);  // 0 - 16383 (14bits, the midpoint is 8192)

//activate with button
~bt3 = MIDIFunc.cc({|val, ccNum, chan, src|
	if(val == 0){
		n.sendMsg('/chordOn', ~chordList[0]);
	}{
		n.sendMsg('/chordOn', ~chordList[1]);
		"1 chordOn".postln;
	};
}, 50); // match cc 23

z = NetAddr("localhost", 57120);


)// same idea but with Tendency
