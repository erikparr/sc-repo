~knob1Val = 0;
~knob2Val = 0;
~knob3Val = 0;
~knob4Val = 0;
~knob5Val = 0;
~knob6Val = 0;
~knob7Val = 0;
~knob8Val = 0;
~knob1Range = 0;
~knob2Range = 0;
~knob3Range = 0;
~knob4Range = 0;
~knob5Range = 0;
~knob6Range = 0;
~knob7Range = 0;
~knob8Range = 0;

// MIDI setup with VST mapping
AppClock.sched(0, {
	~environmentUI = EnvironmentUI.new;
	~midiController = MIDIController(~vstList, n, nil, 16, 0, true);
	// Toggle multi-channel mode (on by default)
	~midiController.setMultiChannelMode(false);
	// Toggle multi-instrument mode (requires multi-channel mode)
	~midiController.setMultiInstrumentMode(false);
	// Toggle velocity control via knob 7
	~midiController.setVelocityCtrlMode(true);
	// Toggle debug logging
	~midiController.setDebug(true);

	// Move VST mapping inside the AppClock block
	~midiController.startVSTMapping((
		\vsti0: [
			[0, 16, 0],  // First knob (CC 16) maps to knob index 0
			// [0, 17, 1],  // Second knob (CC 17) maps to knob index 1
			[0, 19, 2],   // melody rest time (CC 19) maps to knob index 2
			[0, 23, 3],   // bow pressure
			[0, 25, 4],   // harmonic A gain
			[0, 26, 5],   // harmonic B gain
			[0, 27, 6],   // bow pressure accent
			// [0, 17, 7]   // bow position
		],
		\vsti1: [
			[0, 16, 0],  // Same mappings for second VST
			// [0, 17, 1],
			[0, 19, 2],   // melody rest time (CC 19) maps to knob index 2
			[0, 23, 3],    // bow pressure
			[0, 25, 4],   // harmonic A gain
			[0, 26, 5],   // harmonic B gain
			[0, 27, 6],   // bow pressure accent
			// [0, 17, 7]   // bow position
		],
		\vsti2: [
			[0, 16, 0],  // Same mappings for second VST
			// [0, 17, 1],
			[0, 19, 2],   // melody rest time (CC 19) maps to knob index 2
			[0, 23, 3],    // bow pressure
			[0, 25, 4],   // harmonic A gain
			[0, 26, 5],   // harmonic B gain
			[0, 27, 6],   // bow pressure accent
			// [0, 17, 7]   // bow position
		]
		// \vsti3: [
		// 	[0, 16, 0],  // Same mappings for second VST
		// 	[0, 17, 1],
		// 	[0, 23, 3],    // bow pressure
		// 	[0, 25, 4],   // harmonic A gain
		// 	[0, 26, 5],   // harmonic B gain
		// 	[0, 27, 6],   // bow pressure accent
		// 	[0, 17, 7]   // bow position
		// ],
		// \vsti4: [
		// 	[0, 16, 0],  // Same mappings for second VST
		// 	[0, 17, 1],
		// 	[0, 23, 3],    // bow pressure
		// 	[0, 25, 4],   // harmonic A gain
		// 	[0, 26, 5],   // harmonic B gain
		// 	[0, 27, 6],   // bow pressure accent
		// 	[0, 17, 7]   // bow position
		// ],
		// \vsti5: [
		// 	[0, 16, 0],  // Same mappings for second VST
		// 	[0, 17, 1],
		// 	[0, 23, 3],    // bow pressure
		// 	[0, 25, 4],   // harmonic A gain
		// 	[0, 26, 5],   // harmonic B gain
		// 	[0, 27, 6],   // bow pressure accent
		// 	[0, 17, 7]   // bow position
		// ],
	));

	nil; // return nil to prevent rescheduling
});


// 	~controlMIDIRoutine = Routine({
// 	inf.do {
// 		if(~vstList.at(\vsti) != nil){
// 			~vstList.at(\vsti).midi.control(0, 18, ~knob1Val); // touch range = 0-127
// 			~vstList.at(\vsti).midi.control(0, 19, ~knob2Val); // touch range = 0-127
// 			~vstList.at(\vsti).midi.control(0, 16, ~knob3Val); // touch range = 0-127
// 		};
// 		0.02.wait; // Wait for 20ms (50Hz polling rate)
// 	}
// }).play;


	~knobChangeListener = MIDIFunc.cc({ |value, cc, channel|
		if (cc == 20) { // Check if the CC number matches the knob you want
			~veloc = value; // Update ~veloc with the new knob value
			("Knob value changed: " ++ ~veloc).postln; // Optional: print the updated value
		}
	}, nil, nil); // Use `nil` to match any MIDI device/channel


// ~f1 = MIDIFunc.noteOn({arg veloc, pitch, chan;
// 	// chan = 0;
// 	~bendSynth1.set(\gate, 1, \start, 0, \end, 0, \dur,0.0001);
// 	// play midi note and send osc to ethersonic, if glissando mode don't play note just glissssss
// 			~vstList.do { |item, i| item.midi.noteOn(chan, pitch, ~veloc); };
// 			// ~testfx.midi.noteOn(chan, pitch, veloc);
// 		n.sendMsg('/keyOn', chan, pitch);
// 	~numNotesPlaying = ~numNotesPlaying + 1;
// 	// display channel and pitch
// 	("Channel: " ++ chan ++ " Pitch: " ++ pitch).postln;
// });
// ~vstList.at('vsti').midi.noteOn(0,55,100);
// ~f1.free;
~f2 = MIDIFunc.noteOff({arg veloc, pitch, chan;
	var freq = pitch.midicps; // Convert MIDI note number to frequency
	chan =0;
	~vstList.do { |item, i| item.midi.noteOff(chan, pitch, veloc); };
	n.sendMsg('/keyOff', chan, pitch);
	// ~numNotesPlaying = ~numNotesPlaying - 1;
	~numNotesPlaying = 0;
});

~f3 = MIDIFunc.cc({arg ...args;
	// n.sendMsg('/transpose', 0);
	args.postln;
}, 49); // match cc 49

~f4 = MIDIFunc.bend({ arg bendval, channel;
	channel =0;
	bendval.postln;
	~vstList.do { |item, i| item.midi.bend(channel, bendval); };
});

// ~knob1 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	n.sendMsg('/knob1', val);
// 	~knob1Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob1Val = val;
// 	// ~knob1Val.postln;
// }, 16); // match cc 16
//
// ~knob2 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	n.sendMsg('/knob2', val);
// 	~knob2Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob2Val = val;
// }, 17); // match cc 17
//
// ~knob3 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	n.sendMsg('/knob3', val);
// 	~knob3Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob3Val = val;
// }, 18); // match cc 18
// ~knob4 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	~knob4Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob4Val = val;
// 	n.sendMsg('/knob4', val);
//
// }, 19); // match cc 19
// ~knob5 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	~knob5Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob5Val = val;
// 	n.sendMsg('/knob5', val);
//
// }, 20); // match cc 20
// ~knob6 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	~knob6Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob6Val = val;
// 	n.sendMsg('/knob6', val);
//
// }, 21); // match cc 21
// ~knob7 = MIDIFunc.cc({|val, ccNum, chan, src|
// 	~knob7Range = val.linlin(0, 127, 0.0, 1.0);
// 	~knob7Val = val;
// 	n.sendMsg('/knob7', val);
// 	~veloc = ~knob7Val
// }, 22); // match cc 22

~bt1 = MIDIFunc.cc({|val, ccNum, chan, src|
	~vstList.do { |item, i|
		5.do{arg i;
			item.midi.allNotesOff(i);
		};
	};
}, 48); // match cc 23
(
// Free existing handlers
~nextChordButton.free;
~prevChordButton.free;

// Add MIDI button handlers for sequence navigation using Note messages
~nextChordButton = MIDIFunc.noteOn({ |vel, note, chan|
    ["Next button pressed:",
     "Note:", note,
     "Velocity:", vel,
     "Channel:", chan,
     "Procedural Mode:", ~proceduralMode,
     "Current Index:", ~currentChordSetIndex,
     "Current Sequence:", ~currentSequence,
     "Chord Dict:", ~chordDict.notNil
    ].postln;

    if(~proceduralMode.not) {
        // Advance to next chord in sequence
        ~currentChordSetIndex = (~currentChordSetIndex + 1) % ~currentSequence.size;
        ~currentChordList = ~chordDict[~currentSequence[~currentChordSetIndex]].patterns;
        ["Moving to next chord set:", ~chordDict[~currentSequence[~currentChordSetIndex]].name].postln;

        // If we've completed the sequence, advance cycle
        if(~currentChordSetIndex == 0) {
            ~advanceCycle.value;
            ~currentSequence = ~developmentCycles[~currentCycle].sequence;
        };
    };
}, 99, nil);  // Note number 99, any channel

~prevChordButton = MIDIFunc.noteOn({ |vel, note, chan|
    ["Prev button pressed:",
     "Note:", note,
     "Velocity:", vel,
     "Channel:", chan,
     "Procedural Mode:", ~proceduralMode,
     "Current Index:", ~currentChordSetIndex,
     "Current Sequence:", ~currentSequence,
     "Chord Dict:", ~chordDict.notNil
    ].postln;

    if(~proceduralMode.not) {
        // Move to previous chord in sequence
        ~currentChordSetIndex = (~currentChordSetIndex - 1);
        if(~currentChordSetIndex < 0) {
            // If we're at the start, go to previous cycle
            if(~currentCycle > 1) {
                ~switchCycle.value(~currentCycle - 1);
            };
            ~currentChordSetIndex = ~currentSequence.size - 1;
        };
        ~currentChordList = ~chordDict[~currentSequence[~currentChordSetIndex]].patterns;

        // Update the currentChordList in the sketch Task
        ~sketch.set(\currentChordList, ~currentChordList);

        ["Moving to previous chord set:", ~chordDict[~currentSequence[~currentChordSetIndex]].name].postln;
    };
}, 98, nil);  // Note number 98, any channel

)