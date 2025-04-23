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
    var isFirstNote = msg[6].asInteger == 1;  // New parameter for first note
    var isLastNote = msg[7].asInteger == 1;   // New parameter for last note
    var velocityMultiplier = 1.0;  // Default multiplier

    // Apply note offset if mode is enabled
    if(~noteOffsetMode) {
        note = (note + ~noteOffset).clip(0, 127);  // Ensure note stays within MIDI range
        ["Applying note offset:", ~noteOffset, "Original note:", msg[2], "New note:", note].postln;
    };

    // Apply velocity multiplier based on note position if mode is enabled
    if(~velocityMultiplyMode) {
        if(isFirstNote == 1) {
            velocityMultiplier = ~melodyDict[~currentSequence[~currentMelodySetIndex]].velocityMultipliers.first;
            ["Applying first note velocity multiplier:", velocityMultiplier].postln;
        };
        if(isLastNote == 1) {
            velocityMultiplier = ~melodyDict[~currentSequence[~currentMelodySetIndex]].velocityMultipliers.last;
            ["Applying last note velocity multiplier:", velocityMultiplier].postln;
        };

        // Apply the multiplier to the velocity
        velocity = (velocity * velocityMultiplier).asInteger.clip(1, 127);
        ["Final velocity after multiplier:", velocity].postln;
    };

    ["OSC Received:", "channel:", channel, "note:", note, "vel:", velocity, "dur:", duration, "fermata:", isFermata, "first:", isFirstNote, "last:", isLastNote].postln;

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
~fermataMode = false;     // Toggle for holding the last note of each melody
~rampTempoMode = false;  // Toggle for progressively shortening note rest times
~velocityMultiplyMode = false;  // Toggle for velocity multipliers on first/last notes
~noteOffsetMode = true;  // Toggle for note offset mode
~removeLastMode = false;  // Toggle for skipping the last note in each melody
~noteOffset = -12;  // Number of semitones to offset notes by (positive = up, negative = down)
~rampTempoStartMult = 0.1;  // Start with short rests (10% of normal)
~rampTempoEndMult = 5.0;    // End with longer rests (5x normal)
~rampTempoCurve = 1.0;     // Positive curve for fast-to-slow progression
~rampTempoCurveType = \exponential;  // Curve type: \linear, \exponential, \sine, \cosine, \bell, \welch, \perlin, \step
~rampTempoMinRest = 0.125;   // Minimum rest time in seconds, to prevent too rapid notes
~currentMelodySetIndex = 0;
~currentCycle = 1;  // Track which cycle we're in
~lastFermataNote = nil;  // Track the last fermata note to release it
~fermataReleaseRest = 0.25;  // Rest time after releasing a fermata note

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
        [94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last:1    // 50% velocity for last note
    )
));
~melodyDict.put(\set1b, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78,94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set2, (
    name: "Tuba Melody I",
    patterns: [
        [89, 84, 81, 77, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set3, (
    name: "Tuba Melody I",
    patterns: [
        [90, 85, 82, 75, 90],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set4, (
    name: "Tuba Melody I",
    patterns: [
        [90, 85, 78, 73, 90],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set5, (
    name: "Tuba Melody I",
    patterns: [
        [89, 85, 82, 75, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set6, (
    name: "Tuba Melody I",
    patterns: [
        [87, 82, 78, 73, 87],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set7, (
    name: "Tuba Melody I",
    patterns: [
        [89, 82, 78, 73, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));
~melodyDict.put(\set8, (
    name: "Tuba Melody I",
    patterns: [
        [85, 82, 78, 75],
    ],
    velocityMultipliers: (
        first: 1,  // 150% velocity for first note
        last: 1    // 50% velocity for last note
    )
));

~melodyDict.put(\set9, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78,  70],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 1    // 50% velocity for last note
    )
));



~melodyDict.put(\part2a, (
    name: "Tuba Melody I",
    patterns: [
        [77, 75, 77, 89, 78, 75, 77, 78, 90, 77, 78, 94, 82, 73, 77, 89, 78],
    ],
    velocityMultipliers: (
        first: 1,  // 150% velocity for first note
        last: 1    // 50% velocity for last note
    )
));
~melodyDict.put(\part2b, (
    name: "Tuba Melody I",
    patterns: [
        [70, 85, 72, 87, 73, 89, 75, 87, 75, 85, 70, 84, 72, 82, 70, 85],
    ],
    velocityMultipliers: (
        first: 1,  // 150% velocity for first note
        last: 1    // 50% velocity for last note
    )
));



// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
	name: "Initial Cycle",
	sequence: [\set1,\set1,\set1,\set1,\set3,\set3,\set5,\set5,\set6,\set6,\set7,\set7,\set1,\set1,]
));
// Define development cycles
// ~developmentCycles.put(1, (
// 	name: "Initial Cycle",
// 	sequence: [\set9,\set9,\set9,\set9]
// ));

// ~developmentCycles.put(1, (
// 	name: "Initial Cycle",
// 	sequence: [\set8,\set8,\set8,\set8]
// ));

// ~developmentCycles.put(1, (
// 	name: "Initial Cycle",
// 	sequence: [\part2b]
// ));


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
    var effectiveMelodyLength;

    // Initialize sequence
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
    currentMelodyList = currentMelodySet.patterns;

    // Calculate effective melody length based on removeLastMode
    effectiveMelodyLength = if(~removeLastMode == true) {
        currentMelodyList[melodyIndex].size - 1
    } {
        currentMelodyList[melodyIndex].size
    };

    // Only get current note if the melody has notes left
    if(effectiveMelodyLength > 0) {
        currentNote = currentMelodyList[melodyIndex][noteIndex];
    } {
        currentNote = 60; // Default note if melody would be empty
    };

    loop({
        var noteDuration, noteRestTime, melodyRestTime, temporalAccent, baseVelocity,
            actualDuration, isLastNoteInMelody, isFermata, isFirstNote, isLastNote,
            velocityMultiplier, finalVelocity, maxDuration;

        noteDuration = ~midiController.getSliderValue(1).linlin(0, 127, 0.001, 0.3);
        noteRestTime = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
        melodyRestTime = 4.47;  // Using slider 6 for melody rest
        temporalAccent = ~midiController.getSliderValue(5).linlin(0, 127, 0.75, 2);
        baseVelocity = ~midiController.getSliderValue(3).linlin(0, 127, 11, 127);

        // Recalculate the effective melody length
        effectiveMelodyLength = if(~removeLastMode == true) {
            currentMelodyList[melodyIndex].size - 1
        } {
            currentMelodyList[melodyIndex].size
        };

        isLastNoteInMelody = (noteIndex == (effectiveMelodyLength - 1));
        isFermata = isLastNoteInMelody && ~fermataMode && ~melodyRestMode;
        isFirstNote = (noteIndex == 0);
        isLastNote = isLastNoteInMelody;
        velocityMultiplier = 1.0;
        finalVelocity = baseVelocity;

        // Check if we should skip this note (if it's the last note and removeLastMode is true)
        if((~removeLastMode == true) && (noteIndex >= effectiveMelodyLength)) {
            ["Skipping last note due to removeLastMode"].postln;
            // Advance to next pattern
            noteIndex = 0;
            repetitionCount = repetitionCount + 1;

            if(repetitionCount >= ~repetitions) {
                repetitionCount = 0;

                // Handle melody switching logic as in original code...
                if(~melodyRestMode) {
                    ["Taking a longer rest between melodies:", melodyRestTime, "seconds"].postln;
                    melodyRestTime.wait;

                    // If we have a fermata note, release it after the melody rest
                    if(~lastFermataNote.notNil) {
                        ["Releasing fermata note after melody rest:", ~lastFermataNote].postln;
                        NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);

                        // Wait for the additional fermata release rest time
                        ["Waiting for fermata release rest:", ~fermataReleaseRest, "seconds"].postln;
                        ~fermataReleaseRest.wait;

                        ~lastFermataNote = nil;
                    };
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

            // Update effective melody length with the new melody
            effectiveMelodyLength = if(~removeLastMode == true) {
                currentMelodyList[melodyIndex].size - 1
            } {
                currentMelodyList[melodyIndex].size
            };

            // Skip to next iteration without playing a note
            currentNote = currentMelodyList[melodyIndex][noteIndex];
            ts.advance;
            ts.printCurrentTime;
            noteRestTime.wait;
            if(~stop) { ~sketch.stop };
            nil.yield;
        };

        // Apply velocity multiplier if mode is enabled
        if(~velocityMultiplyMode) {
            if(isFirstNote) {
                velocityMultiplier = ~melodyDict[~currentSequence[~currentMelodySetIndex]].velocityMultipliers.at(\first);
                ["First note velocity multiplier:", velocityMultiplier].postln;
            };
            if(isLastNote) {
                velocityMultiplier = ~melodyDict[~currentSequence[~currentMelodySetIndex]].velocityMultipliers.at(\last);
                ["Last note velocity multiplier:", velocityMultiplier].postln;
            };
            finalVelocity = (baseVelocity * velocityMultiplier).asInteger.clip(1, 127);
            ["Velocity calculation:", "Base:", baseVelocity, "Multiplier:", velocityMultiplier, "Final:", finalVelocity].postln;
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
            maxDuration = noteRestTime * 0.9;
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
        ["Playing note:", currentNote, "duration:", actualDuration, "noteIndex:", noteIndex, "fermata:", isFermata, "first:", isFirstNote, "last:", isLastNote, "velocity:", finalVelocity].postln;
        NetAddr.localAddr.sendMsg('/note/on', 0, currentNote, finalVelocity, actualDuration, isFermata.asInteger, isFirstNote.asInteger, isLastNote.asInteger);

        // If this is a fermata note, store it for later release
        if(isFermata) {
            ~lastFermataNote = currentNote;
        };

        // Wait for rest time before next note
        noteRestTime.wait;

        // Advance sequence
        noteIndex = (noteIndex + 1) % (effectiveMelodyLength);

        // If we've completed the current pattern
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if(repetitionCount >= ~repetitions) {
                repetitionCount = 0;

                // If melody rest mode is enabled, wait between melodies
                if(~melodyRestMode) {
                    ["Taking a longer rest between melodies:", melodyRestTime, "seconds"].postln;
                    melodyRestTime.wait;

                    // If we have a fermata note, release it after the melody rest
                    if(~lastFermataNote.notNil) {
                        ["Releasing fermata note after melody rest:", ~lastFermataNote].postln;
                        NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);

                        // Wait for the additional fermata release rest time
                        ["Waiting for fermata release rest:", ~fermataReleaseRest, "seconds"].postln;
                        ~fermataReleaseRest.wait;

                        ~lastFermataNote = nil;
                    };
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

        // Make sure we don't try to access beyond the array bounds
        if(noteIndex < currentMelodyList[melodyIndex].size) {
            currentNote = currentMelodyList[melodyIndex][noteIndex];
        };

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
~velocityMultiplyMode = true;   // Enable velocity multiplier mode
~velocityMultiplyMode = false;  // Disable velocity multiplier mode
~noteOffsetMode = true;    // Enable note offset mode
~noteOffsetMode = false;   // Disable note offset mode
~removeLastMode = true;    // Enable skipping the last note in each melody
~removeLastMode = false;   // Disable skipping the last note in each melody
~noteOffset = 12;          // Set note offset to 12 semitones (one octave up)
~noteOffset = -12;         // Set note offset to -12 semitones (one octave down)
~noteOffset = 0;           // Reset note offset to 0
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

// Load snapshot functions
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "snapshot-functions.scd").load;

// Snapshot control commands
//Remember to load the snapshot first
~loadSnapshotsFromFile.value("surfacing-ii-snap.scd");  // Load snapshots from a file

~saveSnapshot.value("surfacing-intro-01b");  // Save current slider values as "default" snapshot
~listSnapshots.value();  // List all available snapshots
~saveSnapshotsToFile.value("surfacing-ii-snap.scd");  // Save all snapshots to a file
~loadSnapshotsFromFile.value("surfacing-ii-snap.scd");  // Load snapshots from a file
~listSnapshotFiles.value();  // List all available snapshot files
~enableProgrammedMode.value("surfacing-intro-01a");  // Enable programmed mode with "default" snapshot
~enableProgrammedMode.value("surfacing-intro-01b");  // Enable programmed mode with "default" snapshot
~disableProgrammedMode.value();  // Disable programmed mode
~getCurrentSnapshot.value();  // Get current snapshot name
~isProgrammedMode.value();  // Check if programmed mode is active