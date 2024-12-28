	SynthDef(\insert, { arg bus ;
		ReplaceOut.ar(bus, VSTPlugin.ar(In.ar(bus, 2, 2), id: \vsti));
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
		var sig;
		sig = In.ar(bus, 2);
		sig = VSTPlugin.ar(sig, 2, id: \vsti);
		sig = VSTPlugin.ar(sig, 2, id: \vstiRoute);
		ReplaceOut.ar(bus, sig);
	}).add;

	SynthDef(\insertStrings, { arg bus;
		var sig1, sig2, sig3, sig4;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig4 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);
		sig4 = VSTPlugin.ar(sig3, 2, id: \vsti3);
		ReplaceOut.ar(bus, Mix.new([sig1, sig2, sig3, sig4]));
	}).add;

	SynthDef(\singleVST, { arg bus ;
		ReplaceOut.ar(bus, VSTPlugin.ar(In.ar(bus, 2, 2), id: \vst0));
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























