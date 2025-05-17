// Chord Bend with MIDI Slider Control
// This file adds MIDI slider control to the bend and expression parameters
// using CTK and looping envelope synths

// Load setup files
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
// Initialize default parameters (will be controlled by MIDI sliders)
~bendPercents = [20, 20, 20];
~bendDurations = [10.0, 7.5, 6.0];
~exprLevels = [100, 110, 120];
~exprDurations = [1.0, 1.2, 1.4];
~numInstruments = 3; // Global definition of number of instruments

// Chord notes (can be modified by MIDI)
~startChord = [92, 92, 92]; // Default chord

// Keep track of all synths for proper cleanup
~bendSynths = Array.newClear(3);
~exprSynths = Array.newClear(3);

// Initialize log counter to prevent nil errors in OSC functions
~logCounter = 0;

// Helper function to calculate bend value from percentage
~calcBendPercent = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range (0-16383, center at 8192)
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383); // Ensure within valid range
};

// Create a CtkEvent for the chord bend with MIDI control
~chordBendCTK = CtkEvent(0.0, 1, 1, server: s);

// Debug: Print all slider values
~printSliderValues = {
    "Current slider values:".postln;
    8.do { |i|
        var val = ~midiController.getSliderValue(i);
        "Slider %: %".format(i+1, val).postln;
    };
};

// Function to update parameters from MIDI sliders
~updateParamsFromMIDI = {
    ~numInstruments = ~vstList.size; // Update based on actual VST list size
    // Debug: Print slider values occasionally
    if(~updateCounter.isNil) { ~updateCounter = 0 };
    ~updateCounter = ~updateCounter + 1;
    if(~updateCounter % 100 == 0) { ~printSliderValues.value };

    // Map sliders 1-3 to bend percentages (0-100%)
    ~bendPercents[0] = ~midiController.getSliderValue(0).linlin(0, 127, 0, 100);
    ~bendPercents[1] = ~midiController.getSliderValue(1).linlin(0, 127, 0, 100);
    ~bendPercents[2] = ~midiController.getSliderValue(2).linlin(0, 127, 0, 100);

    // Map sliders 4-6 to bend durations (0.5-15 seconds)
    ~bendDurations[0] = ~midiController.getSliderValue(3).linlin(0, 127, 0.5, 15.0);
    ~bendDurations[1] = ~midiController.getSliderValue(4).linlin(0, 127, 0.5, 15.0);
    ~bendDurations[2] = ~midiController.getSliderValue(5).linlin(0, 127, 0.5, 15.0);

    // Map slider 7 to expression levels for all channels (0-127)
    ~exprLevels[0] = ~midiController.getSliderValue(6).linlin(0, 127, 0, 127);
    ~exprLevels[1] = ~midiController.getSliderValue(6).linlin(0, 127, 0, 127);
    ~exprLevels[2] = ~midiController.getSliderValue(6).linlin(0, 127, 0, 127);

    // Map slider 8 to expression durations for all channels (0.1-5.0 seconds)
    ~exprDurations[0] = ~midiController.getSliderValue(7).linlin(0, 127, 0.1, 5.0);
    ~exprDurations[1] = ~midiController.getSliderValue(7).linlin(0, 127, 0.1, 5.0);
    ~exprDurations[2] = ~midiController.getSliderValue(7).linlin(0, 127, 0.1, 5.0);

    // Update the bend values in real-time for all active synths
    ~numInstruments.do { |i|
        if(~bendSynths[i].notNil) {
            var bendValue = ~calcBendPercent.value(~bendPercents[i]);
            ~bendSynths[i].set(\peak, bendValue);
            ~bendSynths[i].set(\peakTime, ~bendDurations[i]);
            ~bendSynths[i].set(\returnTime, ~bendDurations[i] * 0.5);
            ~bendSynths[i].set(\loopDuration, ~bendDurations[i] * 2);
        };

        if(~exprSynths[i].notNil) {
            ~exprSynths[i].set(\peak, ~exprLevels[i]);
            ~exprSynths[i].set(\attackTime, ~exprDurations[i]);
            ~exprSynths[i].set(\releaseTime, ~exprDurations[i] * 0.5);
            ~exprSynths[i].set(\loopDuration, ~exprDurations[i] * 2);
        };
    };
};

// Create a routine to continuously update parameters from MIDI
~midiUpdateRoutine = Routine({
    inf.do {
        ~updateParamsFromMIDI.value;
        0.05.wait; // Update at 20Hz
    };
});

// Define the main CTK function
~chordBendCTK.function_({ |event, group, envbus, inc, server|
    // Update parameters from MIDI before starting
    ~updateParamsFromMIDI.value;
    // Create synths for each tuba
    ~numInstruments.do { |i|
        var vstKey = ("vsti" ++ i).asSymbol;
        var vst = ~vstList[vstKey];
        var bendValue = ~calcBendPercent.value(~bendPercents[i]);
        var note = ~startChord[i];
        var bendDur = ~bendDurations[i];
        var exprLevel = ~exprLevels[i];
        var exprDur = ~exprDurations[i];

        if(vst.notNil) {
            // Send noteOn to VST
            vst.midi.noteOn(i, note, 100);

            // Free any existing synths for this channel
            if(~bendSynths[i].notNil) { ~bendSynths[i].free };
            if(~exprSynths[i].notNil) { ~exprSynths[i].free };

            // Start looping bend envelope synth with time offset for each tuba
            ~bendSynths[i] = Synth(\BendEnvelopeLoop, [
                \start, 8192,         // Center
                \peak, bendValue,     // Calculated bend
                \end, 8192,           // Return to center
                \delayTime, 0,        // No initial delay
                \peakTime, bendDur,   // Time to reach peak
                \returnTime, bendDur * 0.5,  // Time to return (half of peak time)
                \loopDuration, bendDur * 2,  // Total loop duration
                \chanIndex, i,
                \timeOffset, i * 0.5  // Stagger each tuba by 0.5 seconds
            ]);

            // Start looping expression envelope synth
            ~exprSynths[i] = Synth(\ExpressionEnvelopeLoop, [
                \start, 0,
                \peak, exprLevel,
                \end, 0,
                \delayTime, 0,
                \attackTime, exprDur,
                \releaseTime, exprDur * 0.5,
                \loopDuration, exprDur * 2,
                \chanIndex, i,
                \ccNum, 17,           // Expression control
                \timeOffset, i * 0.25 // Stagger expression slightly differently
            ]);

            ("Started tuba " ++ i ++
             " with bend: " ++ ~bendPercents[i] ++ "%, " ++
             "duration: " ++ bendDur ++ "s, " ++
             "expression: " ++ exprLevel).postln;
        } {
            ("VST not found for tuba " ++ i).postln;
        }
    };

    // Don't set next event - we'll control manually
    event.next_(nil);
});

// Function to start the performance
~startPerformance = {
    // Reset log counter to prevent OSC errors
    ~logCounter = 0;
    ~updateCounter = 0;

    // Print initial slider values
    ~printSliderValues.value;

    // Register direct MIDI slider handlers to ensure we get values
    ~sliderHandlers = 8.do { |i|
        MIDIFunc.cc({ |val, ccNum, chan, src|
            "Direct MIDI: Slider % (CC %) value: %".format(i+1, ccNum, val).postln;
        }, i);
    };

    // Start the MIDI update routine
    ~midiUpdateRoutine.reset.play;

    // Start the CTK event
    ~chordBendCTK.play;

    "Performance started with MIDI slider control.".postln;
    "Use sliders 1-3 for bend percentages".postln;
    "Use sliders 4-6 for bend durations".postln;
    "Use slider 7 for expression levels".postln;
    "Use slider 8 for expression durations".postln;
};

// Function to stop the performance
~stopPerformance = {
    var i, vstKey, vst;

    // Stop the MIDI update routine
    ~midiUpdateRoutine.stop;

    // Stop the CTK event
    ~chordBendCTK.stop;

    // Free MIDI handlers
    if(~sliderHandlers.notNil) {
        ~sliderHandlers.do { |handler| handler.free };
    };

    // Free all synths
    for(0, 2, { |i|
        // Free bend and expression synths
        if(~bendSynths[i].notNil) { ~bendSynths[i].free };
        if(~exprSynths[i].notNil) { ~exprSynths[i].free };

        // Send noteOff to all tubas
        vstKey = ("vsti" ++ i).asSymbol;
        vst = ~vstList[vstKey];
        if(vst.notNil) {
            vst.midi.noteOff(i, ~startChord[i], 0);
            vst.midi.bend(i, 8192); // Reset bend to center
        };
    });

    "Performance stopped.".postln;
};

// Emergency stop function - use this if normal stop doesn't work
~emergencyStop = {
    var i, vstKey, vst;

    // Stop all routines
    ~midiUpdateRoutine.stop;
    ~chordBendCTK.stop;

    // Free MIDI handlers
    if(~sliderHandlers.notNil) {
        ~sliderHandlers.do { |handler| handler.free };
    };

    // Free all synths on the server
    s.freeAll;

    // Reset all bend values
    for(0, 2, { |i|
        vstKey = ("vsti" ++ i).asSymbol;
        vst = ~vstList[vstKey];
        if(vst.notNil) {
            vst.midi.allNotesOff(i);
            vst.midi.bend(i, 8192); // Reset bend to center
        };
    });

    "EMERGENCY STOP: All synths freed and notes turned off.".postln;
};

// No need to set up MIDI mapping since we're using the existing MIDIController
// and we're not directly mapping sliders to VST parameters
)

// Execute these lines to start/stop the performance
~startPerformance.value;
~stopPerformance.value;

// If normal stop doesn't work, use emergency stop
// ~emergencyStop.value;

// Change chord notes if desired
// ~startChord = [80, 84, 88]; // Lower chord
