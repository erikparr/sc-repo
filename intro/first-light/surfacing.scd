(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-tuba.scd").load;

(
// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;

// OSC responder for note events with debug printing
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var notes = msg[2..(msg.size-3)];  // Get all notes in the chord
    var velocity = msg[msg.size-2].asInteger;
    var duration = msg[msg.size-1].asFloat;
    var isFermata = msg[msg.size].asInteger == 1;

    ["OSC Received:", "channel:", channel, "notes:", notes, "vel:", velocity, "dur:", duration, "fermata:", isFermata].postln;

    // Play the chord on all VST instances
    ~vstList.do { |item, index|
        ["Playing chord on VST:", index].postln;
        // Play all notes in the chord
        notes.do { |note|
            item.midi.noteOn(index, note, velocity);
        };

        // Schedule note release (unless it's a fermata chord)
        if(isFermata.not) {
            SystemClock.sched(duration, {
                ["Releasing chord:", notes, "on channel:", index].postln;
                notes.do { |note|
                    item.midi.noteOff(index, note, 0);
                };
                nil;
            });
        };
    };
}, '/note/on');

// Add a new OSC responder for releasing fermata chords
OSCdef(\releaseFermata, { |msg, time, addr, recvPort|
    var notes = msg[1..(msg.size-1)];  // Get all notes in the chord

    ["Releasing fermata chord:", notes].postln;

    // Release all notes in the chord on all VST instances
    ~vstList.do { |item, index|
        notes.do { |note|
            item.midi.noteOff(index, note, 0);
        };
    };
}, '/note/release');

/* MELODIC PART with Individual Note Playback */
~bpm = 298;
~stop = false;
~repetitions = 1;
~melodyRestMode = true;  // Toggle for longer rests between melodies
~fermataMode = false;     // Toggle for holding the last note of each melody
~rampTempoMode = false;  // Toggle for progressively shortening note rest times
~rampTempoStartMult = 0.1;  // Start with short rests (10% of normal)
~rampTempoEndMult = 5.0;    // End with longer rests (5x normal)
~rampTempoCurve = 1.0;     // Positive curve for fast-to-slow progression
~rampTempoCurveType = \exponential;  // Curve type: \linear, \exponential, \sine, \cosine, \bell, \welch, \perlin, \step
~rampTempoMinRest = 0.125;   // Minimum rest time in seconds, to prevent too rapid notes
~currentMelodySetIndex = 0;
~currentCycle = 1;  // Track which cycle we're in
~lastFermataNote = nil;  // Track the last fermata note to release it

// Function to apply different curve types to a normalized position (0-1)
~applyCurve = { |pos, type, curveParam=(-3.0)|
    var result;

    switch(type,
        \linear, {
            result = pos;
        },
        \exponential, {
            if(curveParam == 0) {
                result = pos; // Linear when curve param is 0
            } {
                if(curveParam > 0) {
                    // Fast to slow (positive curve)
                    result = pos.pow(curveParam);
                } {
                    // Slow to fast (negative curve)
                    result = 1 - ((1 - pos).pow(curveParam.abs));
                };
            };
        },
        \sine, {
            // Sine curve: starts slow, speeds up in middle, slows at end
            result = (pos * pi).sin / 1.0;
        },
        \cosine, {
            // Cosine curve: starts fast, slows in middle, speeds up at end
            result = 1.0 - (pos * pi).cos / 1.0;
        },
        \bell, {
            // Bell curve: slow-fast-slow (gaussian-like)
            result = 1.0 - ((pos - 0.5) * 2.5).squared.neg.exp;
        },
        \welch, {
            // Welch curve: similar to sine but with different inflection
            result = if(pos < 0.5) {
                (pos * 2).sqrt / 2
            } {
                1 - ((1 - pos) * 2).sqrt / 2
            };
        },
        \perlin, {
            // Perlin noise-like: smoothly varying random-ish curve
            // This is a simplified approximation
            result = pos + (0.3 * (pos * 5).sin) + (0.15 * (pos * 11).sin);
            result = result.clip(0, 1);
        },
        \step, {
            // Step function: discrete jumps
            result = (pos * 5).floor / 4; // 5 steps
            result = result.clip(0, 1);
        },
        // Default to linear if unknown type
        { result = pos; }
    );

    result.clip(0, 1); // Ensure result is between 0 and 1
};

// Melody sets dictionary - starting with one empty template
~melodyDict = Dictionary.new;

// Add the new sequence to the melody dictionary
~melodyDict.put(\loopSet, (
    name: "Loop Sequence",
    patterns: [
        [75, 78],    // pair 1
        [84, 85],    // pair 2
        [77, 78],    // pair 3
        [85, 82],    // pair 4
        [77, 78],    // pair 5
        [78, 75]     // pair 6
    ]
));

// Add the second sequence
~melodyDict.put(\loopSet2, (
    name: "Loop Sequence 2",
    patterns: [
        [85, 84],    // pair 1
        [82, 78],    // pair 2
        [84, 81],    // pair 3
        [77, 78],    // pair 4
        [78, 82],    // pair 5
        [75, 78]     // pair 6
    ]
));

// Add the third sequence
~melodyDict.put(\loopSet3, (
    name: "Loop Sequence 3",
    patterns: [
        [87, 84],    // pair 1
        [84, 82],    // pair 2
        [82, 85],    // pair 3
        [82, 78],    // pair 4
        [84, 82],    // pair 5
        [78, 82],    // pair 6
        [77, 81]     // pair 7
    ]
));

// Add the fourth sequence
~melodyDict.put(\loopSet4, (
    name: "Loop Sequence 4",
    patterns: [
        [90, 89],    // pair 1
        [87, 85],    // pair 2
        [89, 87],    // pair 3
        [84, 85],    // pair 4
        [85, 87],    // pair 5
        [84, 82],    // pair 6
        [85, 82]     // pair 7
    ]
));

// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Loop Cycle",
    sequence: [\loopSet]
));
~developmentCycles.put(2, (
    name: "Loop Cycle 2",
    sequence: [\loopSet2]
));
~developmentCycles.put(3, (
    name: "Loop Cycle 3",
    sequence: [\loopSet3]
));
~developmentCycles.put(4, (
    name: "Loop Cycle 4",
    sequence: [\loopSet4]
));

// Helper function to switch cycles
~switchCycle = { |cycleNumber|
    if(~developmentCycles.includesKey(cycleNumber)) {
        ~currentCycle = cycleNumber;
        ~currentSequence = ~developmentCycles[cycleNumber].sequence;
        ~currentMelodySetIndex = 0;
        ["Switching to cycle:", ~developmentCycles[cycleNumber].name].postln;
        ["Sequence:", ~currentSequence.collect({ |key| ~melodyDict[key].name })].postln;
    } {
        "Invalid cycle number".postln;
    };
};

// Helper function to advance to next cycle
~advanceCycle = {
    var nextCycle = ~currentCycle + 1;
    if(~developmentCycles.includesKey(nextCycle)) {
        ~switchCycle.value(nextCycle);
        ["Advancing to cycle:", nextCycle].postln;
    } {
        ["Staying in final cycle:", ~currentCycle].postln;
    };
};

~sketch = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var currentChord, noteIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;
    var currentMelodySet;
    var cycleCompletionCount = 0;

    // Initialize sequence
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
    currentMelodyList = currentMelodySet.patterns;
    currentChord = currentMelodyList[noteIndex];  // Access the correct pair

    loop({
        var noteDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 1);
        var noteRestTime = ~midiController.sliderValues[2].linlin(0, 127, 0.0001, 1);
        var loopRestTime = ~midiController.sliderValues[6].linlin(0, 127, 1.0, 10.0);
        var temporalAccent = ~midiController.sliderValues[5].linlin(0, 127, 0.75, 2);
        var velocity = ~midiController.sliderValues[3].linlin(0, 127, 40, 127);
        var actualDuration;
        var isLastChordInMelody = (noteIndex == (currentMelodyList.size - 1));
        var isFermata = isLastChordInMelody && ~fermataMode && ~melodyRestMode;
        var melodyLength = currentMelodyList.size;

        // Debug output for slider values and initial durations
        [
            "DEBUG - Raw Slider Values:",
            "Slider 1 (Note Duration):", ~midiController.sliderValues[1], "→", noteDuration.round(0.001), "sec",
            "Slider 2 (Rest Time):", ~midiController.sliderValues[2], "→", noteRestTime.round(0.001), "sec",
            "Slider 3 (Velocity):", ~midiController.sliderValues[3], "→", velocity,
            "Slider 5 (Accent):", ~midiController.sliderValues[5], "→", temporalAccent.round(0.001),
            "Slider 6 (Loop Rest):", ~midiController.sliderValues[6], "→", loopRestTime.round(0.01), "sec"
        ].postln;

        // Apply rampTempo if enabled
        if(~rampTempoMode) {
            var normalizedPosition = noteIndex / (melodyLength - 1);
            var curvedPosition, rampFactor;
            var originalRestTime = noteRestTime;  // Moved variable declaration to the start of the block

            curvedPosition = ~applyCurve.value(normalizedPosition, ~rampTempoCurveType, ~rampTempoCurve);
            rampFactor = ~rampTempoStartMult.blend(~rampTempoEndMult, curvedPosition);

            noteRestTime = noteRestTime * rampFactor;
            noteRestTime = noteRestTime.max(~rampTempoMinRest);

            ["RAMP TEMPO - Position:", noteIndex, "Original Rest:", originalRestTime.round(0.001),
             "Factor:", rampFactor.round(0.01), "Final Rest:", noteRestTime.round(0.001)].postln;
        };

        // Apply temporal accent to first chord in pattern
        actualDuration = if(noteIndex == 0) {
            // Debug accent application
            ["ACCENT - First Note Accent:", "Base Duration:", noteDuration.round(0.001),
             "Accent:", temporalAccent.round(0.01), "Final Duration:", (noteDuration * temporalAccent).round(0.001)].postln;
            noteDuration * temporalAccent;
        } {
            noteDuration;
        };

        // Ensure note duration never exceeds rest time
        if(isFermata.not) {
            var maxDuration = noteRestTime * 0.9;
            if(actualDuration > maxDuration) {
                ["DURATION LIMIT - Original:", actualDuration.round(0.001), "Limited to:", maxDuration.round(0.001)].postln;
                actualDuration = maxDuration;
            };
        };

        // Final duration report
        ["FINAL TIMING - Note:", currentChord, "Duration:", actualDuration.round(0.001),
         "Rest:", noteRestTime.round(0.001), "Total:", (actualDuration + noteRestTime).round(0.001)].postln;

        // Release any previous fermata chord before playing a new one
        if(~lastFermataNote.notNil) {
            ~lastFermataNote.do { |note, i|
                var vstKey = (\vsti ++ i).asSymbol;
                var vst = ~vstList[vstKey];

                if(vst.notNil) {
                    ["Releasing fermata note:", note, "from VST:", vstKey].postln;
                    vst.midi.noteOff(i, note, 0);
                };
            };
            ~lastFermataNote = nil;
        };

        // Play the chord on VST instances
        ["Playing chord:", currentChord, "duration:", actualDuration, "noteIndex:", noteIndex, "fermata:", isFermata].postln;

        // Distribute notes across available VST instances
        if (currentChord.size <= ~vstList.size) {
            currentChord.do { |note, i|
                var vstKey = (\vsti ++ i).asSymbol;  // Create key like \vsti0, \vsti1, etc.
                var vst = ~vstList[vstKey];          // Get VST instance using the key

                if(vst.notNil) {
                    ["Sending noteOn for note:", note, "to VST:", vstKey].postln;
                    vst.midi.noteOn(i, note, velocity);  // Send note to the VST
                } {
                    ["VST not found for key:", vstKey].postln;
                };
            };
        } {
            "Not enough VST instances for the chord".postln;
        };

        // If this is a fermata chord, store it for later release
        if(isFermata) {
            ~lastFermataNote = currentChord;
        } {
            // Schedule note release for non-fermata chords
            SystemClock.sched(actualDuration, {
                currentChord.do { |note, i|
                    var vstKey = (\vsti ++ i).asSymbol;
                    var vst = ~vstList[vstKey];

                    if(vst.notNil) {
                        ["Releasing note:", note, "from VST:", vstKey].postln;
                        vst.midi.noteOff(i, note, 0);
                    };
                };
                nil;
            });
        };

        // Wait for rest time before next chord
        noteRestTime.wait;

        // Advance sequence
        noteIndex = (noteIndex + 1) % (currentMelodyList.size);

        // If we've completed the current pattern
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if(repetitionCount >= ~repetitions) {
                repetitionCount = 0;

                // Take a rest between loop sequences
                if(currentMelodySet.name == "Loop Sequence") {
                    loopRestTime.wait;
                };

                // If melody rest mode is enabled, wait between melodies
                if(~melodyRestMode) {
                    loopRestTime.wait;
                };

                ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~currentSequence.size;

                if(~currentMelodySetIndex == 0) {
                    cycleCompletionCount = cycleCompletionCount + 1;
                    if(cycleCompletionCount >= 2) {
                        cycleCompletionCount = 0;
                        ~advanceCycle.value;
                    };
                };

                currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
                currentMelodyList = currentMelodySet.patterns;
            };
        };

        currentChord = currentMelodyList[noteIndex];  // Access the correct pair
        ts.advance;
        ts.printCurrentTime;

        if(~stop) { ~sketch.stop };
    });
});
)

// Control commands
~sketch.play;
~repetitions = 1;  // Change number of repetitions
~stop = true;
~melodyRestMode = true;   // Enable melody rest modes
~melodyRestMode = false;  // Disable melody rest mode
~fermataMode = false;     // Disable fermata mode
~rampTempoMode = true;      // Enable ramp tempo mode
~rampTempoMode = false;     // Disable ramp tempo mode
~rampTempoStartMult = 2.0;  // Start with longer rests (2x normal)
~rampTempoEndMult = 0.1;    // End with very short rests (10% of normal)
~rampTempoCurve = -4.0;     // Curve parameter for exponential type
~rampTempoMinRest = 0.01;   // Set minimum rest time (10ms)
~rampTempoMinRest = 0.05;   // Set minimum rest time (50ms)
~rampTempoMinRest = 0.2;    // Set minimum rest time (100ms)

// Set different curve types
~rampTempoCurveType = \linear;      // Linear ramp
~rampTempoCurveType = \exponential; // Exponential curve (uses ~rampTempoCurve parameter)
/*
For Fast-to-Slow Progression: ~rampTempoCurve
Use positive values (like 3.0)
Small positive values (0.5 to 2.0): Gentle deceleration
Medium positive values (2.0 to 5.0): More pronounced slowing down
Large positive values (5.0+): Dramatic slowing at the end
*/
~switchCycle.value(1);
~switchCycle.value(2);
~switchCycle.value(3);
~switchCycle.value(4);
~switchCycle.value(5);
~switchCycle.value(6);
~sketch.play;
~stop = true;

// Stop all notes
(
10.do { |note, index|
    var vstKey = (\vsti ++ index).asSymbol;
    var vst = ~vstList[vstKey];

    if(vst.notNil) {
        vst.midi.allNotesOff(index);  // Stop any playing notes
    };
};

)