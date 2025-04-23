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
	
	// Enable multi-instrument and multi-channel modes
	~midiController.setMultiInstrumentMode(true);
	~midiController.setMultiChannelMode(true);
	
	// Move VST mapping inside the AppClock block
	~midiController.startVSTMapping((
		\vsti0: [
			[0, 16, 0],  // First knob (CC 16) maps to knob index 0
			// [0, 17, 1],  // Second knob (CC 17) maps to knob index 1
			[0, 23, 3],   // bow pressure
			[0, 25, 4],   // harmonic A gain
			[0, 26, 5],   // harmonic B gain
			[0, 27, 6],   // bow pressure accent
			[0, 28, 7]   // bow position
		],
		\vsti1: [
			[0, 16, 0],  // Same mappings for second VST
			// [0, 17, 1],
			[0, 23, 3],    // bow pressure
			[0, 25, 4],   // harmonic A gain
			[0, 26, 5],   // harmonic B gain
			[0, 27, 6],   // bow pressure accent
			[0, 28, 7]   // bow position
		],
		\vsti2: [
			[0, 16, 0],  // Same mappings for third VST
			// [0, 17, 1],
			[0, 23, 3],    // bow pressure
			[0, 25, 4],   // harmonic A gain
			[0, 26, 5],   // harmonic B gain
			[0, 27, 6],   // bow pressure accent
			[0, 28, 7]   // bow position
		]
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

// Commenting out redundant note handlers since MIDIController handles this
/*
~f1 = MIDIFunc.noteOn({arg veloc, pitch, chan;
	// Find the first available channel (0,1,2)
	var outChan = 0;
	while { ~midiController.activeNotes[outChan].notNil && (outChan < 3) } {
		outChan = outChan + 1;
	};
	
	// If all channels are in use, use the first one
	if(outChan >= 3) { outChan = 0 };
	
	~bendSynth1.set(\gate, 1, \start, 0, \end, 0, \dur,0.0001);
	
	// play glissando note mode
	if (~glissandoNoteMode) {
		SystemClock.sched(~knob2Val, {
			~bendSynth1.set(\gate, 1, \start, 0, \end, 8192, \dur,~knob1Val);
		});
	};
	
	// play midi note and send osc to ethersonic
	if(~glissandoMode == true) {
		n.sendMsg('/glissOn', outChan, pitch);
	} {
		// Send to specific VST based on channel
		var vstKey = (\vsti ++ outChan).asSymbol;
		var vst = ~vstList[vstKey];
		if(vst.notNil) {
			vst.midi.noteOn(outChan, pitch, ~veloc);
			["Note On:", "Pitch:", pitch, "Channel:", outChan, "VST:", vstKey].postln;
		};
		n.sendMsg('/keyOn', outChan, pitch);
	};
	
	// Store the channel assignment for this pitch
	~midiController.activeNotes[outChan] = pitch;
	~numNotesPlaying = ~numNotesPlaying + 1;
	pitch.postln;
});

~f2 = MIDIFunc.noteOff({arg veloc, pitch, chan;
	// Find which channel this pitch was assigned to
	var outChan = 0;
	while { ~midiController.activeNotes[outChan] != pitch && (outChan < 3) } {
		outChan = outChan + 1;
	};
	
	// If we found the pitch, clear its channel assignment
	if(outChan < 3) {
		~midiController.activeNotes[outChan] = nil;
	};
	
	var vstKey = (\vsti ++ outChan).asSymbol;
	var vst = ~vstList[vstKey];
	
	if(vst.notNil) {
		vst.midi.noteOff(outChan, pitch, veloc);
		["Note Off:", "Pitch:", pitch, "Channel:", outChan, "VST:", vstKey].postln;
	};
	
	n.sendMsg('/keyOff', outChan, pitch);
	~numNotesPlaying = max(0, ~numNotesPlaying - 1);
});
*/

~f3 = MIDIFunc.cc({arg ...args;
	// n.sendMsg('/transpose', 0);
	args.postln;
}, 49); // match cc 49

~f4 = MIDIFunc.bend({ arg bendval, channel;
	var outChan = channel % 3;  // Map to our 3 channels
	var vstKey = (\vsti ++ outChan).asSymbol;
	var vst = ~vstList[vstKey];
	
	if(vst.notNil) {
		vst.midi.bend(outChan, bendval);
		["Pitch Bend:", "Channel:", outChan, "Value:", bendval, "VST:", vstKey].postln;
	}
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