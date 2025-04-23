// Load the base setup first
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;

(
// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;
OSCdef(\releaseFermata).free;
OSCdef(\noteOn1).free;
OSCdef(\noteOn2).free;
OSCdef(\releaseFermata1).free;
OSCdef(\releaseFermata2).free;

// Create OSC responders for two different tuba instances
// Tuba 1 OSC Responder
OSCdef(\noteOn1, { |msg, time, addr, recvPort|
    var channel, note, velocity, duration, isFermata, isFirstNote, isLastNote;
    var instance, velocityMultiplier, vst;

    channel = msg[1].asInteger;
    note = msg[2].asInteger;
    velocity = msg[3].asInteger;
    duration = msg[4].asFloat;
    isFermata = msg[5].asInteger == 1;
    isFirstNote = msg[6].asInteger == 1;
    isLastNote = msg[7].asInteger == 1;
    instance = msg[8].asInteger; // 1 = first tuba
    velocityMultiplier = 1.0;

    // Apply note offset if enabled for this instance
    if(instance == 1 && ~noteOffsetMode1) {
        note = (note + ~noteOffset1).clip(0, 127);
    };

    // Apply velocity multiplier based on note position if enabled
    if(instance == 1 && ~velocityMultiplyMode1) {
        if(isFirstNote == 1) {
            velocityMultiplier = ~melodyDict[~currentSequence1[~currentMelodySetIndex1]].velocityMultipliers.first;
        };
        if(isLastNote == 1) {
            velocityMultiplier = ~melodyDict[~currentSequence1[~currentMelodySetIndex1]].velocityMultipliers.last;
        };
        velocity = (velocity * velocityMultiplier).asInteger.clip(1, 127);
    };

    ["Tuba 1 OSC:", "note:", note, "vel:", velocity, "dur:", duration, "fermata:", isFermata].postln;

    // Play on the first VST only (tuba1)
    vst = ~vstList.at(\vsti0);
    if(vst.notNil) {
        vst.midi.noteOn(0, note, velocity);

        // Schedule note release unless it's a fermata note
        if(isFermata.not) {
            SystemClock.sched(duration, {
                vst.midi.noteOff(0, note, 0);
                nil;
            });
        };
    };
}, '/note/on1');

// Tuba 2 OSC Responder
OSCdef(\noteOn2, { |msg, time, addr, recvPort|
    var channel, note, velocity, duration, isFermata, isFirstNote, isLastNote;
    var instance, velocityMultiplier, vst;

    channel = msg[1].asInteger;
    note = msg[2].asInteger;
    velocity = msg[3].asInteger;
    duration = msg[4].asFloat;
    isFermata = msg[5].asInteger == 1;
    isFirstNote = msg[6].asInteger == 1;
    isLastNote = msg[7].asInteger == 1;
    instance = msg[8].asInteger; // 2 = second tuba
    velocityMultiplier = 1.0;

    // Apply note offset if enabled for this instance
    if(instance == 2 && ~noteOffsetMode2) {
        note = (note + ~noteOffset2).clip(0, 127);
    };

    // Apply velocity multiplier based on note position if enabled
    if(instance == 2 && ~velocityMultiplyMode2) {
        if(isFirstNote == 1) {
            velocityMultiplier = ~melodyDict[~currentSequence2[~currentMelodySetIndex2]].velocityMultipliers.first;
        };
        if(isLastNote == 1) {
            velocityMultiplier = ~melodyDict[~currentSequence2[~currentMelodySetIndex2]].velocityMultipliers.last;
        };
        velocity = (velocity * velocityMultiplier).asInteger.clip(1, 127);
    };

    ["Tuba 2 OSC:", "note:", note, "vel:", velocity, "dur:", duration, "fermata:", isFermata].postln;

    // Play on the second VST only (tuba2)
    vst = ~vstList.at(\vsti1);
    if(vst.notNil) {
        vst.midi.noteOn(0, note, velocity);

        // Schedule note release unless it's a fermata note
        if(isFermata.not) {
            SystemClock.sched(duration, {
                vst.midi.noteOff(0, note, 0);
                nil;
            });
        };
    };
}, '/note/on2');

// OSC responders for releasing fermata notes
OSCdef(\releaseFermata1, { |msg, time, addr, recvPort|
    var note, vst;

    note = msg[1].asInteger;
    ["Releasing fermata note tuba 1:", note].postln;

    vst = ~vstList.at(\vsti0);
    if(vst.notNil) {
        vst.midi.noteOff(0, note, 0);
    };
}, '/note/release1');

OSCdef(\releaseFermata2, { |msg, time, addr, recvPort|
    var note, vst;

    note = msg[1].asInteger;
    ["Releasing fermata note tuba 2:", note].postln;

    vst = ~vstList.at(\vsti1);
    if(vst.notNil) {
        vst.midi.noteOff(0, note, 0);
    };
}, '/note/release2');

// Better stop functions with immediate effect
~stopTuba1 = {
    ~stop1 = true;
    if(~sketch1.notNil) {
        ~sketch1.stop;
        "Tuba 1 stopped".postln;
        // Release any held notes
        ~vstList.at(\vsti0).midi.allNotesOff(0);
    };
};

~stopTuba2 = {
    ~stop2 = true;
    if(~sketch2.notNil) {
        ~sketch2.stop;
        "Tuba 2 stopped".postln;
        // Release any held notes
        ~vstList.at(\vsti1).midi.allNotesOff(0);
    };
};

~stopAllTubas = {
    ~stopTuba1.value;
    ~stopTuba2.value;
    "All tubas stopped".postln;
};

// Create a function that returns a new sketch Task with its own parameters
~createSketch = { |instanceID = 1|
    // Determine which variables to use based on instance ID
    var stateSymbols = if(instanceID == 1) {
        (
            bpm: \bpm1,
            stop: \stop1,
            repetitions: \repetitions1,
            melodyRestMode: \melodyRestMode1,
            fermataMode: \fermataMode1,
            rampTempoMode: \rampTempoMode1,
            velocityMultiplyMode: \velocityMultiplyMode1,
            noteOffsetMode: \noteOffsetMode1,
            noteOffset: \noteOffset1,
            rampTempoStartMult: \rampTempoStartMult1,
            rampTempoEndMult: \rampTempoEndMult1,
            rampTempoCurve: \rampTempoCurve1,
            rampTempoCurveType: \rampTempoCurveType1,
            rampTempoMinRest: \rampTempoMinRest1,
            currentMelodySetIndex: \currentMelodySetIndex1,
            currentCycle: \currentCycle1,
            lastFermataNote: \lastFermataNote1,
            fermataReleaseRest: \fermataReleaseRest1,
            currentSequence: \currentSequence1,
            oscPath: '/note/on1',
            oscReleasePath: '/note/release1'
        )
    } {
        (
            bpm: \bpm2,
            stop: \stop2,
            repetitions: \repetitions2,
            melodyRestMode: \melodyRestMode2,
            fermataMode: \fermataMode2,
            rampTempoMode: \rampTempoMode2,
            velocityMultiplyMode: \velocityMultiplyMode2,
            noteOffsetMode: \noteOffsetMode2,
            noteOffset: \noteOffset2,
            rampTempoStartMult: \rampTempoStartMult2,
            rampTempoEndMult: \rampTempoEndMult2,
            rampTempoCurve: \rampTempoCurve2,
            rampTempoCurveType: \rampTempoCurveType2,
            rampTempoMinRest: \rampTempoMinRest2,
            currentMelodySetIndex: \currentMelodySetIndex2,
            currentCycle: \currentCycle2,
            lastFermataNote: \lastFermataNote2,
            fermataReleaseRest: \fermataReleaseRest2,
            currentSequence: \currentSequence2,
            oscPath: '/note/on2',
            oscReleasePath: '/note/release2'
        )
    };

    Task({
        var ts, currentNote, noteIndex, melodyIndex, repetitionCount;
        var currentMelodyList, currentMelodySet, cycleCompletionCount;
        var stopVarSymbol, shouldStop = false;

        // Store the stop variable symbol directly for later use
        stopVarSymbol = stateSymbols.stop;

        ts = TimeSignature.new(2, 3, currentEnvironment[stateSymbols.bpm]);
        noteIndex = 0;
        melodyIndex = 0;
        repetitionCount = 0;
        cycleCompletionCount = 0;

        // Initialize sequence
        currentEnvironment[stateSymbols.currentSequence] = ~developmentCycles[currentEnvironment[stateSymbols.currentCycle]].sequence;
        currentMelodySet = ~melodyDict[currentEnvironment[stateSymbols.currentSequence][currentEnvironment[stateSymbols.currentMelodySetIndex]]];
        currentMelodyList = currentMelodySet.patterns;
        currentNote = currentMelodyList[melodyIndex][noteIndex];

        ["Starting sketch", instanceID, "with sequence", currentEnvironment[stateSymbols.currentSequence]].postln;

        loop({
            var noteDuration, noteRestTime, melodyRestTime, temporalAccent, baseVelocity;
            var actualDuration, isLastNoteInMelody, isFermata, melodyLength;
            var isFirstNote, isLastNote, velocityMultiplier, finalVelocity;

            // Check stop condition at the beginning of each loop iteration
            shouldStop = if(instanceID == 1) {
                ~stop1 == true
            } {
                ~stop2 == true
            };

            if(shouldStop) {
                ["Tuba", instanceID, "stopping due to stop flag"].postln;
                this.stop;
                ^nil; // Exit the task immediately
            };

            noteDuration = ~midiController.getSliderValue(1).linlin(0, 127, 0.001, 0.3);
            noteRestTime = ~midiController.getSliderValue(2).linlin(0, 127, 0.0001, 0.4);
            melodyRestTime = 4.47;  // Using slider 6 for melody rest
            temporalAccent = ~midiController.getSliderValue(5).linlin(0, 127, 0.75, 2);
            baseVelocity = ~midiController.getSliderValue(3).linlin(0, 127, 11, 127);
            isLastNoteInMelody = (noteIndex == (currentMelodyList[melodyIndex].size - 1));
            isFermata = isLastNoteInMelody && currentEnvironment[stateSymbols.fermataMode] && currentEnvironment[stateSymbols.melodyRestMode];
            melodyLength = currentMelodyList[melodyIndex].size;
            isFirstNote = (noteIndex == 0);
            isLastNote = isLastNoteInMelody;
            velocityMultiplier = 1.0;
            finalVelocity = baseVelocity;

            // Apply velocity multiplier if mode is enabled
            if(currentEnvironment[stateSymbols.velocityMultiplyMode]) {
                if(isFirstNote) {
                    velocityMultiplier = ~melodyDict[currentEnvironment[stateSymbols.currentSequence][currentEnvironment[stateSymbols.currentMelodySetIndex]]].velocityMultipliers.at(\first);
                };
                if(isLastNote) {
                    velocityMultiplier = ~melodyDict[currentEnvironment[stateSymbols.currentSequence][currentEnvironment[stateSymbols.currentMelodySetIndex]]].velocityMultipliers.at(\last);
                };
                finalVelocity = (baseVelocity * velocityMultiplier).asInteger.clip(1, 127);
            };

            // Apply temporal accent to first note in pattern
            actualDuration = if(noteIndex == 0) {
                noteDuration * temporalAccent
            } {
                noteDuration
            };

            // Ensure note duration never exceeds rest time (prevent overlapping notes)
            if(isFermata.not) {
                var maxDuration = noteRestTime * 0.9;
                if(actualDuration > maxDuration) {
                    actualDuration = maxDuration;
                };
            };

            // Release any previous fermata note before playing a new one
            if(currentEnvironment[stateSymbols.lastFermataNote].notNil) {
                ["Releasing previous fermata note for tuba", instanceID, currentEnvironment[stateSymbols.lastFermataNote]].postln;
                NetAddr.localAddr.sendMsg(stateSymbols.oscReleasePath, currentEnvironment[stateSymbols.lastFermataNote]);
                currentEnvironment[stateSymbols.lastFermataNote] = nil;
            };

            // Send note event with instance ID
            ["Tuba", instanceID, "playing:", currentNote, "fermata:", isFermata].postln;
            NetAddr.localAddr.sendMsg(
                stateSymbols.oscPath,
                0, currentNote, finalVelocity, actualDuration,
                isFermata.asInteger, isFirstNote.asInteger, isLastNote.asInteger,
                instanceID
            );

            // If this is a fermata note, store it for later release
            if(isFermata) {
                currentEnvironment[stateSymbols.lastFermataNote] = currentNote;
            };

            // Check stop flag again before waiting
            shouldStop = if(instanceID == 1) {
                ~stop1 == true
            } {
                ~stop2 == true
            };

            if(shouldStop) {
                ["Tuba", instanceID, "stopping before wait"].postln;
                this.stop;
                ^nil; // Exit the task immediately
            };

            // Wait for rest time before next note
            noteRestTime.wait;

            // Check stop flag again after waiting
            shouldStop = if(instanceID == 1) {
                ~stop1 == true
            } {
                ~stop2 == true
            };

            if(shouldStop) {
                ["Tuba", instanceID, "stopping after wait"].postln;
                this.stop;
                ^nil; // Exit the task immediately
            };

            // Advance sequence
            noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

            // If we've completed the current pattern
            if(noteIndex == 0) {
                repetitionCount = repetitionCount + 1;
                if(repetitionCount >= currentEnvironment[stateSymbols.repetitions]) {
                    repetitionCount = 0;

                    // If melody rest mode is enabled, wait between melodies
                    if(currentEnvironment[stateSymbols.melodyRestMode]) {
                        ["Tuba", instanceID, "rest between melodies:", melodyRestTime].postln;

                        // Check stop flag before waiting for melody rest
                        shouldStop = if(instanceID == 1) {
                            ~stop1 == true
                        } {
                            ~stop2 == true
                        };

                        if(shouldStop) {
                            ["Tuba", instanceID, "stopping before melody rest"].postln;
                            this.stop;
                            ^nil; // Exit the task immediately
                        };

                        melodyRestTime.wait;

                        // Check stop flag after waiting for melody rest
                        shouldStop = if(instanceID == 1) {
                            ~stop1 == true
                        } {
                            ~stop2 == true
                        };

                        if(shouldStop) {
                            ["Tuba", instanceID, "stopping after melody rest"].postln;
                            this.stop;
                            ^nil; // Exit the task immediately
                        };

                        // If we have a fermata note, release it after the melody rest
                        if(currentEnvironment[stateSymbols.lastFermataNote].notNil) {
                            ["Releasing fermata for tuba", instanceID, "after rest"].postln;
                            NetAddr.localAddr.sendMsg(stateSymbols.oscReleasePath, currentEnvironment[stateSymbols.lastFermataNote]);
                            currentEnvironment[stateSymbols.lastFermataNote] = nil;
                        };
                    };

                    // Always apply the fermata release rest, regardless of fermata mode
                    ["Tuba", instanceID, "applying release rest:", currentEnvironment[stateSymbols.fermataReleaseRest]].postln;

                    // Check stop flag before waiting for fermata release rest
                    shouldStop = if(instanceID == 1) {
                        ~stop1 == true
                    } {
                        ~stop2 == true
                    };

                    if(shouldStop) {
                        ["Tuba", instanceID, "stopping before release rest"].postln;
                        this.stop;
                        ^nil; // Exit the task immediately
                    };

                    // Apply the fermata release rest even when no fermata was used
                    currentEnvironment[stateSymbols.fermataReleaseRest].wait;

                    // Check stop flag after waiting for fermata release rest
                    shouldStop = if(instanceID == 1) {
                        ~stop1 == true
                    } {
                        ~stop2 == true
                    };

                    if(shouldStop) {
                        ["Tuba", instanceID, "stopping after release rest"].postln;
                        this.stop;
                        ^nil; // Exit the task immediately
                    };

                    currentEnvironment[stateSymbols.currentMelodySetIndex] =
                        (currentEnvironment[stateSymbols.currentMelodySetIndex] + 1) %
                        currentEnvironment[stateSymbols.currentSequence].size;

                    if(currentEnvironment[stateSymbols.currentMelodySetIndex] == 0) {
                        cycleCompletionCount = cycleCompletionCount + 1;
                        if(cycleCompletionCount >= 2) {
                            cycleCompletionCount = 0;
                            // Call the appropriate advance cycle function
                            if(instanceID == 1) {
                                ~advanceCycle1.value;
                            } {
                                ~advanceCycle2.value;
                            };
                        };
                    };

                    currentMelodySet = ~melodyDict[currentEnvironment[stateSymbols.currentSequence][currentEnvironment[stateSymbols.currentMelodySetIndex]]];
                    currentMelodyList = currentMelodySet.patterns;
                    ["Tuba", instanceID, "New Melody:", currentMelodySet.name].postln;
                };
            };

            currentNote = currentMelodyList[melodyIndex][noteIndex];
            ts.advance;
        });
    });
};

// Helper functions to switch and advance cycles for each instance
~switchCycle1 = { |cycleNumber|
    if(~developmentCycles.includesKey(cycleNumber)) {
        ~currentCycle1 = cycleNumber;
        ~currentSequence1 = ~developmentCycles[cycleNumber].sequence;
        ~currentMelodySetIndex1 = 0;
        ["Tuba 1 switching to cycle:", ~developmentCycles[cycleNumber].name].postln;
    };
};

~switchCycle2 = { |cycleNumber|
    if(~developmentCycles.includesKey(cycleNumber)) {
        ~currentCycle2 = cycleNumber;
        ~currentSequence2 = ~developmentCycles[cycleNumber].sequence;
        ~currentMelodySetIndex2 = 0;
        ["Tuba 2 switching to cycle:", ~developmentCycles[cycleNumber].name].postln;
    };
};

~advanceCycle1 = {
    var nextCycle = ~currentCycle1 + 1;
    if(~developmentCycles.includesKey(nextCycle)) {
        ~switchCycle1.value(nextCycle);
        ["Tuba 1 advancing to cycle:", nextCycle].postln;
    };
};

~advanceCycle2 = {
    var nextCycle = ~currentCycle2 + 1;
    if(~developmentCycles.includesKey(nextCycle)) {
        ~switchCycle2.value(nextCycle);
        ["Tuba 2 advancing to cycle:", nextCycle].postln;
    };
};

// Initialize melody dictionary (shared between instances)
// Melody sets dictionary - imported from original file
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 1.0    // 100% velocity for last note
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

// Define development cycles (shared between instances)
~developmentCycles = Dictionary.new;
// ~developmentCycles.put(1, (
// 	name: "Initial Cycle",
// 	sequence: [\set3,\set3,\set3,\set3,\set5,\set5,\set5,\set5,\set6,\set6,\set6,\set6,\set7,\set7,\set7,\set7]
// ));
~developmentCycles.put(1, (
	name: "Initial Cycle",
	sequence: [\set8,\set8,\set8,\set8]
));
//
// ~developmentCycles.put(1, (
// 	name: "Initial Cycle",
// 	sequence: [\part2b]
// ));


// Initialize parameters for Tuba 1
~bpm1 = 298;
~stop1 = false;
~repetitions1 = 1;
~melodyRestMode1 = false;
~fermataMode1 = false;
~rampTempoMode1 = false;
~velocityMultiplyMode1 = false;
~noteOffsetMode1 = true;
~noteOffset1 = -12;
~rampTempoStartMult1 = 0.1;
~rampTempoEndMult1 = 5.0;
~rampTempoCurve1 = 1.0;
~rampTempoCurveType1 = \exponential;
~rampTempoMinRest1 = 0.125;
~currentMelodySetIndex1 = 0;
~currentCycle1 = 1;
~lastFermataNote1 = nil;
~fermataReleaseRest1 = 0;

// Initialize parameters for Tuba 2 (with some different settings)
~bpm2 = 298;
~stop2 = false;
~repetitions2 = 1;
~melodyRestMode2 = false;
~fermataMode2 = false;  // Different fermata mode from Tuba 1
~rampTempoMode2 = false;
~velocityMultiplyMode2 = true; // Different from Tuba 1
~noteOffsetMode2 = true;
~noteOffset2 = 0;      // Different offset from Tuba 1
~rampTempoStartMult2 = 0.1;
~rampTempoEndMult2 = 5.0;
~rampTempoCurve2 = 1.0;
~rampTempoCurveType2 = \exponential;
~rampTempoMinRest2 = 0.125;
~currentMelodySetIndex2 = 0;
~currentCycle2 = 1;
~lastFermataNote2 = nil;
~fermataReleaseRest2 = 0;

// Initialize sequences for both instances
~currentSequence1 = ~developmentCycles[~currentCycle1].sequence;
~currentSequence2 = ~developmentCycles[~currentCycle2].sequence;

// Create the two sketch instances
~sketch1 = ~createSketch.value(1);
~sketch2 = ~createSketch.value(2);
)
~sketch1.stop;
~sketch2.stop;

~sketch1.play;
~sketch2.play;
~stop1 = true;
~stop2 = true;

// Control commands for Tuba 1
~sketch1.play;
~stopTuba1.value;  // Use this instead of just setting ~stop1 = true
~fermataMode1 = true;       // Enable fermata mode for Tuba 1
~fermataMode1 = false;      // Disable fermata mode for Tuba 1
~velocityMultiplyMode1 = true;   // Enable velocity multiplier for Tuba 1
~noteOffset1 = -12;          // Set note offset for Tuba 1 (one octave down)
~switchCycle1.value(1);      // Switch cycle for Tuba 1

// Control commands for Tuba 2
~sketch2.play;
~stopTuba2.value;  // Use this instead of just setting ~stop2 = true
~fermataMode2 = true;       // Enable fermata mode for Tuba 2
~fermataMode2 = false;      // Disable fermata mode for Tuba 2
~velocityMultiplyMode2 = false;   // Disable velocity multiplier for Tuba 2
~noteOffset2 = 0;            // Set note offset for Tuba 2 (no transposition)
~switchCycle2.value(1);      // Switch cycle for Tuba 2

// Control release rest duration
~fermataReleaseRest1 = 0.5;  // Set tuba 1 release rest to 0.5 seconds
~fermataReleaseRest2 = 0.25; // Set tuba 2 release rest to 0.25 seconds

// Play both sketches with different parameters
(
~stop1 = false;
~stop2 = false;
~fermataMode1 = false;
~fermataMode2 = true;
~noteOffset1 = -12;
~noteOffset2 = 0;
~sketch1.play;
~sketch2.play;
)

// Stop both sketches with the new helper function
~stopAllTubas.value;

// Stop all notes on both VSTs
(
~vstList.at(\vsti0).midi.allNotesOff(0);
~vstList.at(\vsti1).midi.allNotesOff(0);
)
