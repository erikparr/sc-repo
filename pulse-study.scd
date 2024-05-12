
~ctrl1 = Bus.control;
~vsti.map(4, ~ctrl1); // find the number of the parameter you want to control and set it to the
//~vsti.gui
// ~vsti.unmap(4); // find the number of the parameter you want to control and set it to the control // ~lfo.free;
// ~ctrl1.free;
(
SynthDef(\MacroCtrl1, {
	arg start = 0, end = 1, dur = 1;
	var env;
	env = EnvGen.kr(
		// envelopes with a gate require an extra node
		Env([start,start,end], [dur*0.01,dur*0.99], \sin),
		gate: \gate.tr,  // Responds to trigger impulses
		doneAction: Done.pauseSelf
	);
	Out.kr(~ctrl1, env);
}).add;
)

(
// increasing tempo
~burst = Task({
	var waitEnv = Env([1,0.1,1],[10,10], \sin);

	var	duration = 20;
	var notes1 = 60;
	var notes2 = 52;
	var currentNotes = notes1; // Start with the first set of notes
	var startTime = Main.elapsedTime;
	0.25.wait;
	Synth(\MacroCtrl1, [ \gate, 1, \start, 0.0, \end, 1.0, \dur, duration/2 ]);
	loop({
		var now = Main.elapsedTime - startTime;
		var waittime = waitEnv.at(now);
		~vsti.midi.noteOn(0, currentNotes, 70.rrand(100));

		if (now > duration) {
			Synth(\MacroCtrl1, [ \gate, 1, \start, 1.0, \end, 0.0, \dur, duration ]);
			now = now - duration;
			startTime = Main.elapsedTime - now;
			currentNotes = if(currentNotes == notes1) { notes2 } { notes1 };
		};
		postf(" waiting %\n ", waittime);
		waittime.wait;
		~vsti.midi.noteOff(0, currentNotes, 0);
	});
});

)
~burst.play;
~burst.stop;



(
~bpm = 418;
// increasing tempo
~burst = Task({
	var ts = TimeSignature.new(4, 4, ~bpm); // 4/4 time signature
	var waittime;
	var ctrlHi1 = 0.666;
	var ctrlLow1 = 0.0;
	var	duration = 20;
	var notes1 = 41;
	var notes2 = 48;
	var currentNotes = notes1; // Start with the first set of notes
	var startTime = Main.elapsedTime;
	0.25.wait;
	Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlLow1, \end, ctrlHi1, \dur, duration ]);
	loop({
		var now = Main.elapsedTime - startTime;
		ts.setBPM(~bpm);
		~bpm.postln;
		waittime = ts.getBeatDuration;
		~vsti.midi.noteOn(0, currentNotes, 70.rrand(100));

		if (now >= duration) {
			Synth(\MacroCtrl1, [ \gate, 1, \start, ctrlHi1, \end, ctrlLow1, \dur, duration ]);
			now = now - duration;
			startTime = Main.elapsedTime - now;
			"repeat".postln;
			// currentNotes = if(currentNotes == notes1) { notes2 } { notes1 };
		};
		postf(" waiting %\n ", waittime);
		waittime.wait;
		~vsti.midi.noteOff(0, currentNotes, 0);
	});
});
)
~burst.play;
~burst.stop;
