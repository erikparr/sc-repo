	SynthDef(\insert, { arg bus ;
		var input, output;
		input = In.ar(bus, 2);  // Read 2 channels from the bus
		output = VSTPlugin.ar(input, 2, id: \vsti0);  // Process through VST with 2 output channels
		ReplaceOut.ar(bus, output);  // Output 2 channels back to the bus
	}).add;

	// synthdef for creating two synths in parallel
	SynthDef(\insert2, { arg bus1, bus2;
		var sig1, sig2;
		sig1 = In.ar(bus1, 2);
		sig2 = In.ar(bus2, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);

		ReplaceOut.ar(bus1, Mix.new([sig1, sig2]));
	}).add;


	SynthDef(\insert3, { arg bus;
		var sig1, sig2, sig3;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);

		// Output to ADAT channels as defined in Babyface Pro manual
		ReplaceOut.ar(2, sig1);  // ADAT 3/4
		ReplaceOut.ar(4, sig2);  // ADAT 5/6
		ReplaceOut.ar(6, sig3);  // ADAT 7/8
	}).add;


	SynthDef(\insertStrings4, { arg bus;
		var sig1, sig2, sig3, sig4;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig4 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);
		sig4 = VSTPlugin.ar(sig4, 2, id: \vsti3);

		// Output to ADAT channels as defined in Babyface Pro manual
		ReplaceOut.ar(2, sig1);  // ADAT 3/4
		ReplaceOut.ar(2, sig2);  // ADAT 5/6
		ReplaceOut.ar(4, sig3);  // ADAT 7/8
		ReplaceOut.ar(4, sig4);  // ADAT 7/8
	}).add;

	SynthDef(\insertStrings, { arg bus;
		var sig1, sig2, sig3, sig4, sig5, sig6;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig4 = In.ar(bus, 2);
		sig5 = In.ar(bus, 2);
		sig6 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);
		sig4 = VSTPlugin.ar(sig4, 2, id: \vsti3);
		sig5 = VSTPlugin.ar(sig5, 2, id: \vsti4);
		sig6 = VSTPlugin.ar(sig6, 2, id: \vsti5);
		// Output to ADAT channels as defined in Babyface Pro manual
		ReplaceOut.ar(2, Mix.new([sig1, sig4]));  // ADAT 3/4
		ReplaceOut.ar(4, Mix.new([sig2, sig5]));  // ADAT 5/6
		ReplaceOut.ar(6, Mix.new([sig3, sig6]));  // ADAT 7/8
	}).add;

	SynthDef(\singleVST, { arg bus, sig;
			sig = In.ar(bus, 2);
			sig = VSTPlugin.ar(sig, 2, id: \vsti0);
		ReplaceOut.ar(bus,sig);
	}).add;

	SynthDef(\doubleVST, { arg bus, sig, sig2;
			sig = In.ar(bus, 2);
			sig = VSTPlugin.ar(sig, 2, id: \vsti0);
			sig2 = In.ar(bus, 2);
			sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
			ReplaceOut.ar(2, sig);
			ReplaceOut.ar(4, sig2);
	}).add;


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

// CC control envelopes
	SynthDef(\ccEnvelopeLoop, {
		arg start = 0, mid1 = 0.5, mid2 = 0.5, end = 1, dur = 1, chanIndex = 0;
		var env;
		env = EnvGen.kr(
			Env([start,mid1,mid2, end], [dur*0.3333, dur*0.3333, dur*0.3334], \lin),
			gate: Trig.kr(Impulse.kr(1), dur),
			doneAction: 0
		);
		SendTrig.kr(Impulse.kr(64), id:chanIndex, value:env);  // Send triggers at a control rate of 64 Hz
		// Out.kr(~bend1, env);
	}).add;























