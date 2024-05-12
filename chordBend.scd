(

~waitTime = 12; // default wait time

// OSCFunc to listen for OSC messages to change the wait time
~waitFunc = OSCFunc({ |msg, time, addr, recvPort|
    ~waitTime = msg[1];
}, '/changeWaitTime');

~morphChord1 = [ 64.0, 67.0, 69.0, 72.0 ];
~chordBend = Task({
    loop {
        ~morphMidi = [ 0.rrand(16384),  0.rrand(16384),  0.rrand(16384),  0.rrand(16384) ];
        ~morphChord1.do {|note, index|
            ~noteToChannelMap[index] = index;
            // first turn the note on
            ~vsti.midi.noteOn(index, note, 100);
            0.001.wait; //this is just a minimal wait time to make sure the note is on before we bend it
            // then bend the note
            Synth(\BendEnvelope1, [ \gate, 1, \chanIndex, index, \start, 0, \end, 8192, \dur, 10 ]);
        };
		~waitTime.wait;
    }
});
)

~chordBend.play
~chordBend.stop
~vsti.midi.allNotesOff(0);
