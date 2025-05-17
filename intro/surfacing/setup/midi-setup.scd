// MIDI setup with VST mapping
AppClock.sched(0, {
	~environmentUI = EnvironmentUI.new;
	
	// Get VST instances from VSTManager
	~midiController = MIDIController(~vstManager.getInstances, n, nil, 16, 0, true);
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