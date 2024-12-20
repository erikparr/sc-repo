(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;


// MPE OSC Listener for MIDI Control
(
// Initialize MIDIClient if not already done
MIDIClient.init;

// Global variables
~mpeChannelRange = (1..15); // MPE channels (excluding master channel 16)
~currentChannel = 1;         // Start with first MPE channel
~activeNotes = Dictionary.new; // Track active notes and their channels

// Function to get next available MPE channel
~getNextMPEChannel = {
    var channel = ~currentChannel;
    ~currentChannel = (~currentChannel + 1).wrap(1, 15);
    channel;
};



// OSC listeners
OSCdef(\mpeNoteOn, { |msg, time, addr, port|
    var note = msg[1].asInteger;
    var velocity = msg[2].asFloat;
    var channel = ~getNextMPEChannel.();

    // Store note info
    ~activeNotes[note] = channel;

    // Send note on
    ~vstList.do { |item|
        item.midi.noteOn(channel, note, velocity * 127);
    };

    ["MPE Note On:", note, "velocity:", velocity, "channel:", channel].postln;
}, '/mpe/noteOn', nil);

OSCdef(\mpeNoteOff, { |msg, time, addr, port|
    var note = msg[1].asInteger;
    var velocity = msg[2].asFloat;
    var channel = ~activeNotes[note];

    if(channel.notNil) {
        // Send note off
        ~vstList.do { |item|
            item.midi.noteOff(channel, note, velocity * 127);
        };

        // Remove from active notes
        ~activeNotes.removeAt(note);

        ["MPE Note Off:", note, "velocity:", velocity, "channel:", channel].postln;
    };
}, '/mpe/noteOff', nil);

// MPE-specific controllers
OSCdef(\mpePitchBend, { |msg, time, addr, port|
    var note = msg[1].asInteger;
    var bend = msg[2].asFloat;  // Expected range: -1.0 to 1.0
    var channel = ~activeNotes[note];

    if(channel.notNil) {
        var bendValue = (bend * 8192 + 8192).asInteger; // Convert to 14-bit MIDI range
        ~vstList.do { |item|
            item.midi.bend(channel, bendValue);
        };

        ["MPE Pitch Bend:", note, "bend:", bend, "channel:", channel].postln;
    };
}, '/mpe/pitchBend', nil);

OSCdef(\mpePressure, { |msg, time, addr, port|
    var note = msg[1].asInteger;
    var pressure = msg[2].asFloat; // Expected range: 0.0 to 1.0
    var channel = ~activeNotes[note];

    if(channel.notNil) {
        ~vstList.do { |item|
            item.midi.pressure(channel, pressure * 127);
        };

        ["MPE Pressure:", note, "pressure:", pressure, "channel:", channel].postln;
    };
}, '/mpe/pressure', nil);

OSCdef(\mpeTimbre, { |msg, time, addr, port|
    var note = msg[1].asInteger;
    var timbre = msg[2].asFloat; // Expected range: 0.0 to 1.0
    var channel = ~activeNotes[note];

    if(channel.notNil) {
        ~vstList.do { |item|
            item.midi.control(channel, 74, timbre * 127); // CC 74 is "Timbre/Brightness"
        };

        ["MPE Timbre:", note, "timbre:", timbre, "channel:", channel].postln;
    };
}, '/mpe/timbre', nil);

// Cleanup function
~cleanup = {
    // Free all notes
    ~activeNotes.keysValuesDo { |note, channel|
        ~vstList.do { |item|
            item.midi.noteOff(channel, note, 0);
        };
    };
    ~activeNotes.clear;

    // Free OSC defs
    OSCdef(\mpeNoteOn).free;
    OSCdef(\mpeNoteOff).free;
    OSCdef(\mpePitchBend).free;
    OSCdef(\mpePressure).free;
    OSCdef(\mpeTimbre).free;
};

CmdPeriod.doOnce(~cleanup);

"MPE OSC Listener ready.".postln;
"Available OSC commands:".postln;
"/mpe/noteOn [note(int), velocity(float 0-1)]".postln;
"/mpe/noteOff [note(int), velocity(float 0-1)]".postln;
"/mpe/pitchBend [note(int), bend(float -1 to 1)]".postln;
"/mpe/pressure [note(int), pressure(float 0-1)]".postln;
"/mpe/timbre [note(int), timbre(float 0-1)]".postln;
)

// Example usage from SuperCollider:
// n = NetAddr("localhost", 57120); // Local OSC address
// n.sendMsg("/mpe/noteOn", 60, 0.7);  // Note C4, velocity 0.7
// n.sendMsg("/mpe/pitchBend", 60, 0.5); // Bend C4 up by half
// n.sendMsg("/mpe/pressure", 60, 0.8);  // Add pressure
// n.sendMsg("/mpe/timbre", 60, 0.6);    // Modify timbre
// n.sendMsg("/mpe/noteOff", 60, 0.0);  // Release C4 