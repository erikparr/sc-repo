(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;

(
// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;

// OSC responder for note events with debug printing
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;  // New parameter for fermata notes

    ["OSC Received:", "channel:", channel, "note:", note, "vel:", velocity, "dur:", duration, "fermata:", isFermata].postln;

    // Play the note on all VST instances
    ~vstList.do { |item, index|
        ["Playing on VST:", index].postln;
        item.midi.noteOn(index, note, velocity);

        // Schedule note release (unless it's a fermata note)
        if(isFermata.not) {
            SystemClock.sched(duration, {
                ["Releasing note:", note, "on channel:", index].postln;
                item.midi.noteOff(index, note, 0);
                nil;
            });
        };
    };
}, '/note/on');

// Add a new OSC responder for releasing fermata notes
OSCdef(\releaseFermata, { |msg, time, addr, recvPort|
    var note = msg[1].asInteger;

    ["Releasing fermata note:", note].postln;

    // Release the note on all VST instances
    ~vstList.do { |item, index|
        item.midi.noteOff(index, note, 0);
    };
}, '/note/release');

/* MELODIC PART with Individual Note Playback */
~bpm = 298;
~stop = false;
~repetitions = 1;
~melodyRestMode = true;  // Toggle for longer rests between melodies
~fermataMode = true;     // Toggle for holding the last note of each melody
~rampTempoMode = true;  // Toggle for progressively shortening note rest times
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
~melodyDict.put(\set1, (
    name: "Tuba Melody I",
    patterns: [
        [75, 78, 89],
    ]
));

~melodyDict.put(\set2, (
    name: "Tuba Melody II",
    patterns: [
        [77, 78, 84],
    ]
));

~melodyDict.put(\set3, (
    name: "Tuba Melody III",
    patterns: [
        [78, 82, 90],
    ]
));

~melodyDict.put(\set4, (
    name: "Tuba Melody IV",
    patterns: [
        [75, 78, 89],
    ]
));

~melodyDict.put(\set5, (
    name: "Tuba Melody V",
    patterns: [
        [66, 73, 90],
    ]
));

~melodyDict.put(\set6, (
    name: "Tuba Melody VI",
    patterns: [
        [66, 73, 85],
    ]
));
~melodyDict.put(\set7, (
    name: "Tuba Melody VII",
    patterns: [
        [70, 75, 92],
    ]
));
~melodyDict.put(\set8, (
    name: "Tuba Melody VIII",
    patterns: [
        [66, 73, 90],
    ]
));


~melodyDict.put(\set1a, (
    name: "Tuba Melody I A",
    patterns: [
        [70, 73, 84],
    ]
));

~melodyDict.put(\set1b, (
    name: "Tuba Melody I B",
    patterns: [
        [70, 73, 84],
    ]
));

~melodyDict.put(\set3a, (
    name: "Tuba Melody III A",
    patterns: [
        [70, 72, 73, 77, 78, 82, 84],
    ]
));

~melodyDict.put(\set3b, (
    name: "Tuba Melody III B",
    patterns: [
        [75, 77, 80, 84, 85, 87, 89],
    ]
));

~melodyDict.put(\set4a, (
    name: "Tuba Melody IV A",
    patterns: [
        [76, 79, 93, 91, 90, 85],
    ]
));





// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Initial Cycle",
    sequence: [\set1, \set2, \set3, \set4,\set1, \set2, \set3, \set4]
));
~developmentCycles.put(2, (
    name: "Bridge Cycle",
    sequence: [\set5, \set6, \set7, \set8]
));
~developmentCycles.put(3, (
    name: "Bridge Cycle",
    sequence: [\set1a, \set1b]
));
~developmentCycles.put(4, (
    name: "Bridge Cycle",
    sequence: [\set3a,\set3a, \set3b, \set3b, \set3a,\set3a, \set3b, \set3b]
));
~developmentCycles.put(5, (
    name: "Bridge Cycle",
    sequence: [\set4a, \set4a, \set4a, \set4a, \set4a, \set4a, \set4a, \set4a]
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
    var currentNote, noteIndex = 0, melodyIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;
    var currentMelodySet;
    var cycleCompletionCount = 0;

    // Initialize sequence
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
    currentMelodyList = currentMelodySet.patterns;
    currentNote = currentMelodyList[melodyIndex][noteIndex];

    loop({
        var noteDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 0.3);
        var noteRestTime = ~midiController.sliderValues[2].linlin(0, 127, 0.0001, 0.4);
        var melodyRestTime = ~midiController.sliderValues[6].linlin(0, 127, 0.5, 8.0);  // Using slider 6 for melody rest
        var temporalAccent = ~midiController.sliderValues[5].linlin(0, 127, 0.75, 2);
        var velocity = ~midiController.sliderValues[3].linlin(0, 127, 40, 127);
        var actualDuration;
        var isLastNoteInMelody = (noteIndex == (currentMelodyList[melodyIndex].size - 1));
        var isFermata = isLastNoteInMelody && ~fermataMode && ~melodyRestMode;
        var melodyLength = currentMelodyList[melodyIndex].size;

        // Apply rampTempo if enabled
        if(~rampTempoMode) {
            var normalizedPosition = noteIndex / (melodyLength - 1); // Position from 0.0 to 1.0
            var curvedPosition, rampFactor;

            // Apply selected curve type to the normalized position
            curvedPosition = ~applyCurve.value(normalizedPosition, ~rampTempoCurveType, ~rampTempoCurve);

            // Calculate the multiplier at this position
            rampFactor = ~rampTempoStartMult.blend(~rampTempoEndMult, curvedPosition);

            // Apply the multiplier to note rest time
            noteRestTime = noteRestTime * rampFactor;

            // Ensure rest time doesn't go below minimum
            noteRestTime = noteRestTime.max(~rampTempoMinRest);

            ["Ramp tempo:", "raw pos:", normalizedPosition, "curved pos:", curvedPosition,
             "curve type:", ~rampTempoCurveType, "factor:", rampFactor, "rest time:", noteRestTime].postln;
        };

        // Apply temporal accent to first note in pattern (noteIndex == 0)
        actualDuration = if(noteIndex == 0) {
            [
                "Applying accent to first note:",
                "Base Duration:", noteDuration,
                "Accent Multiplier:", temporalAccent,
                "Final Duration:", noteDuration * temporalAccent
            ].postln;
            noteDuration * temporalAccent
        } {
            noteDuration
        };

        // Ensure note duration never exceeds rest time (prevent overlapping notes)
        // For fermata notes, we don't apply this limit since they're meant to be held
        if(isFermata.not) {
            // Leave a small gap (90% of rest time) to ensure clean separation between notes
            var maxDuration = noteRestTime * 0.9;
            if(actualDuration > maxDuration) {
                ["Limiting duration to prevent overlap:", "Original:", actualDuration, "Limited:", maxDuration].postln;
                actualDuration = maxDuration;
            };
        };

        // Release any previous fermata note before playing a new one
        if(~lastFermataNote.notNil) {
            ["Releasing previous fermata note:", ~lastFermataNote].postln;
            NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
            ~lastFermataNote = nil;
        };

        // Send note event with debug info
        ["Playing note:", currentNote, "duration:", actualDuration, "noteIndex:", noteIndex, "fermata:", isFermata].postln;
        NetAddr.localAddr.sendMsg('/note/on', 0, currentNote, velocity, actualDuration, isFermata.asInteger);

        // If this is a fermata note, store it for later release
        if(isFermata) {
            ~lastFermataNote = currentNote;
        };

        // Wait for rest time before next note
        noteRestTime.wait;

        // Advance sequence
        noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

        // If we've completed the current pattern
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if(repetitionCount >= ~repetitions) {
                repetitionCount = 0;

                // If melody rest mode is enabled, wait between melodies
                if(~melodyRestMode) {
                    ["Taking a longer rest between melodies:", melodyRestTime, "seconds"].postln;
                    melodyRestTime.wait;
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
                ["New Melody Set:", currentMelodySet.name, currentMelodyList[0]].postln;
            };
        };

        currentNote = currentMelodyList[melodyIndex][noteIndex];
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
~fermataMode = true;      // Enable fermata mode
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