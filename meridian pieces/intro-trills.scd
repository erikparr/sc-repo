
~f1 = MIDIFunc.noteOn({arg veloc, pitch, chan;
	chan = 0;
	~vstList.do { |item, i| item.midi.noteOn(chan, pitch, ~veloc); };
	n.sendMsg('/keyOn', chan, pitch);
	~numNotesPlaying = ~numNotesPlaying + 1;
	pitch.postln;
});
~f2 = MIDIFunc.noteOff({arg veloc, pitch, chan;
	var freq = pitch.midicps; // Convert MIDI note number to frequency
	chan =0;
	~vstList.do { |item, i| item.midi.noteOff(chan, pitch, ~veloc); };
	n.sendMsg('/keyOff', chan, pitch);
	// ~numNotesPlaying = ~numNotesPlaying - 1;
	~numNotesPlaying = 0;
});
(
~f1.free;
~f2.free;
)


/*TRILL RHYTHMIC PART*/
(
~bpm = 298;
~stop = false;
~chordIndex = 0;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var resttime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[73], [69], [66]];
	var chordList1 = [[72], [69], [64]];
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
		var bpm = ~midiController.sliderValues[0].linlin(0, 127, 60, 400); // + bpmOffset.at(now);
		ts.setBPM(bpm);
		// (bpm).postln;
		resttime = 	~midiController.sliderValues[1].linlin(0, 127, 0.025, 0.35);
		waittime = 	~midiController.sliderValues[2].linlin(0, 127, 0.001, 0.25);
		if(waittime == 1.0){waittime = 10};
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOn(0, note, ~midiController.sliderValues[3].linlin(0, 127, 0, 100)); };
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
		resttime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%(nextChordsSet.size);
		currentNotes = nextChordsSet[noteIndex];
		postf(" nextChordsSet index: %\n ", noteIndex);

		if(ts.measure != measureIndex){
			// chordIndex = (chordIndex+1)%nextArpegSet.size;
			// nextChordsSet = nextArpegSet[chordIndex];
		};
		// postf(" nextArpegSet index: %\n ", chordIndex);

		if(ts.bar%2 == 0){
			chordIndex = (chordIndex+1)%arpegList.size;
			// 	nextChordsSet = nextArpegSet[chordIndex];

		};
		// postf(" arpegList index: %\n ", arpegIndex);
		waittime.wait;
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



/*TRILL RHYTHMIC PART*/
(
~bpm = 298;
~stop = false;
~chordIndex = 0;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var resttime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[73], [69], [66], [73], [76], [69]];
	var chordList1 = [[72], [69], [64]];
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
		var bpm = ~midiController.sliderValues[0].linlin(0, 127, 60, 400); // + bpmOffset.at(now);
		ts.setBPM(bpm);
		// (bpm).postln;
		resttime = 	~midiController.sliderValues[1].linlin(0, 127, 0.025, 0.35);
		waittime = 	~midiController.sliderValues[2].linlin(0, 127, 0.001, 0.25);
		if(waittime == 1.0){waittime = 10};
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOn(0, note, ~midiController.sliderValues[3].linlin(0, 127, 0, 100)); };
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
		resttime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%(nextChordsSet.size);
		currentNotes = nextChordsSet[noteIndex];
		postf(" nextChordsSet index: %\n ", noteIndex);

		if(ts.measure != measureIndex){
			// chordIndex = (chordIndex+1)%nextArpegSet.size;
			// nextChordsSet = nextArpegSet[chordIndex];
		};
		// postf(" nextArpegSet index: %\n ", chordIndex);

		if(ts.bar%2 == 0){
			chordIndex = (chordIndex+1)%arpegList.size;
			// 	nextChordsSet = nextArpegSet[chordIndex];

		};
		// postf(" arpegList index: %\n ", arpegIndex);
		waittime.wait;
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


~f1 = MIDIFunc.noteOn({arg veloc, pitch, chan;
	chan = 0;
	~vstList.do { |item, i| item.midi.noteOn(chan, pitch, ~veloc); };
	n.sendMsg('/keyOn', chan, pitch);
	~numNotesPlaying = ~numNotesPlaying + 1;
	pitch.postln;
});
~f2 = MIDIFunc.noteOff({arg veloc, pitch, chan;
	var freq = pitch.midicps; // Convert MIDI note number to frequency
	chan =0;
	~vstList.do { |item, i| item.midi.noteOff(chan, pitch, ~veloc); };
	n.sendMsg('/keyOff', chan, pitch);
	// ~numNotesPlaying = ~numNotesPlaying - 1;
	~numNotesPlaying = 0;
});
(
~f1.free;
~f2.free;
)


/*TRILL RHYTHMIC PART*/
(
~bpm = 298;
~stop = false;
~chordIndex = 0;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(2, 3, ~bpm); // 4/4 time signature
	var waittime;
	var resttime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var chordList = [[70], [65], [63]];
	var chordList1 = [[66,70], [61]];
	var arpegList = [chordList, chordList];
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
		resttime = 	~knob6Val.linlin(0, 127, 0.025, 1.0);
		waittime = 	~knob5Val.linlin(0, 127, 0.001, 1.0);
		if(waittime == 1.0){waittime = 10};
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
		resttime.wait;
		currentNotes.do { |note, index|
			~vstList.do { |item, i| item.midi.noteOff(0, note, 0); };
		};

		// iterate through arpeggi
		// first get the notes list index in the chord list
		noteIndex = (noteIndex+1)%nextChordsSet.size;
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
		waittime.wait;
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

