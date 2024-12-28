
~veloc = 100;

~glissandoMode = false;
~glissandoNoteMode = false;

~numNotesPlaying = 0;
// Envelope control


// BendEnvelope1 defined in startup file

// ~bendSynth1 = Synth(\BendEnvelope1);

// keep track of channels
~noteToChannelMap = Array.fill(10,0);


// Setup OSCFunc to listen for trigger messages
// ~oscFunc.free
~oscFunc = OSCFunc({ |msg|
    var index = msg[2];
    var envValue = msg[3];
    var scaledValue = envValue.linlin(0, 1, 0, 16383).asInteger;

    // Only print debug every 32 messages (reduces console spam)
    if ((~messageCount ? 0) % 32 == 0) {
        postf("Bend Update - Channel: %, Value: %\n", index, scaledValue);
    };
    ~messageCount = (~messageCount ? 0) + 1;

    // Send bend to all VSTs
    ~vstList.do { |vst|
        vst.midi.bend(index.asInteger, scaledValue);
    };
}, '/tr', s.addr);

~chord = [];
~appendChords = true;
~chordList = [];

~captureNotes = [];
OSCdef(\onPlay, {
	arg msg;
	msg.postln;
	~vstList.do { |item, i| item.midi.noteOn(msg[1], msg[2], 100); };
	n.sendMsg('/keyOn', msg[1], msg[2]);
}, '/keyOnPlay');
OSCdef(\offPlay, {
	arg msg;
	~vstList.do { |item, i| item.midi.noteOff(msg[1], msg[2], 0); };
	n.sendMsg('/keyOff', msg[1], msg[2]);
}, '/keyOffPlay');
OSCdef(\onBend, {
	arg msg;
	msg[2].postln;
	~vstList.do { |item, i| item.midi.bend(msg[1].asInteger, msg[2].asInteger); };
}, '/onBend');
OSCdef(\captureNotes, {
	arg msg;
	msg.postln;
	~captureNotes = msg.drop(1).asInteger;
	("capture notes: " + ~captureNotes ).postln;
}, '/noteCapture');
OSCdef(\glissandoMode, {
	arg msg;
	msg.postln;
	if(msg[1].asInteger == 1,{ ~glissandoMode = true; "true".postln},{ ~glissandoMode = false});
}, '/glissando');

OSCdef(\glissandoNoteMode, {
	arg msg;
	msg.postln;
	if(msg[1].asInteger == 1,{ ~glissandoNoteMode = true; "true".postln},{ ~glissandoNoteMode = false});
}, '/glissandoNote');

// receive chords to bend using MPE midi
OSCFunc({ |msg|
	~morphChord1 = msg[1..];
}, '/morphChord1');

OSCFunc({ |msg|
	~morphChord2 = msg[1..];
}, '/morphChord2');

OSCFunc({ |msg|
	~morphMidi = msg[1..];
}, '/morphMidi');

~bpmOsc = OSCdef(\getBPM, {
	arg msg;
	~bpm = msg[1].asInteger;
	~bpm.postln;
}, '/setBPM', n);
