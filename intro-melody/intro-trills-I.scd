(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;

(
~activeTasks = List.new;
// Preset Dictionaries
~envPresets = Dictionary.new;
~melodyPresets = Dictionary.new;
~bowPresets = Dictionary.new;

// Function to switch envelope presets
~switchEnvPreset = { |presetName|
	var preset = ~envPresets[presetName];
	if(preset.notNil, {
		// Set envelope parameters from preset
		~envTotalDuration = preset.totalDuration;
		~envBreakpoint1Time = ~envTotalDuration * preset.breakpoint1;
		~envBreakpoint2Time = ~envTotalDuration * preset.breakpoint2;
		~envBreakpoint3Time = ~envTotalDuration * preset.breakpoint3;
		~envValue1 = preset.value1;
		~envValue2 = preset.value2;
		~envValue3 = preset.value3;
		~envValue4 = preset.value4;

		// Create new envelope
		~noteEnv = Env(
			[~envValue1, ~envValue2, ~envValue3, ~envValue4],
			[~envBreakpoint1Time,
				~envBreakpoint2Time - ~envBreakpoint1Time,
				~envBreakpoint3Time - ~envBreakpoint2Time],
			\sin
		);

		~noteEnvBuf = Buffer.sendCollection(s, ~noteEnv.discretize(~envTotalDuration * 20));
		["Switched to envelope preset", presetName].postln;
	}, {
		"Envelope preset not found!".postln;
	});
};

// Function to switch melody presets
~switchMelodyPreset = { |presetName|
	var preset = ~melodyPresets[presetName];
	if(preset.notNil, {
		~currentMelodySet = preset.melodies;
		~loopCount = preset.loopCount;
		~currentPreset = presetName;
		["Switched to melody preset", presetName, "with", ~loopCount, "loops"].postln;
	}, {
		"Melody preset not found!".postln;
	});
};

// Function to switch bow presets
~switchBowPreset = { |presetName|
	var preset = ~bowPresets[presetName];
	if(preset.notNil, {
		~bowHigh = preset.high;
		~bowLow = preset.low;
		["Switched to bow preset", presetName, "high:", ~bowHigh, "low:", ~bowLow].postln;
	}, {
		"Bow preset not found!".postln;
	});
};

// Global state variables
~bpm = 298;
~stop = false;
~randomMode = false;
~playOnce = true;
~isReverse = false;  // Controls CC direction

// Add single bow mode flag
~singleBowMode = false;  // Can be toggled true/false

// Main performance Task
~burst.isPlaying.if({ ~burst.stop });  // Stop if already playing
~burst = Task({
	// Local variables
	var ts, noteOnTime, startTime, lastEnvelopeCycle;
	var currentNotes, noteIndex, melodyIndex;
	var isLastIteration, noteID, shouldSwitchMelody;
	var startAbsoluteTime = 0;  // Tracks absolute time for envelope

	// Helper function for envelope value calculation
	var getEnvValue = { |currentTime|
		var absoluteTime = startAbsoluteTime + currentTime;
		var effectiveTime = min(absoluteTime, ~envTotalDuration);
		~noteEnv.at(effectiveTime)
	};

	// Helper function for rhythm calculation
	var getRhythmDuration = { |currentPreset, melodyIdx, noteIdx, defaultDuration|
		var rhythmValue;

		if(currentPreset.notNil) {
			if(currentPreset.includesKey(\rhythms) and: {
				currentPreset.rhythms.isKindOf(SequenceableCollection) and: {
					currentPreset.rhythms[melodyIdx].notNil and: {
						currentPreset.rhythms[melodyIdx][noteIdx].notNil
					}
				}
			}) {
				// Use detailed rhythm patterns if available and valid
				rhythmValue = currentPreset.rhythms[melodyIdx][noteIdx];
			} {
				// Use simple rhythm value if available
				rhythmValue = currentPreset.rhythm ? 1.0;
			};
		} {
			rhythmValue = 1.0;
		};

		// Ensure we return a valid number multiplied by the default duration
		(rhythmValue ? 1.0) * defaultDuration;
	};

	// Initialize performance variables
	ts = TimeSignature.new(2, 3, ~bpm);
	startTime = SystemClock.seconds;
	lastEnvelopeCycle = 0;

	// Performance state
	noteIndex = 0;
	melodyIndex = 0;
	isLastIteration = false;
	noteID = 0;
	shouldSwitchMelody = false;
	~currentLoops = 0;

	// Initialize synth dictionary and state
	~synthDict = Dictionary.new;
	~stop = false;
	currentNotes = ~currentMelodySet[melodyIndex][noteIndex];

	0.25.wait;  // Initial pause

	// Main performance loop
	loop({
		var currentTime = SystemClock.seconds - startTime;
		var currentEnvelopeCycle = (currentTime / ~envTotalDuration).floor;
		var ccStart, ccEnd, ccMid1, ccMid2;
		var bowHigh = ~bowHigh;
		var bowLow = ~bowLow;
		var currentPreset = ~melodyPresets[~currentPreset];
		var overlap = if(currentPreset.notNil and: { currentPreset.includesKey(\overlap) }) {
			currentPreset.overlap
		} {
			1
		};
		var noteOnTime = getEnvValue.(currentTime);
		var fullNoteDuration = noteOnTime;
		var waitTime, bowDuration, rhythmDuration;

		// Debug output
		[
			"----Debug Info----",
			"Current Time: %".format(currentTime.round(0.001)),
			"Envelope Value: %".format(noteOnTime.round(0.001)),
			"Total Duration: %".format(~envTotalDuration),
			"Overlap Factor: %".format(overlap),
		].do(_.postln);

		// Calculate rhythm duration
		rhythmDuration = getRhythmDuration.(currentPreset, melodyIndex, noteIndex, fullNoteDuration);
		waitTime = rhythmDuration * overlap;
		bowDuration = if(~singleBowMode) {
			var totalMelodyDuration = ~currentMelodySet[melodyIndex].size * fullNoteDuration;
			totalMelodyDuration
		} {
			rhythmDuration
		};

		["Wait Time: %".format(waitTime.round(0.001)),
		 "Full Note Duration: %".format(fullNoteDuration.round(0.001))].do(_.postln);

		// Check for cycle completion
		if(currentEnvelopeCycle > lastEnvelopeCycle) {
			if(~playOnce) { ~stop = true; };
			lastEnvelopeCycle = currentEnvelopeCycle;
			startAbsoluteTime = ~envTotalDuration;  // Lock at final envelope value
		};

		isLastIteration = ~stop && (noteIndex == (~currentMelodySet[melodyIndex].size - 1));

		// Calculate CC values based on direction
		ccStart = if(~isReverse, bowHigh, bowLow);
		ccMid1 = if(~isReverse, (bowHigh*0.6).round, (bowHigh*0.3).round);
		ccMid2 = if(~isReverse, (bowHigh*0.3).round, (bowHigh*0.6).round);
		ccEnd = if(~isReverse, bowLow, bowHigh);

		// Play current notes
		if(isLastIteration.not) {
			// Note-on messages
			currentNotes.do { |note|
					~vstList.do { |item|
						item.midi.noteOn(0, note, ~veloc);
					};
					"Playing Note: % at time: %".format(note, currentTime.round(0.001)).postln;
			};

			// Create new envelope synth with appropriate duration
			if(~singleBowMode.not or: { noteIndex == 0 }) {
				~synthDict.put(noteID, Synth(\ccEnvelopeLoop, [
					\gate, 1,
					\chanIndex, 0,
					\start, ccStart,
					\mid1, ccMid1,
					\mid2, ccMid2,
					\end, ccEnd,
					\dur, bowDuration
				]));
				~isReverse = ~isReverse.not;
			};

			// Schedule note-off independently
			fork {
				rhythmDuration.wait;  // Use rhythmDuration instead of fullNoteDuration
				currentNotes.do { |note|
					~vstList.do { |item|
						item.midi.noteOff(0, note, 0);
					};
					"Stopping Note: % at time: %".format(note, (currentTime + rhythmDuration).round(0.001)).postln;
				};
			};

			// Wait for the calculated duration before next note
			waitTime.wait;

			// Cleanup envelope synth
			if(~singleBowMode.not or: { noteIndex == (~currentMelodySet[melodyIndex].size - 1) }) {
				~synthDict.at(noteID).free;
				~synthDict.removeAt(noteID);
			};
		};

		noteID = noteID + 1;

		0.01.wait;  // Small wait to prevent timing issues

		// Handle melody switching
		if(noteIndex == 0) {  // At the start of each melody cycle
			~currentLoops = ~currentLoops + 1;
			if(~currentLoops >= ~loopCount) {  // After reaching loop count
				~currentLoops = 0;
				melodyIndex = (melodyIndex + 1) % ~currentMelodySet.size;  // Switch to next melody
				["Switching to melody", melodyIndex, "after", ~loopCount, "loops"].postln;

				// Check if we've gone through all melodies
				if(melodyIndex == 0) {
					~stop = true;  // Stop after all melodies have completed their loops
					["Completed all melody cycles"].postln;
				};
			};
		};

		// Advance to next note
		noteIndex = (noteIndex + 1) % (~currentMelodySet[melodyIndex].size);
		currentNotes = ~currentMelodySet[melodyIndex][noteIndex];
		ts.advance;

		if(~stop && isLastIteration) {
			~burst.stop;
		};
	});
});
~activeTasks.add(~burst);

// Define envelope presets
~envPresets.put(\preset1, (
	totalDuration: 24,
	breakpoint1: 0.05,    // 8% of total duration
	breakpoint2: 0.1,     // 90% of total duration
	breakpoint3: 0.666,     // 100% of total duration
	value1: 1,          // Initial value
	value2: 0.7,          // First target
	value3: 0.5,         // Second target
	value4: 0.6           // Final value
));

// gesture 1 for bass and cello
~envPresets.put(\gesture1, (
	totalDuration: 52,
	breakpoint1: 0.02,
	breakpoint2: 0.5,
	breakpoint3: 1.0,
	value1: 1,
	value2: 0.5,
	value3: 0.0666,
	value4: 3
));
//gesture 2 for cello
~envPresets.put(\gesture2bass, (
	totalDuration: 52,
	breakpoint1: 0.02,
	breakpoint2: 0.5,
	breakpoint3: 1.0,
	value1: 6,
	value2: 3,
	value3: 5,
	value4: 3
));

~envPresets.put(\flightThemeBow1, (
	totalDuration: 36,
	breakpoint1: 0.1,
	breakpoint2: 0.5,
	breakpoint3: 1.0,
	value1: 0.7,
	value2: 0.7,
	value3: 0.7,
	value4:  2.4,
));
~envPresets.put(\flightThemeBow2, (
	totalDuration: 64,
	breakpoint1: 0.1,
	breakpoint2: 0.5,
	breakpoint3: 1.0,
	value1: 1,
	value2: 1,
	value3: 1,
	value4: 1,
));

~envPresets.put(\preset3, (
	totalDuration: 24,
	breakpoint1: 0.5,
	breakpoint2: 0.6,
	breakpoint3: 1.0,
	value1: 8,
	value2: 8,
	value3: 8,
	value4: 8
));

// Define melody presets with a more flexible structure
~melodyPresets.put(\basic, (
	melodies: [
		[[73, 70]]
	],
	// Simple rhythm definition - single value applies to all notes
	rhythm: 1.0,
	loopCount: 24
));

~melodyPresets.put(\single, (
	melodies: [
		[[73, 70], [66]],
		[[73, 70], [66]]
	],
	rhythm: 1.0,
	loopCount: 32
));

~melodyPresets.put(\theme1, (
	melodies: [
		[[70, 65]]
	],
	rhythm: 2.0,
	loopCount: 32
));

~melodyPresets.put(\theme1bass, (
	melodies: [
		[[58, 53]]
	],
	rhythm: 4.0,
	loopCount: 32
));

~melodyPresets.put(\descending, (
	melodies: [
		[[69, 65], [60]],
		[[66, 65], [61]],
		[[70, 66], [63]],
		[[63, 60], [58]],
		[[60, 57], [53]]
	],
	rhythm: 1.0,
	loopCount: 2
));

// Complex rhythm pattern using detailed rhythms array
~melodyPresets.put(\flightTheme1, (
	melodies: [
		[[70], [65], [63]],
		[[70], [66], [61]]
	],
	// Detailed rhythm patterns per melody
	rhythm: 1.0,
	loopCount: 2,
	overlap: 0.25
));

~melodyPresets.put(\flightTheme2, (
	melodies: [
		[[53], [54], [58], [61]],  // First melody
		[[53], [54], [58], [63]],  // Second melody
		[[54], [58], [63], [65]],  // Third melody
		[[65], [63], [65], [70]]   // Fourth melody
	],
	// Detailed rhythm patterns per melody
	rhythms: 1.0,
	loopCount: 4,
	overlap: 0.25
));

// Define bow presets
~bowPresets.put(\normal, (
	high: 127,
	low: 0
));

~bowPresets.put(\gentle, (
	high: 90,
	low: 20
));

~bowPresets.put(\aggressive, (
	high: 127,
	low: 40
));

~bowPresets.put(\subtle, (
	high: 70,
	low: 30
));
)

// Performance controls
~switchEnvPreset.value(\flightThemeBow1);      // Initialize envelope
~switchMelodyPreset.value(\theme1bass); // Initialize melody set
~switchBowPreset.value(\normal);    // For softer playing
//ok
~burst.play;                           // Start performance
~burst.reset;                          // Reset if needed
~stop = true;                          // Stop performance

(
10.do { |note, index|
	var vstKey = (\vsti ++ index).asSymbol;
	var vst = ~vstList[vstKey];

	if(vst.notNil) {
		vst.midi.allNotesOff(index);  // Stop any playing notes
	};
};
)
