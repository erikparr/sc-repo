(
// Initialize MIDI
MIDIClient.init;
MIDIIn.connectAll;

// Debug function
~debug = { |msg|
    ("DEBUG:" + thisThread.seconds.round(0.001) + msg).postln;
};

// Print available MIDI devices
"MIDI Sources:".postln;
MIDIClient.sources.do({ |src| src.postln });
"MIDI Destinations:".postln;
MIDIClient.destinations.do({ |dst| dst.postln });

// MIDI note-on response
~midiResponder = MIDIFunc.noteOn({ |vel, num, chan, src|
    var mappedNotes, vstKey;  // Declare all variables at start
    
    ~debug.value("MIDI Input - Note:" + num + "Vel:" + vel + "Chan:" + chan);
    
    // Get mapped notes
    mappedNotes = ~noteMapper.getOutputNotes(num);
    ~debug.value("Mapped notes:" + mappedNotes);
    
    // Check VST list
    ~debug.value("VST List status:" + ~vstList.notNil + "Size:" + ~vstList.size);
    
    // Try to play note
    try {
        ~vstList.at(\vsti0).midi.noteOn(chan, num, vel);
        ~debug.value("Sent note to VST0");
    } { |error|
        ~debug.value("Error playing note:" + error);
    };
    
    // Handle mapped notes
    if(mappedNotes.notNil) {
        mappedNotes.do({ |note, i|
            try {
                vstKey = ('vsti' ++ (i+1)).asSymbol;
                ~debug.value("Trying VST:" + vstKey);
                ~vstList.at(vstKey).midi.noteOn(chan, note, vel);
                ~debug.value("Sent note" + note + "to" + vstKey);
            } { |error|
                ~debug.value("Error with mapped note:" + error);
            };
        });
    };
});

// MIDI note-off response
~midiOffResponder = MIDIFunc.noteOff({ |vel, num, chan, src|
    var mappedNotes, vstKey;  // Declare variables
    
    ~debug.value("MIDI Off - Note:" + num);
    
    // Get mapped notes
    mappedNotes = ~noteMapper.getOutputNotes(num);
    
    // Release input note
    try {
        ~vstList.at(\vsti0).midi.noteOff(chan, num, vel);
        ~debug.value("Released note from VST0");
    } { |error|
        ~debug.value("Error releasing note:" + error);
    };
    
    // Release mapped notes if they exist
    if(mappedNotes.notNil) {
        mappedNotes.do({ |note, i|
            try {
                vstKey = ('vsti' ++ (i+1)).asSymbol;
                ~vstList.at(vstKey).midi.noteOff(chan, note, vel);
                ~debug.value("Released note" + note + "from" + vstKey);
            } { |error|
                ~debug.value("Error releasing mapped note:" + error);
            };
        });
    };
});

// MIDI CC responder for controllers
~midiCCResponder = CCResponder({ |src, chan, num, value|
    ["CC:", num, "Value:", value].postln;
});

// Add test function
~testMIDIFlow = {
    var testNote = 60;  // Declare at start
    ~debug.value("Starting MIDI flow test");
    ~debug.value("VST List contents:" + ~vstList);
    
    ~debug.value("Sending test note:" + testNote);
    ~midiResponder.value(100, testNote, 0, 0);
};

("MIDI setup completed. Run ~testMIDIFlow.value to test.").postln;
) 