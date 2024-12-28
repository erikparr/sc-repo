(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;



/* MELODIC PART 2 with Individual Note Playback */
(
~bpm = 298;
~stop = false;
~repetitions = 2;
~randomMode = false;
~currentMelodySetIndex = 0;

// Restructured melody sets as a dictionary
~melodyDict = Dictionary.new;
~melodyDict.put(\set1, (
    name: "First Set",
    patterns: [
        [58, 51, 53],
        [58, 51, 53]
    ]
));
~melodyDict.put(\set2, (
    name: "Second Set",
    patterns: [
        [61, 53, 54],
        [61, 53, 54],
    ]
));
~melodyDict.put(\set3, (
    name: "Third Set",
    patterns: [
        [61, 58, 54],
        [61, 58, 54]
    ]
));
~melodyDict.put(\set4, (
    name: "Fourth Set",
    patterns: [
        [61, 57, 52],
        [61, 57, 52]
    ]
));
~melodyDict.put(\set5, (
    name: "Fifth Set",
    patterns: [
        [58, 53, 51],
        [58, 53, 51]
    ]
));
~melodyDict.put(\set6, (
    name: "Sixth Set",
    patterns: [
        [58, 54, 49],
        [58, 54, 49]
    ]
));

// Melody arrangements dictionary
~arrangements = Dictionary.new;
~arrangements.put(\intro, (
    name: "Basic Set 1-2 Cycle",
    sequence: [\set1, \set2]
));
~arrangements.put(\extended, (
    name: "Extended Three Set Cycle",
    sequence: [\set1, \set2, \set3]
));
~arrangements.put(\minimal, (
    name: "Minimal Set 1 Only",
    sequence: [\set1]
));

// Current arrangement selection
~currentArrangement = \intro;
~currentArrangementIndex = 0;

// Convert dictionary keys to ordered array for indexing (now based on arrangement)
~melodySetKeys = ~arrangements[~currentArrangement].sequence;

~sketch = Task({
    var ts = TimeSignature.new(2, 3, ~bpm);
    var noteDuration = 0, restTime = 0;  // Duration of notes and rests
    var currentNote = 0;
    var noteIndex = 0;
    var melodyIndex = 0;
    var repetitionCount = 0;
    var currentMelodyList;
    var temporalAccent;
    var velocity;
    var accentedDuration;

    // Helper function to get next melody index
    var getNextMelodyIndex = {
        if(~randomMode) {
            var currentIndex = melodyIndex;
            while({
                melodyIndex = currentMelodyList.size.rand;
                melodyIndex == currentIndex;
            });
            melodyIndex;
        } {
            (melodyIndex + 1) % currentMelodyList.size;
        };
    };

    ~stop = false;
    currentMelodyList = ~melodyDict[~melodySetKeys[~currentMelodySetIndex]].patterns;
    currentNote = currentMelodyList[melodyIndex][noteIndex];
    0.25.wait;

    loop({
        // Get timing values from MIDI controller
        noteDuration = ~midiController.sliderValues[1].linlin(0, 127, 0.001, 0.75);  // Controls how long each note is held
        restTime = ~midiController.sliderValues[2].linlin(0, 127, 0.01, 0.5);       // Controls rest duration between notes

        // Get temporal accent factor from slider 5 (75% to 150% of normal duration)
        temporalAccent = ~midiController.sliderValues[5].linlin(0, 127, 0.75, 1.5);

        // Update tempo
        ts.setBPM(~midiController.sliderValues[0].linlin(0, 127, 60, 400));

        // Calculate base velocity
        velocity = ~midiController.sliderValues[3].linlin(0, 127, 0, 100);

        // Play current single note
        ~vstList.do { |item|
            item.midi.noteOn(0, currentNote, velocity);
        };
        currentNote.post; " ".post;
        if(noteIndex == 0) {
            ["TEMPORAL ACCENT:", temporalAccent].postln;
        } {
            "".postln;
        };

        // Apply temporal accent to the note duration for the first note
        accentedDuration = if(noteIndex == 0) {
            noteDuration * temporalAccent;
        } {
            noteDuration;
        };

        postf("note duration: % (accent: %)\n", accentedDuration, if(noteIndex == 0) { temporalAccent } { 1 });
        accentedDuration.wait;  // Hold the note

        // Release current note
        ~vstList.do { |item|
            item.midi.noteOff(0, currentNote, 0);
        };

        restTime.wait;  // Rest between notes

        // Advance to next note in current melody
        noteIndex = (noteIndex + 1) % (currentMelodyList[melodyIndex].size);

        // If we've completed the current melody
        if(noteIndex == 0) {
            repetitionCount = repetitionCount + 1;
            if (repetitionCount >= ~repetitions) {
                repetitionCount = 0;
                melodyIndex = getNextMelodyIndex.value;

                // If we've completed all melodies in current set, move to next set in arrangement
                if(melodyIndex == 0) {
                    ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~melodySetKeys.size;
                    currentMelodyList = ~melodyDict[~melodySetKeys[~currentMelodySetIndex]].patterns;
                    ["Current melody set:", ~melodyDict[~melodySetKeys[~currentMelodySetIndex]].name].postln;
                }
            }
        };

        currentNote = currentMelodyList[melodyIndex][noteIndex];
        ts.advance;

        if(~stop == true) {
            ~sketch.stop;
        };
    });
});
)

// Control commands
~sketch.play;
~repetitions = 2;  // Change number of repetitions
~stop = true;

// Arrangement control
~switchToArrangement.value(\intro);     // Switch to intro Set 1-2 cycle
~switchToArrangement.value(\extended);   // Switch to extended three set cycle
~switchToArrangement.value(\minimal);    // Switch to minimal single set

// Modified melody set switching functions
~switchToNextMelodySet = {
    ~currentMelodySetIndex = (~currentMelodySetIndex + 1) % ~melodySetKeys.size;
    ["Switching to melody set:", ~melodyDict[~melodySetKeys[~currentMelodySetIndex]].name].postln;
};

~switchToMelodySet = { |setIndex|
    if(setIndex >= 0 and: { setIndex < ~melodySetKeys.size }) {
        ~currentMelodySetIndex = setIndex;
        ["Switching to melody set:", ~melodyDict[~melodySetKeys[~currentMelodySetIndex]].name].postln;
    } {
        "Invalid melody set index".postln;
    };
};

// New function to switch arrangements
~switchToArrangement = { |arrangementKey|
    if(~arrangements.includesKey(arrangementKey)) {
        ~currentArrangement = arrangementKey;
        ~melodySetKeys = ~arrangements[arrangementKey].sequence;
        ~currentMelodySetIndex = 0;
        ["Switching to arrangement:", ~arrangements[arrangementKey].name].postln;
        ["Sequence:", ~melodySetKeys].postln;
    } {
        "Invalid arrangement key".postln;
    };
};
