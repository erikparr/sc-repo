// ==================== CHORD BEND WITH MIDICONTROLLER ====================
// This file adds MIDIController integration to control the looping chord bend system

// Load the main chord bend system
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "chord-bend-independent.scd").load;

// Ensure everything is reset
~cleanupChordBend.value;

// Initialize parameter ranges and mappings
(
// Base values that will be controlled by the physical sliders/knobs
~baseParams = (
    // Bend parameters
    bendPercent: [20, 25, 30],           // Base bend percentages
    bendDuration: [1.0, 1.2, 1.4],       // Base bend durations
    returnDuration: [1.0, 1.2, 1.4],     // Base return durations

    // Expression parameters
    exprCC: [17, 17, 17],                // Expression CC numbers
    exprStart: [30, 30, 30],             // Base expression start levels
    exprAttack: [0.3, 0.3, 0.3],         // Base expression attack times
    exprPeak: [100, 100, 100],           // Base expression peak levels
    exprRelease: [0.7, 0.7, 0.7],        // Base expression release times
    exprEnd: [30, 30, 30],               // Base expression end levels

    // Global parameters
    loopDuration: 4.0,                   // Base loop duration in seconds
    delayTime: 0.0,                      // Base delay time (before bend/expression)
    offsetFactor: 0.0                    // Timing offset factor between instances
);

// Initialize values with safe defaults
~lastOffsetFactor = 0;
~baseDelayTime = 0;
~offsetFactor = 0;
~delayTimes = [0, 0, 0];
~loopDuration = 4.0; // Safe default loop duration
~bendDurations = [1.0, 1.0, 1.0]; // Safe default bend durations
~returnDurations = [1.0, 1.0, 1.0]; // Safe default return durations
~exprAttackTimes = [0.3, 0.3, 0.3]; // Safe default attack times
~exprReleaseTimes = [0.7, 0.7, 0.7]; // Safe default release times

// Access the CC values from your sliders
~slider1Val = 0; // CC 0
~slider2Val = 0; // CC 1
~slider3Val = 0; // CC 2
~slider4Val = 0; // CC 3
~slider5Val = 0; // CC 4
~slider6Val = 0; // CC 5
~slider7Val = 0; // CC 6 - Delay time before bend/expression (0-127 -> 0.0-2.0 seconds)
~slider8Val = 0; // CC 7 - Offset factor between tubas (0-127 -> 0.0-1.0)

// Define parameter mapping function (called by control routine)
~updateParamsFromController = {
    // Access slider values directly from the MIDIController
    // Note: sliderValues array directly contains 0-127 values for sliders (CC 0-7)
    var slider1 = ~midiController.sliderValues[0] ? 0; // First slider (CC 0)
    var slider2 = ~midiController.sliderValues[1] ? 0; // Second slider (CC 1)
    var slider3 = ~midiController.sliderValues[2] ? 0; // Third slider (CC 2)
    var slider4 = ~midiController.sliderValues[3] ? 0; // Fourth slider (CC 3)
    var slider5 = ~midiController.sliderValues[4] ? 0; // Fifth slider (CC 4)
    var slider6 = ~midiController.sliderValues[5] ? 0; // Sixth slider (CC 5)
    var slider7 = ~midiController.sliderValues[6] ? 0; // Seventh slider (CC 6)
    var slider8 = ~midiController.sliderValues[7] ? 0; // Eighth slider (CC 7)

    // Map sliders to chord bend parameters

    // SLIDER 1 (CC 0): Bend percentage for all tubas (0-127 → 5-100%)
    ~bendPercents = Array.fill(3, {
        slider1.linlin(0, 127, 1, 30)
    });

    // SLIDER 2 (CC 1): Bend duration for all tubas (0-127 → 0.1-5.0 seconds)
    // Ensure minimum value of 0.1 seconds
    ~bendDurations = Array.fill(3, {
        slider2.linlin(0, 127, 0.1, 5.0).max(0.1)
    });

    // SLIDER 3 (CC 2): Return duration for all tubas (0-127 → 0.1-5.0 seconds)
    // Ensure minimum value of 0.1 seconds
    ~returnDurations = Array.fill(3, {
        slider3.linlin(0, 127, 0.1, 5.0).max(0.1)
    });

    // SLIDER 4 (CC 3): Overall loop duration (0-127 → 0.5-10.0 seconds)
    // Ensure minimum value of 0.5 seconds for loop duration
    ~loopDuration = slider4.linlin(0, 127, 0.5, 5.0).max(0.5);

    // SLIDER 5 (CC 4): Expression start level for all tubas (0-127 → 0-127)
    ~exprStartLevels = Array.fill(3, {
        slider5.asInteger
    });

    // SLIDER 6 (CC 5): Expression peak level for all tubas (0-127 → 0-127)
    ~exprPeakLevels = Array.fill(3, {
        slider6.asInteger
    });

    // SLIDER 7 (CC 6): Delay time before bend/expression (0-127 → 0.01-2.0 seconds)
    // Important: Ensure delay time is at least 0.01 seconds, never zero
    ~baseDelayTime = slider7.linlin(0, 127, 0.01, 2.0);

    // SLIDER 8 (CC 7): Offset factor between tubas (0-127 → 0.0-1.0)
    ~offsetFactor = slider8.linlin(0, 127, 0.0, 1.0);

    // Initialize lastOffsetFactor if nil
    if(~lastOffsetFactor.isNil) { ~lastOffsetFactor = 0 };

    // Calculate individual delay times for each tuba based on offset factor
    ~delayTimes = Array.fill(3, { |i|
        var instanceOffset;

        // Calculate the offset for this instance as a proportion of the delay time
        // i=0: offset=0 (always starts immediately)
        // i=1: offset ranges from 0 (at factor=0) to 0.5*delayTime (at factor=1)
        // i=2: offset ranges from 0 (at factor=0) to 1.0*delayTime (at factor=1)
        instanceOffset = (i / 2.0) * (~offsetFactor ? 0) * (~baseDelayTime ? 0.01);

        // Return the final delay time for this instance, ensuring at least 0.01 seconds
        (~baseDelayTime ? 0.01) + instanceOffset;
    });

    // DEBUG: Output the calculated delay times when offset factor changes significantly
    if ((~offsetFactor - (~lastOffsetFactor ? 0)).abs > 0.1) {
        "Delay times updated: Base=%, Offset Factor=%, Times=%"
        .format(~baseDelayTime, ~offsetFactor, ~delayTimes).postln;
        ~lastOffsetFactor = ~offsetFactor;
    };

    // Expression attack and release times with minimum values to prevent zero-time envelopes
    ~exprAttackTimes = Array.fill(3, {
        slider7.linlin(0, 127, 0.05, 3.0).max(0.05)
    });

    ~exprReleaseTimes = Array.fill(3, {
        slider8.linlin(0, 127, 0.05, 3.0).max(0.05)
    });

    // Expression end levels set to match start levels
    ~exprEndLevels = ~exprStartLevels;

    // Debug output (uncomment for testing)
    // "Parameters updated from MIDIController sliders".postln;
};

// Initialize default curve shapes
~bendCurves = [\sin, \sin, \sin];
~returnCurves = [\sin, \sin, \sin];
~delayCurves = [\lin, \lin, \lin];  // Default linear curves for delay segment


// ==================== SETUP MIDICONTROLLER INTEGRATION ====================
// Create a function to set up MIDIController
~setupMIDIController = {
    "Setting up MIDIController for chord bend...".postln;

    // Check if MIDIController already exists from midi-setup.scd
    if(~midiController.isNil) {
        "Warning: No existing MIDIController found. Creating a new one...".postln;
        // Create a MIDIController instance only if it doesn't exist
        ~midiController = MIDIController(~vstList, nil, nil, 8, 0, true);

        // Set multi-instrument and multi-channel modes
        ~midiController.setMultiInstrumentMode(true);
        ~midiController.setMultiChannelMode(true);

        // Disable note handling in MIDIController (we'll handle this ourselves)
        ~midiController.setNoteHandlingEnabled(false);
    } {
        "Using existing MIDIController instance from midi-setup.scd".postln;
    };

    // Create a control routine that continuously updates parameters
    ~controlRoutine = Routine({
        inf.do {
            ~updateParamsFromController.value;
            0.05.wait; // 20Hz update rate
        }
    });

    // Start the control routine
    ~controlRoutine.play;

    // Add debug output to check slider values
    ~debugSliderValues = Routine({
        5.do {
            "Current slider values:".postln;
            8.do { |i|
                "Slider % (CC %): %".format(i+1, i, ~midiController.sliderValues[i]).postln;
            };
            1.wait;
        };
    });
    ~debugSliderValues.play;

    "MIDIController setup complete. Physical sliders are now mapped to chord bend parameters.".postln;
    "Slider 1 (CC 0): Bend percentage (all tubas)".postln;
    "Slider 2 (CC 1): Bend duration (all tubas)".postln;
    "Slider 3 (CC 2): Return duration (all tubas)".postln;
    "Slider 4 (CC 3): Loop duration (global)".postln;
    "Slider 5 (CC 4): Expression start level (all tubas)".postln;
    "Slider 6 (CC 5): Expression peak level (all tubas)".postln;
    "Slider 7 (CC 6): Delay time before bend/expression (all tubas)".postln;
    "Slider 8 (CC 7): Offset factor (0=all simultaneous, 127=fully staggered)".postln;
};

// Setup MIDIController
~setupMIDIController.value;
)

// ==================== REALTIME LOOPING WITH MIDICONTROLLER ====================
(
// Enhanced looping system that updates parameter values on each cycle
~setupControllerLoopingBend = {
    var loopingSynths = Array.newClear(3);
    var loopingExprSynths = Array.newClear(3);
    var activeNotes = Array.newClear(3);
    var isRunning = false;
    var cycleCount = 0;
    var safeLoopDuration;

    // Initialize variables to track next update time
    var nextUpdateTime = 0;

    // Task to start/stop and update the looping bend
    ~controllerLoopingTask = Task({
        var targetBends = Array.newClear(3);
        var vstKey, vst;

        // First update parameters from controller
        ~updateParamsFromController.value;

        // Set a safe loop duration
        safeLoopDuration = (~loopDuration ? 4.0).max(0.5);

        if(isRunning) {
            "Stopping controller looping bend...".postln;

            // Free all synths
            loopingSynths.do { |synth| if(synth.notNil) { synth.free } };
            loopingExprSynths.do { |synth| if(synth.notNil) { synth.free } };

            // Turn off all notes
            activeNotes.do { |noteData|
                if(noteData.notNil) {
                    var vstIndex = noteData[0], note = noteData[1], vst = noteData[2];
                    vst.midi.noteOff(vstIndex, note, 0);
                    "Turned off note % on tuba %".format(note, vstIndex).postln;
                };
            };

            // Reset all bends to center
            3.do { |vstIndex|
                vstKey = (\vsti ++ vstIndex).asSymbol;
                vst = ~vstList[vstKey];
                if(vst.notNil) {
                    vst.midi.bend(vstIndex, 8192);  // Center position
                    "Reset bend for tuba % to center".format(vstIndex).postln;
                };
            };

            isRunning = false;
            "Controller looping bend stopped.".postln;
            ^this;
        };

        "Starting controller looping bend...".postln;
        "Using start chord: %".format(~startChord).postln;
        "Using peak bend percentages: %".format(~bendPercents).postln;
        "Using loop duration: % seconds".format(safeLoopDuration).postln;
        "Using delay times: %".format(~delayTimes).postln;

        isRunning = true;
        cycleCount = 0;

        // Pre-calculate all bend values and store in array
        3.do { |i|
            targetBends[i] = ~calcBendPercent.value(~bendPercents[i]);
            "Pre-calculated bend for tuba %: %".format(i, targetBends[i]).postln;
        };

        // Reset all VSTs to center bend
        3.do { |vstIndex|
            vstKey = (\vsti ++ vstIndex).asSymbol;
            vst = ~vstList[vstKey];
            if(vst.notNil) {
                vst.midi.bend(vstIndex, 8192);  // Center position
                "Reset bend for % to center (8192)".format(vstKey).postln;
            } {
                "Warning: VST not found for %".format(vstKey).postln;
            };
        };

        // Short wait to ensure reset is applied
        0.1.wait;

        // Play notes and set up initial looping envelopes
        3.do { |vstIndex|
            vstKey = (\vsti ++ vstIndex).asSymbol;
            vst = ~vstList[vstKey];

            if(vst.notNil) {
                var startNote, bendPercent, bendDuration, returnDuration, delayTime;
                var totalEnvelopeDuration, scaleFactor;
                var exprCC, exprStartLevel, attackTime, peakLevel, releaseTime, exprEndLevel;

                startNote = ~startChord[vstIndex];
                bendPercent = ~bendPercents[vstIndex] ? 20;

                bendDuration = (~bendDurations[vstIndex] ? 1.0).max(0.1); // Ensure minimum duration
                returnDuration = (~returnDurations[vstIndex] ? 1.0).max(0.1); // Ensure minimum duration
                delayTime = (~delayTimes[vstIndex] ? 0.01).max(0.01); // Minimum 0.01 seconds

                // Check that durations don't add up to more than the total loop duration
                totalEnvelopeDuration = bendDuration + returnDuration + delayTime;
                if (totalEnvelopeDuration > safeLoopDuration) {
                    // Scale durations to fit within loop
                    scaleFactor = safeLoopDuration / totalEnvelopeDuration;
                    bendDuration = bendDuration * scaleFactor;
                    returnDuration = returnDuration * scaleFactor;
                    delayTime = delayTime * scaleFactor;
                    "Warning: Envelope times exceed loop duration. Scaling bend=%s, return=%s, delay=%s to fit in %s seconds"
                    .format(bendDuration, returnDuration, delayTime, safeLoopDuration).postln;
                };

                // Expression envelope parameters with defaults and minimums
                exprCC = ~exprCC[vstIndex] ? 17;
                exprStartLevel = ~exprStartLevels[vstIndex] ? 30;
                attackTime = (~exprAttackTimes[vstIndex] ? 0.3).max(0.05); // Minimum 0.05 seconds
                peakLevel = ~exprPeakLevels[vstIndex] ? 100;
                releaseTime = (~exprReleaseTimes[vstIndex] ? 0.7).max(0.05); // Minimum 0.05 seconds
                exprEndLevel = ~exprEndLevels[vstIndex] ? 30;

                // Play the note
                vst.midi.noteOn(vstIndex, startNote, 100);  // Velocity 100
                activeNotes[vstIndex] = [vstIndex, startNote, vst];
                "Playing note % on tuba %".format(startNote, vstIndex).postln;

                // Start the looping bend envelope with delay
                loopingSynths[vstIndex] = Synth(\BendEnvelopeLoop, [
                    \start, 8192,                // Start at center
                    \peak, targetBends[vstIndex],           // Peak bend from calculation
                    \end, 8192,                  // Return to center
                    \delayTime, delayTime,       // Delay before starting bend
                    \peakTime, bendDuration,     // Time to reach peak
                    \returnTime, returnDuration, // Time to return from peak
                    \loopDuration, safeLoopDuration, // Total duration of one loop cycle (global)
                    \chanIndex, vstIndex,        // Which VST to control
                    \delayCurve, ~delayCurves[vstIndex] ? \lin,     // Curve for delay segment
                    \peakCurve, ~bendCurves[vstIndex] ? \sin,       // Curve for reaching peak
                    \returnCurve, ~returnCurves[vstIndex] ? \sin    // Curve for returning
                ]);

                // Start the looping expression envelope with delay
                loopingExprSynths[vstIndex] = Synth(\ExpressionEnvelopeLoop, [
                    \start, exprStartLevel,      // Use configured start level
                    \peak, peakLevel,            // Uses ~exprPeakLevels
                    \end, exprEndLevel,          // Use configured end level
                    \delayTime, delayTime,       // Delay before starting expression change
                    \attackTime, attackTime,     // Uses ~exprAttackTimes
                    \releaseTime, releaseTime,   // Uses ~exprReleaseTimes
                    \loopDuration, safeLoopDuration, // Total duration (global)
                    \chanIndex, vstIndex,
                    \ccNum, exprCC,
                    \delayCurve, ~delayCurves[vstIndex] ? \lin,     // Curve for delay segment
                    \attackCurve, ~bendCurves[vstIndex] ? \sin,
                    \releaseCurve, ~returnCurves[vstIndex] ? \sin
                ]);

                "Tuba %: Looping bend with delay=% sec, bend=% to %% (bend value: %) with % sec cycle"
                .format(vstIndex, delayTime, bendPercent, targetBends[vstIndex], safeLoopDuration).postln;

                "Tuba %: Looping expression with delay=% sec - CC: %, range: % to % to %"
                .format(vstIndex, delayTime, exprCC, exprStartLevel, peakLevel, exprEndLevel).postln;
            } {
                "Error: VST not found for tuba %".format(vstIndex).postln;
            };
        };

        // Set the time for the next parameter update
        nextUpdateTime = thisThread.seconds + safeLoopDuration;

        // Enter the main loop, checking for parameter updates
        while { isRunning } {
            var timeToNextUpdate;

            // Update the safe loop duration at each iteration
            safeLoopDuration = (~loopDuration ? 4.0).max(0.5);

            // Ensure nextUpdateTime is not nil before subtraction
            if(nextUpdateTime.notNil) {
                timeToNextUpdate = nextUpdateTime - thisThread.seconds;

                // If it's time for an update (or past time)
                if(timeToNextUpdate <= 0) {
                    cycleCount = cycleCount + 1;
                    "Cycle % complete. Updating parameters from controller...".format(cycleCount).postln;

                    // Update parameters from controller
                    ~updateParamsFromController.value;

                    // Update each synth with new parameter values
                    3.do { |vstIndex|
                        var targetBend, bendDuration, returnDuration, delayTime;
                        var totalEnvelopeDuration, scaleFactor;
                        var exprCC, exprStartLevel, attackTime, peakLevel, releaseTime, exprEndLevel;

                        targetBend = ~calcBendPercent.value(~bendPercents[vstIndex] ? 20);
                        bendDuration = (~bendDurations[vstIndex] ? 1.0).max(0.1);
                        returnDuration = (~returnDurations[vstIndex] ? 1.0).max(0.1);
                        delayTime = (~delayTimes[vstIndex] ? 0.01).max(0.01); // Minimum 0.01 seconds

                        // Check that durations don't add up to more than the total loop duration
                        totalEnvelopeDuration = bendDuration + returnDuration + delayTime;
                        if (totalEnvelopeDuration > safeLoopDuration) {
                            // Scale durations to fit within loop
                            scaleFactor = safeLoopDuration / totalEnvelopeDuration;
                            bendDuration = bendDuration * scaleFactor;
                            returnDuration = returnDuration * scaleFactor;
                            delayTime = delayTime * scaleFactor;
                        };

                        exprCC = ~exprCC[vstIndex] ? 17;
                        exprStartLevel = ~exprStartLevels[vstIndex] ? 30;
                        attackTime = (~exprAttackTimes[vstIndex] ? 0.3).max(0.05); // Minimum 0.05 seconds
                        peakLevel = ~exprPeakLevels[vstIndex] ? 100;
                        releaseTime = (~exprReleaseTimes[vstIndex] ? 0.7).max(0.05); // Minimum 0.05 seconds
                        exprEndLevel = ~exprEndLevels[vstIndex] ? 30;

                        // Update bend synth
                        if(loopingSynths[vstIndex].notNil) {
                            loopingSynths[vstIndex].set(
                                \peak, targetBend,
                                \delayTime, delayTime,
                                \peakTime, bendDuration,
                                \returnTime, returnDuration,
                                \loopDuration, safeLoopDuration
                            );
                        };

                        // Update expression synth
                        if(loopingExprSynths[vstIndex].notNil) {
                            loopingExprSynths[vstIndex].set(
                                \start, exprStartLevel,
                                \peak, peakLevel,
                                \end, exprEndLevel,
                                \delayTime, delayTime,
                                \attackTime, attackTime,
                                \releaseTime, releaseTime,
                                \loopDuration, safeLoopDuration
                            );
                        };
                    };

                    // Schedule the next update one loop duration from now
                    nextUpdateTime = thisThread.seconds + safeLoopDuration;
                };
            } {
                // If nextUpdateTime is nil, initialize it
                nextUpdateTime = thisThread.seconds + safeLoopDuration;
            };

            // Short wait before checking again
            0.1.wait;
        };
    });

    // Method to start the looping
    ~startControllerLooping = {
        "Debug: Starting controller looping function...".postln;
        "Debug: isRunning = %".format(isRunning).postln;

        if(isRunning) {
            "Controller looping bend already running. Stop it first.".postln;
        } {
            "Debug: About to reset and play the controllerLoopingTask...".postln;
            ~controllerLoopingTask.reset.play;
            "Debug: Task started.".postln;
        };
    };

    // Method to stop the looping
    ~stopControllerLooping = {
        if(isRunning) {
            ~controllerLoopingTask.reset.play;  // This will execute the stop logic
        } {
            "Controller looping bend not running.".postln;
        };
    };

    // Function to clean up
    ~cleanupControllerLooping = {
        // Stop both tasks
        ~controllerLoopingTask.stop;
        ~controlRoutine.stop;

        // Free MIDIController
        ~midiController.free;

        // Call existing cleanup
        ~cleanupChordBend.value;

        "Controller looping system cleaned up.".postln;
    };

    // Return the task for convenience
    ~controllerLoopingTask;
};

// Setup the controller looping system
~setupControllerLoopingBend.value;

"Controller looping system initialized.".postln;
"Use ~startControllerLooping.value; to start and ~stopControllerLooping.value; to stop".postln;
"Adjust physical sliders or knobs on your MIDI controller to change parameters in real-time.".postln;
"Slider/Knob 7 (CC 6/22) controls the delay time before bends/expression changes begin.".postln;
"Slider/Knob 8 (CC 7/23) controls how staggered the tubas are (0=all simultaneous, 127=fully staggered).".postln;
"Changes will take effect at the start of the next loop cycle.".postln;
)
// Start the chord bend system
~startControllerLooping.value;

// Stop the chord bend system
~stopControllerLooping.value;

// Clean up all resources when done
~cleanupControllerLooping.value;
~startControllerLooping.value;

// Stop the chord bend system
~stopControllerLooping.value;
