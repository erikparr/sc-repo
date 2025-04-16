(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-tuba.scd").load;

(

/* MELODIC PART with Individual Note Playback */
~bpm = 298;
~stop = false;
~repetitions = 1;
~melodyRestMode = false;  // Toggle for longer rests between melodies
~fermataMode = false;     // Toggle for holding the last note of each melody
~rampTempoMode = false;   // Toggle for progressively changing note rest times
~rampTempoStartMult = 0.1;  // Start with short rests (10% of normal)
~rampTempoEndMult = 5.0;    // End with longer rests (5x normal)
~rampTempoCurve = 3.0;     // Positive curve for fast-to-slow progression
~rampTempoCurveType = \exponential;  // Curve type: \linear, \exponential, \sine, \cosine, \bell, \welch, \perlin, \step
~rampTempoMinRest = 0.01;   // Minimum rest time in seconds, to prevent too rapid notes
~currentMelodySetIndex = 0;
~currentCycle = 1;  // Track which cycle we're in
~lastFermataNote = nil;  // Track the last fermata note to release it

// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;
OSCdef(\releaseFermata).free;

// OSC responder for note events with debug printing
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;  // Parameter for fermata notes

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

/* SCALE DEFINITION AND GENERATION */

// Define a Scale Generator function that respects the octave parameter
~generateScale = { |root=53, scaleType=\phrygianDominant, octave=4, direction=\ascending, numNotes=8|
    var intervals, notes, rootMidi;
    var scaleTypes = (
        phrygianDominant: [0, 1, 4, 5, 7, 8, 10, 12],  // F Phrygian dominant: F – G♭ – A – B♭ – C – D♭ – E♭ – F
        major: [0, 2, 4, 5, 7, 9, 11, 12],
        minor: [0, 2, 3, 5, 7, 8, 10, 12],
        harmonicMinor: [0, 2, 3, 5, 7, 8, 11, 12],
        melodicMinor: [0, 2, 3, 5, 7, 9, 11, 12],
        dorian: [0, 2, 3, 5, 7, 9, 10, 12],
        mixolydian: [0, 2, 4, 5, 7, 9, 10, 12],
        lydian: [0, 2, 4, 6, 7, 9, 11, 12],
        locrian: [0, 1, 3, 5, 6, 8, 10, 12],
        octatonic: [0, 2, 3, 5, 6, 8, 9, 11, 12]  // Octatonic (diminished) scale: alternating whole and half steps
    );

    // Get the intervals for the selected scale type
    intervals = scaleTypes[scaleType];
    if(intervals.isNil) {
        "Invalid scale type. Using phrygianDominant as default.".postln;
        intervals = scaleTypes.phrygianDominant;
    };

    // Use the root note as provided - don't recalculate based on octave
    rootMidi = root;

    // Generate the basic scale for this root
    notes = intervals.collect { |interval| rootMidi + interval };

    // If we need more notes than a single octave provides, we'll need to repeat the pattern
    if(numNotes > notes.size) {
        "Warning: Requested more notes than available in a single octave of this scale.".postln;
        "Limiting to available notes.".postln;
        numNotes = notes.size;
    };

    // Apply direction
    notes = switch(direction,
        \ascending, { notes },
        \descending, { notes.reverse },
        \ascendingDescending, { notes ++ notes.reverse.drop(1).drop(-1) },
        \descendingAscending, { notes.reverse ++ notes.drop(1).drop(-1) },
        // Default to ascending if invalid direction
        { notes }
    );

    // Limit to the specified number of notes
    if(numNotes < notes.size) {
        notes = notes[0..numNotes-1];
    };

    ["Generated scale:",
     "Root:", rootMidi.asString ++ " (" ++ rootMidi.midicps.round(0.01) ++ "Hz)",
     "Type:", scaleType,
     "Direction:", direction,
     "Notes:", notes].postln;

    notes;
};

// Define a Hybrid Scale Generator function
~generateHybridScale = { |root1=65, scaleType1=\phrygianDominant, root2=65, scaleType2=\octatonic,
                         octave=4, direction=\ascending, numNotes=12, selectionMethod=\alternate|
    var scale1, scale2, hybridScale, availableNotes, nextNote, lastScale = nil;
    var notePool = Set.new;  // Use a Set to avoid duplicates
    var continueLoop;
    var maxOctaveSpan = 3;  // Allow spanning up to 3 octaves to get more notes

    // Generate the first scale with extended octave range
    scale1 = [];
    (0..maxOctaveSpan).do { |octaveOffset|
        var octaveShift = if(direction == \descending, -1 * octaveOffset, octaveOffset);
        var extendedRoot = root1 + (octaveShift * 12);
        scale1 = scale1 ++ ~generateScale.value(
            extendedRoot,
            scaleType1,
            octave + octaveShift,
            direction,
            16  // Request more notes than we need to have a good pool
        );
    };

    // Generate the second scale with extended octave range
    scale2 = [];
    (0..maxOctaveSpan).do { |octaveOffset|
        var octaveShift = if(direction == \descending, -1 * octaveOffset, octaveOffset);
        var extendedRoot = root2 + (octaveShift * 12);
        scale2 = scale2 ++ ~generateScale.value(
            extendedRoot,
            scaleType2,
            octave + octaveShift,
            direction,
            16  // Request more notes than we need to have a good pool
        );
    };

    ["Generated source scales with extended range:",
     "Scale 1:", scale1,
     "Scale 2:", scale2].postln;

    // Add all notes to the pool (Set automatically eliminates duplicates)
    scale1.do { |note| notePool.add(note) };
    scale2.do { |note| notePool.add(note) };

    // Convert to Array and sort according to direction
    availableNotes = notePool.asArray;
    availableNotes = switch(direction,
        \ascending, { availableNotes.sort },
        \descending, { availableNotes.sort.reverse },
        // For bidirectional, we'll still sort ascending and handle direction in the selection
        { availableNotes.sort }
    );

    ["Available notes after deduplication:", availableNotes.size, "notes:", availableNotes].postln;

    // Initialize hybrid scale
    hybridScale = [];

    // Select notes according to the specified method
    switch(selectionMethod,
        \alternate, {
            // Simple alternating selection between scales
            var scaleIndex = 0;
            var scale1Index = 0;
            var scale2Index = 0;
            var notesAdded = 0;
            var maxAttempts = availableNotes.size * 2;  // Prevent infinite loops
            var attempts = 0;

            while { (notesAdded < numNotes) && (attempts < maxAttempts) } {
                var currentScale, noteIndex;
                attempts = attempts + 1;

                if(scaleIndex == 0) {
                    currentScale = scale1;
                    noteIndex = scale1Index;
                    scale1Index = scale1Index + 1;
                    if(scale1Index >= currentScale.size) { scale1Index = 0 };
                } {
                    currentScale = scale2;
                    noteIndex = scale2Index;
                    scale2Index = scale2Index + 1;
                    if(scale2Index >= currentScale.size) { scale2Index = 0 };
                };

                if(noteIndex < currentScale.size) {
                    var note = currentScale[noteIndex];
                    if(hybridScale.includes(note).not) {
                        hybridScale = hybridScale.add(note);
                        notesAdded = notesAdded + 1;
                    };
                };

                scaleIndex = (scaleIndex + 1) % 2;
            };
        },

        \zigzag, {
            // Zigzag through the available notes, choosing from the closest scale
            var currentNote = availableNotes.first;
            hybridScale = hybridScale.add(currentNote);

            continueLoop = true;
            while { continueLoop && (hybridScale.size < numNotes) && (availableNotes.size > 1) } {
                var scale1Candidate = nil, scale2Candidate = nil;
                var scale1Distance = inf, scale2Distance = inf;

                // Find the next note in scale1
                scale1.do { |note|
                    if(hybridScale.includes(note).not) {
                        var distance = (note - currentNote).abs;
                        if(distance < scale1Distance) {
                            scale1Distance = distance;
                            scale1Candidate = note;
                        };
                    };
                };

                // Find the next note in scale2
                scale2.do { |note|
                    if(hybridScale.includes(note).not) {
                        var distance = (note - currentNote).abs;
                        if(distance < scale2Distance) {
                            scale2Distance = distance;
                            scale2Candidate = note;
                        };
                    };
                };

                // Choose the note from the scale that wasn't used last time, if possible
                if(scale1Candidate.notNil && scale2Candidate.notNil) {
                    if(lastScale == \scale1 && scale2Candidate.notNil) {
                        currentNote = scale2Candidate;
                        lastScale = \scale2;
                    } {
                        currentNote = scale1Candidate;
                        lastScale = \scale1;
                    };
                } {
                    if(scale1Candidate.notNil) {
                        currentNote = scale1Candidate;
                        lastScale = \scale1;
                    } {
                        if(scale2Candidate.notNil) {
                            currentNote = scale2Candidate;
                            lastScale = \scale2;
                        } {
                            // No more candidates available
                            continueLoop = false;
                        };
                    };
                };

                if(continueLoop) {
                    hybridScale = hybridScale.add(currentNote);
                };
            };
        },

        \nearest, {
            // Start with the lowest/highest note and always choose the nearest unused note
            var currentNote = availableNotes.first;
            hybridScale = hybridScale.add(currentNote);
            availableNotes.remove(currentNote);

            continueLoop = true;
            while { continueLoop && (hybridScale.size < numNotes) && (availableNotes.size > 0) } {
                var nearestNote = nil;
                var minDistance = inf;

                // Find the nearest unused note
                availableNotes.do { |note|
                    var distance = (note - currentNote).abs;
                    if(distance < minDistance) {
                        minDistance = distance;
                        nearestNote = note;
                    };
                };

                if(nearestNote.notNil) {
                    currentNote = nearestNote;
                    hybridScale = hybridScale.add(currentNote);
                    availableNotes.remove(currentNote);
                } {
                    continueLoop = false;
                };
            };
        },

        // Default to simple merge and sort
        {
            hybridScale = availableNotes[0..numNotes-1];
        }
    );

    // Ensure we have exactly the requested number of notes
    if(hybridScale.size > numNotes) {
        hybridScale = hybridScale[0..numNotes-1];
    } {
        // If we couldn't get enough unique notes, repeat the pattern
        if(hybridScale.size < numNotes) {
            var originalSize = hybridScale.size;
            var repetitions = (numNotes / originalSize).ceil.asInteger;

            if(originalSize > 0) {  // Prevent division by zero
                var extendedScale = [];
                repetitions.do { |i|
                    extendedScale = extendedScale ++ hybridScale;
                };
                hybridScale = extendedScale[0..numNotes-1];
            };
        };
    };

    ["Generated hybrid scale with", hybridScale.size, "notes:", hybridScale].postln;

    hybridScale;
};

// Helper function to regenerate the hybrid scale with new parameters
~regenerateHybridScale = { |root1=65, scaleType1=\phrygianDominant, root2=65, scaleType2=\octatonic,
                           octave=4, direction=\ascending, numNotes=12, selectionMethod=\alternate|
    ~hybridScale = ~generateHybridScale.value(
        root1, scaleType1, root2, scaleType2,
        octave, direction, numNotes, selectionMethod
    );

    // Update the melody dictionary
    ~melodyDict.put(\set1, (
        name: root1.asString ++ " " ++ scaleType1 ++ " + " ++ root2.asString ++ " " ++ scaleType2 ++ " Hybrid Scale",
        patterns: [
            ~hybridScale,
        ]
    ));

    // Reset the current melody set index to play the new scale
    ~currentMelodySetIndex = 0;

    // Reset the sketch to ensure it plays from the beginning
    ~stop = true;
    ~sketch.stop;
    ~stop = false;

    "Hybrid scale regenerated with " ++ ~hybridScale.size ++ " notes. Run ~sketch.play to hear it.".postln;
};

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

// Generate F Phrygian dominant scale (F – G♭ – A – B♭ – C – D♭ – E♭ – F)
// F in MIDI is 53 (F3), 65 (F4), 77 (F5)
~fPhrygianDominant = ~generateScale.value(
    53,                    // F3 as root
    \phrygianDominant,     // Scale type
    3,                     // Octave 3
    \descending,           // Direction
    8                      // Number of notes
);

// Melody sets dictionary with our scale
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "F Phrygian Dominant Scale",
    patterns: [
        ~fPhrygianDominant,  // Our generated scale
    ]
));

// Define development cycles
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (
    name: "Scale Cycle",
    sequence: [\set1]
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

// Helper function to regenerate the scale with new parameters
~regenerateScale = { |root=53, scaleType=\phrygianDominant, octave=3, direction=\descending, numNotes=8|
    ~fPhrygianDominant = ~generateScale.value(
        root,
        scaleType,
        octave,
        direction,
        numNotes
    );

    // Update the melody dictionary
    ~melodyDict.put(\set1, (
        name: root.asString ++ " " ++ scaleType ++ " Scale",
        patterns: [
            ~fPhrygianDominant,
        ]
    ));

    // Reset the current melody set index to play the new scale
    ~currentMelodySetIndex = 0;

    "Scale regenerated. Restart the sketch to play the new scale.".postln;
};

// Window-based descending evolution scale generator
~generateWindowEvolutionScale = { |startNote=77, numNotes=6, endNote=55|
    var allNotes, currentScale;
    var octaveRange = ((startNote - endNote) / 12).ceil.asInteger;
    var scaleNotes = Array.new;

    // Generate notes for each octave we need to cover
    (0..octaveRange).do { |octave|
        var rootNote = startNote - (octave * 12);
        var octaveNotes = ~generateScale.value(
            rootNote,
            \phrygianDominant,
            rootNote.midicps.cpsmidi.round.asInteger.div(12),
            \descending,
            8  // Full octave of scale
        );
        scaleNotes = scaleNotes.addAll(octaveNotes);
    };

    // Sort and remove duplicates
    allNotes = scaleNotes.asSet.asArray.sort({ |a, b| b < a });  // Sort descending

    ["DEBUG - Window Evolution:",
        "\nStart note:", startNote,
        "\nEnd note:", endNote,
        "\nOctave range needed:", octaveRange,
        "\nAll available notes:", allNotes,
        "\nTotal notes generated:", allNotes.size
    ].postln;

    // Function to get the next evolution of the scale
    ~getNextEvolution = { |currentScale|
        var currentHighestNote = currentScale[0];
        var nextStartIndex = allNotes.indexOf(currentHighestNote) + 1;

        ["DEBUG - Window Evolution:",
            "\nCurrent window:", currentScale,
            "\nMoving window to index:", nextStartIndex,
            "\nNext window would be:", if(nextStartIndex.notNil) {
                allNotes[nextStartIndex..(nextStartIndex + numNotes - 1)]
            } { "none" }
        ].postln;

        if(nextStartIndex.notNil and: { (nextStartIndex + numNotes - 1) < allNotes.size }) {
            var nextScale = allNotes[nextStartIndex..(nextStartIndex + numNotes - 1)];

            if(nextScale.last <= endNote) {
                ["Evolution complete - reached or passed target note:", endNote].postln;
                nil;
            } {
                ["Window evolved to:", nextScale].postln;
                nextScale;
            };
        } {
            ["Evolution complete - reached end of available notes"].postln;
            nil;
        };
    };

    // Initialize with the highest possible notes
    currentScale = allNotes[0..(numNotes-1)];

    // Update the melody dictionary with evolution settings
    ~melodyDict.put(\set1, (
        name: "Window Evolution Scale (End at " ++ endNote ++ ")",
        patterns: [currentScale],
        evolving: true,
        repetitionsBeforeEvolution: 1
    ));

    // Reset the current melody set index
    ~currentMelodySetIndex = 0;

    ["Initial window:", currentScale, "Will stop at or before:", endNote].postln;
    currentScale;
};

// Update the startEvolvingScale function to use the new generator
~startEvolvingScale = { |startNote=65, numNotes=8, endNote=48|
    ~generateWindowEvolutionScale.value(startNote, numNotes, endNote);
    ~stop = true;
    ~sketch.stop;
    ~stop = false;
    ~sketch.play;
    "Started new evolving scale with end note:" + endNote + ".".postln;
};

~sketch = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var currentNote, noteIndex = 0, melodyIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;
    var currentMelodySet;
    var cycleCompletionCount = 0;
    var nextScale;  // Declare at the beginning with other vars

    // Initialize sequence
    ~currentSequence = ~developmentCycles[~currentCycle].sequence;
    currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
    currentMelodyList = currentMelodySet.patterns;
    currentNote = currentMelodyList[melodyIndex][noteIndex];

    loop({
        var noteDuration, noteRestTime, melodyRestTime, temporalAccent, velocity;
        var actualDuration, isLastNoteInMelody, isFermata, melodyLength;
        var normalizedPosition, curvedPosition, rampFactor;

        // Add safety checks and default values for slider values
        noteDuration = if(~midiController.notNil and: { ~midiController.sliderValues.notNil }) {
            var sliderVal = ~midiController.sliderValues[1] ? 0;  // Default to 0 if nil
            sliderVal.linlin(0, 127, 0.1, 0.3);  // Minimum 100ms duration
        } {
            0.2 // default duration
        };

        noteRestTime = if(~midiController.notNil and: { ~midiController.sliderValues.notNil }) {
            var sliderVal = ~midiController.sliderValues[2] ? 0;  // Default to 0 if nil
            sliderVal.linlin(0, 127, 0.15, 0.4);  // Minimum 150ms rest
        } {
            0.3 // default rest time
        };

        melodyRestTime = if(~midiController.notNil and: { ~midiController.sliderValues.notNil }) {
            ~midiController.sliderValues[6].linlin(0, 127, 0.5, 8.0);
        } {
            2.0 // default melody rest time
        };

        temporalAccent = if(~midiController.notNil and: { ~midiController.sliderValues.notNil }) {
            ~midiController.sliderValues[5].linlin(0, 127, 0.75, 2);
        } {
            1.5 // default accent
        };

        velocity = if(~midiController.notNil and: { ~midiController.sliderValues.notNil }) {
            ~midiController.sliderValues[3].linlin(0, 127, 40, 127);
        } {
            80 // default velocity
        };

        isLastNoteInMelody = (noteIndex == (currentMelodyList[melodyIndex].size - 1));
        isFermata = isLastNoteInMelody && ~fermataMode && ~melodyRestMode;
        melodyLength = currentMelodyList[melodyIndex].size;

        // Apply rampTempo if enabled
        if(~rampTempoMode) {
            normalizedPosition = noteIndex / (melodyLength - 1); // Position from 0.0 to 1.0

            // Apply selected curve type to the normalized position
            curvedPosition = ~applyCurve.value(normalizedPosition, ~rampTempoCurveType, ~rampTempoCurve);

            // Calculate the multiplier at this position
            rampFactor = ~rampTempoStartMult.blend(~rampTempoEndMult, curvedPosition);

            // Apply the multiplier to note rest time
            noteRestTime = noteRestTime * rampFactor;

            // Ensure rest time doesn't go below minimum
            noteRestTime = noteRestTime.max(~rampTempoMinRest);
        };

        // Apply temporal accent to first note in pattern
        actualDuration = if(noteIndex == 0) {
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
        ["Iteration:", i, "Note:", currentNote, "Rest time:", noteRestTime].postln;
        ["Playing note:", currentNote, "duration:", actualDuration, "noteIndex:", noteIndex, "fermata:", isFermata].postln;
        NetAddr.localAddr.sendMsg('/note/on', 0, currentNote, velocity, actualDuration, isFermata.asInteger);

        // If this is a fermata note, store it for later release
        if(isFermata) {
            ~lastFermataNote = currentNote;
        };

        // Just before the wait
        ["Debug - noteRestTime:", noteRestTime, noteRestTime.class].postln;
        noteRestTime.wait;

        // Advance sequence
        noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

        // Add debugging around the pattern completion check
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;

            if(currentMelodySet.evolving == true and:
               {repetitionCount >= (currentMelodySet.repetitionsBeforeEvolution ? 1)}) {

                repetitionCount = 0;  // Reset counter

                nextScale = ~getNextEvolution.value(currentMelodyList[melodyIndex]);

                if(nextScale.notNil) {
                    ["Evolving scale to:", nextScale].postln;
                    currentMelodyList[melodyIndex] = nextScale;
                    ~melodyDict[~currentSequence[~currentMelodySetIndex]].patterns = [nextScale];
                } {
                    ["Evolution complete, stopping playback"].postln;
                    ~stop = true;
                };
            };

            // If melody rest mode is enabled, wait between melodies
            if(~melodyRestMode) {
                ["Taking a longer rest between melodies:", melodyRestTime, "seconds"].postln;
                melodyRestTime.wait;
            };

            // Only advance melody set index if we're not evolving
            if(currentMelodySet.evolving != true) {
                ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~currentSequence.size;
            };

            currentMelodySet = ~melodyDict[~currentSequence[~currentMelodySetIndex]];
            currentMelodyList = currentMelodySet.patterns;
            ["New Melody Set:", currentMelodySet.name, currentMelodyList[0]].postln;
        };

        currentNote = currentMelodyList[melodyIndex][noteIndex];
        ts.advance;
        ts.printCurrentTime;

        if(~stop) { ~sketch.stop };
    });
});

// Helper function to restart the sketch
~restartSketch = {
	~sketch.reset;  // Reset the task to start from the beginning
    ~stop = true;
    ~sketch.stop;
    ~stop = false;
    ~sketch.play;
    "Sketch restarted.".postln;
};
)
~startEvolvingScale.(86, 4, 79);
// =====================================================
// HYBRID SCALE EXAMPLES - QUICK REFERENCE
// =====================================================
(
// 1. Create a hybrid scale combining F5 Phrygian dominant and F5 octatonic
~regenerateHybridScale.(
    77, \phrygianDominant,  // Scale 1: F5 Phrygian dominant
    77, \octatonic,         // Scale 2: F5 octatonic
    5, \descending, 7,      // Octave 5, ascending, 12 notes
    \zigzag              // Selection method: alternate between scales
);
)
~restartSketch.value;
~sketch.play;  // Play the hybrid scale
~stop = true;

// 2. Create a hybrid scale with different roots (C4 major + D4 minor)
~regenerateHybridScale.(
    60, \major,             // Scale 1: C4 major
    62, \minor,             // Scale 2: D4 minor
    4, \descending, 12,     // Octave 4, descending, 12 notes
    \zigzag                 // Selection method: zigzag between scales
);
~sketch.play;
~stop = true;

// 3. Create a hybrid scale with nearest-note selection
~regenerateHybridScale.(
    53, \phrygianDominant,  // Scale 1: F3 Phrygian dominant
    53, \octatonic,         // Scale 2: F3 octatonic
    3, \ascending, 12,      // Octave 3, ascending, 12 notes
    \nearest                // Selection method: always choose nearest note
);
~sketch.play;
~stop = true;

// 4. Create a bidirectional hybrid scale
~regenerateHybridScale.(
    65, \harmonicMinor,     // Scale 1: F4 harmonic minor
    65, \melodicMinor,      // Scale 2: F4 melodic minor
    4, \ascendingDescending, 16, // Octave 4, up and down, 16 notes
    \alternate              // Selection method: alternate between scales
);
~sketch.play;
~stop = true;

// Stop all notes if needed
(
~vstList.do { |item, index|
    item.midi.allNotesOff(index);
};
)

// Start from F4 (65), use 8 notes, stop when reaching or going below C3 (48)
~startEvolvingScale.(65, 8, 48);

// Or start from F5 (77), use 6 notes, stop at G3 (55)
~startEvolvingScale.(77, 6, 55);

// Stop when needed
~stop = true;