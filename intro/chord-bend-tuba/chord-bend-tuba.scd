// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// Clean up any existing OSC functions
~oscFunc.free;

// OSC Function for pitch bend
~logCounter = 0;

~oscFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    var vstKey = (\vsti ++ chanIndex).asSymbol;

    ~logCounter = ~logCounter + 1;
    if(~logCounter % 5 == 0) {  // Only print every 5th message
        ["OSC Debug:",
            "ReplyID:", replyID,
            "Chan:", chanIndex,
            "VST:", vstKey,
            "Bend:", bendValue
        ].postln;
    };

    // Always send the bend value, just don't print it
    if(~vstList[vstKey].notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        ~vstList[vstKey].midi.bend(chanIndex, bendValue);
    };
}, '/bend', s.addr);

// Modified bend envelope
SynthDef(\BendEnvelope1, {
    arg start = 8192, end = 8192, dur = 1, chanIndex = 0;
    var env;

    env = EnvGen.kr(
        Env.new(
            levels: [start, end],
            times: [dur],
            curve: \sin
        ),
        doneAction: 2
    );

    SendReply.kr(
        Impulse.kr(100),
        '/bend',
        [chanIndex, env],
        replyID: chanIndex  // Unique replyID for each channel
    );
}).add;
)

(
// Helper function for bend calculation
~calcBendValue = {|fromNote, toNote, currentBend=8192|
    var semitones = toNote - fromNote;
    var unitsPerSemitone = 682;  // 8192/12 = 682.666... units per semitone
    var bendOffset = semitones * unitsPerSemitone;
    var bendValue;

    // Calculate relative to current bend position
    bendValue = currentBend + bendOffset;
    bendValue = bendValue.clip(0, 16383).asInteger;

    // For debugging
    ["Bend calculation:",
        "From:", fromNote,
        "To:", toNote,
        "Semitones:", semitones,
        "Current:", currentBend,
        "Offset:", bendOffset,
        "Final:", bendValue
    ].postln;

    bendValue;
};

// Define chord pattern
~chordPattern = [
    // [note1, note2, duration before bend, bend duration]
    [70, 77, 4.0, 2],  // First chord
    [72, 82, 4.0, 2]   // Second chord
];

// Initialize the lastBends array for all VSTs
~lastBends = Array.fill(2, { 8192 });  // Initialize with center value for both VSTs

// Loop mode toggle (true = loop, false = play once)
~loopMode = false;

// Arpeggiation mode toggle (true = arpeggiate, false = play simultaneously)
~arpeggiateMode = true;

// Task for playing chord pattern
~chordPatternTask = Task({
    var patternIndex = 0;
    var activeSynths = List.new;
    var activeNotes = List.new;
    var firstRun = true;
    var currentChord, nextChord, waitTime, bendDuration, pauseTime;
    var vstKey, vst, vstIndex;
    var shouldContinue = true;  // Flag to control loop continuation
    var noteStartTimes = List.new;  // Track when each note started playing
    var noteWaitTimes = List.new;   // Track wait time for each note

    // Add VST verification
    ["VST Status:"].postln;
    2.do { |vstIndex|
        vstKey = (\vsti ++ vstIndex).asSymbol;
        ["VST", vstIndex, ":",
            "Key:", vstKey,
            "Available:", ~vstList[vstKey].notNil,
            "MIDI:", if(~vstList[vstKey].notNil) { ~vstList[vstKey].midi.notNil } { false }
        ].postln;
    };

    while { shouldContinue } {
        // Only play notes on first run
        if(firstRun) {
            // Reset all bends to center (8192) before playing new notes
            2.do { |vstIndex|
                vstKey = (\vsti ++ vstIndex).asSymbol;
                vst = ~vstList[vstKey];
                if(vst.notNil) {
                    vst.midi.bend(vstIndex, 8192);
                };
            };

            // Play initial chord
            currentChord = ~chordPattern[0];
            
            if(~arpeggiateMode) {
                // Get arpeggiation duration from slider 4 (0.1 to 2 seconds)
                var arpDuration = ~midiController.sliderValues[3].linlin(0, 127, 0.1, 2);
                ["Arpeggiating chord with duration:", arpDuration].postln;
                
                // Play notes with delay
                2.do { |vstIndex|
                    vstKey = (\vsti ++ vstIndex).asSymbol;
                    vst = ~vstList[vstKey];

                    if(vst.notNil && currentChord.notNil) {
                        // Delay each note based on its position
                        (vstIndex * arpDuration).wait;
                        
                        ["Playing Arpeggiated Note:", vstKey, currentChord[vstIndex], "Delay:", vstIndex * arpDuration].postln;
                        vst.midi.noteOn(vstIndex, currentChord[vstIndex], 100);
                        activeNotes.add([vstIndex, currentChord[vstIndex], vst]);
                        noteStartTimes.add(thisThread.seconds);  // Record when this note started
                        noteWaitTimes.add(~midiController.sliderValues[0].linlin(0, 127, 1, 8));  // Record wait time for this note
                    };
                };
            } {
                // Play all notes simultaneously
                2.do { |vstIndex|
                    vstKey = (\vsti ++ vstIndex).asSymbol;
                    vst = ~vstList[vstKey];

                    if(vst.notNil && currentChord.notNil) {
                        ["Playing Chord:", vstKey, currentChord[vstIndex]].postln;
                        vst.midi.noteOn(vstIndex, currentChord[vstIndex], 100);
                        activeNotes.add([vstIndex, currentChord[vstIndex], vst]);
                        noteStartTimes.add(thisThread.seconds);  // Record when this note started
                        noteWaitTimes.add(~midiController.sliderValues[0].linlin(0, 127, 1, 8));  // Record wait time for this note
                    };
                };
            };

            firstRun = false;
        };

        // Get current chord before updating index
        currentChord = ~chordPattern[patternIndex];

        // Update indices
        patternIndex = (patternIndex + 1) % ~chordPattern.size;

        // Check if we've reached the end of the pattern and loop mode is off
        if(patternIndex == 0 && ~loopMode.not) {
            ["Loop mode off - stopping after last chord"].postln;
            // Wait for the pause time before stopping
            pauseTime = ~midiController.sliderValues[2].linlin(0, 127, 0.1, 2);
            pauseTime.wait;
            // Stop all notes
            activeNotes.do { |noteData|
                var vstIndex, note, vst;
                #vstIndex, note, vst = noteData;
                if(vst.notNil) {
                    vst.midi.noteOff(vstIndex, note, 0);
                };
            };
            // Exit the loop
            shouldContinue = false;
        } {
            // Get next chord
            nextChord = ~chordPattern[patternIndex];

            if(~arpeggiateMode) {
                ["Starting bends with note start times:", noteStartTimes].postln;
                ["Current time:", thisThread.seconds].postln;

                2.do { |vstIndex|
                    var startBend = ~lastBends[vstIndex];
                    var targetBend = ~calcBendValue.value(
                        currentChord[vstIndex],
                        nextChord[vstIndex],
                        startBend
                    );
                    var timeSinceStart, remainingWait;

                    // Bend duration controlled by slider 2
                    bendDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.5, 4);

                    ["Arpeggiated Bend Args:",
                        "VST:", vstIndex,
                        "Start Bend:", startBend,
                        "Target Bend:", targetBend,
                        "Duration:", bendDuration,
                        "Chan Index:", vstIndex,
                        "Wait Time:", noteWaitTimes[vstIndex],
                        "Note Start Time:", noteStartTimes[vstIndex],
                        "Current Time:", thisThread.seconds
                    ].postln;

                    // Wait until this note's wait time has elapsed since it started
                    timeSinceStart = thisThread.seconds - noteStartTimes[vstIndex];
                    remainingWait = noteWaitTimes[vstIndex] - timeSinceStart;
                    ["Waiting for note", vstIndex, ":", 
                        "Time since start:", timeSinceStart,
                        "Remaining wait:", remainingWait
                    ].postln;
                    
                    if(remainingWait > 0) {
                        remainingWait.wait;
                    };

                    ["Starting bend for note", vstIndex].postln;
                    activeSynths.add(
                        Synth(\BendEnvelope1, [
                            \start, startBend,
                            \end, targetBend,
                            \dur, bendDuration,
                            \chanIndex, vstIndex
                        ])
                    );
                    ~lastBends[vstIndex] = targetBend;
                };

                // Wait for the last bend to complete
                bendDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.5, 4);
                bendDuration.wait;
            } {
                // In non-arpeggio mode, all notes bend simultaneously
                2.do { |vstIndex|
                    var startBend = ~lastBends[vstIndex];
                    var targetBend = ~calcBendValue.value(
                        currentChord[vstIndex],
                        nextChord[vstIndex],
                        startBend
                    );

                    // Bend duration controlled by slider 2
                    bendDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.5, 4);

                    ["Chord Bend Args:",
                        "VST:", vstIndex,
                        "Start Bend:", startBend,
                        "Target Bend:", targetBend,
                        "Duration:", bendDuration,
                        "Chan Index:", vstIndex
                    ].postln;

                    activeSynths.add(
                        Synth(\BendEnvelope1, [
                            \start, startBend,
                            \end, targetBend,
                            \dur, bendDuration,
                            \chanIndex, vstIndex
                        ])
                    );
                    ~lastBends[vstIndex] = targetBend;
                };

                // Wait for bend completion
                bendDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.5, 4);
                bendDuration.wait;
            };

            // Short pause between patterns (controlled by slider 3)
            pauseTime = ~midiController.sliderValues[2].linlin(0, 127, 0.1, 2);  // Map slider 3 to 0.1-2 seconds
            pauseTime.wait;
        };
    }
});
)

// Control commands
~chordPatternTask.play;
~chordPatternTask.stop;
~cleanupChordPattern.value;
~loopMode = false;

// Cleanup function
~cleanupChordPattern = {
    ["Cleaning up..."].postln;

    // Stop the task
    ~chordPatternTask.stop;

    // Reset all VSTs
    2.do { |index|
        var vstKey = (\vsti ++ index).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            ["Resetting VST:", vstKey].postln;
            vst.midi.bend(index, 8192);
            vst.midi.allNotesOff(index);
        };
    };
};
//stop all notes
(
10.do { |note, index|
	var vstKey = (\vsti ++ index).asSymbol;
	var vst = ~vstList[vstKey];

	if(vst.notNil) {
		vst.midi.allNotesOff(index);  // Stop any playing notes
	};
};
)
