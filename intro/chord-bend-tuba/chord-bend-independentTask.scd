// Clean up any existing OSC functions
~oscFunc.free;
~triggerResponder.free;
~expressionFunc.free;  // Add cleanup for new expression function

// Initialize counter for logging
~logCounter = 0;

// Direct test of bend messaging - add this to verify basic bend functionality
~testBendDirectly = {
    "Testing bend directly...".postln;
    3.do { |vstIndex|
        var vstKey = (\vsti ++ vstIndex).asSymbol;
        var vst = ~vstList[vstKey];
        if(vst.notNil) {
            // Test with an extreme bend value to ensure visibility
            var testBendValue = 12000;  // Far above center (8192)
            "Sending direct bend value: % to tuba %".format(testBendValue, vstIndex).postln;
            vst.midi.bend(vstIndex, testBendValue);
            0.5.wait;
            "Resetting bend value to center for tuba %".format(vstIndex).postln;
            vst.midi.bend(vstIndex, 8192);
            0.5.wait;
        } {
            "VST not found for tuba %".format(vstIndex).postln;
        };
    };
    "Direct bend test complete.".postln;
};

// OSC Function for pitch bend with more debugging
~oscFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    var vstKey = (\vsti ++ chanIndex).asSymbol;

    // Add logging for debugging (every 20 messages to avoid flooding)
    if(~logCounter.isNil) { ~logCounter = 0 };
    ~logCounter = ~logCounter + 1;
    if(~logCounter % 20 == 0) {
        "Bend OSC: chan: %, bend: %".format(chanIndex, bendValue).postln;
    };

    // Only send the bend if values are valid
    if(~vstList[vstKey].notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        ~vstList[vstKey].midi.bend(chanIndex, bendValue);
    } {
        // SuperCollector syntax for if-else
        if(~vstList[vstKey].isNil) {
            "Error: VST not found for key %".format(vstKey).postln;
        } {
            "Error: Invalid bend value: %".format(bendValue).postln;
        };
    };
}, '/bend', s.addr);

// Enhanced SynthDef for three-node bend envelope (start -> peak -> end)
SynthDef(\BendEnvelope, {
    arg start = 8192, peak = 8192, end = 8192,
        peakTime = 1, returnTime = 1,
        chanIndex = 0, peakCurve = \lin, returnCurve = \lin;

    var env = EnvGen.kr(
        Env(
            [start, peak, end],  // Three level points: start -> peak -> end
            [peakTime, returnTime],  // Two segments: reach peak, then return
            [peakCurve, returnCurve]  // Curve for each segment
        ),
        doneAction: 2
    );

    // Debug message at start
    SendTrig.kr(Impulse.kr(0), chanIndex, start);

    // Send values to OSC at high rate
    SendReply.kr(
        Impulse.kr(100),
        '/bend',
        [chanIndex, env],
        replyID: chanIndex
    );
}).add;

// Synth definition for ADSR expression envelope
SynthDef(\ExpressionEnvelope, {
    arg start=0, peak=100, end=0, 
        attackTime=0.5, releaseTime=0.5,
        chanIndex=0, ccNum=11, attackCurve=\sin, releaseCurve=\sin;
    var env;
    
    // Create a simpler three-point envelope like BendEnvelope
    env = EnvGen.kr(
        Env(
            [start, peak, end],  // Three level points: start -> peak -> end
            [attackTime, releaseTime],  // Two segments: reach peak, then release
            [attackCurve, releaseCurve]  // Curve for each segment
        ),
        doneAction: 2
    );
    
    // Debug message at start
    SendTrig.kr(Impulse.kr(0), chanIndex + 100, start);
    
    // Send the control signal via OSC at same rate as bend
    SendReply.kr(
        Impulse.kr(100),  // Send 100 times per second
        '/expression',
        [chanIndex, ccNum, env.round(1).clip(0, 127)]  // Round to integer and clip for MIDI CC
    );
}).add;

// LOOPING VERSIONS OF THE ENVELOPES
// --------------------------------

// Looping version of the bend envelope
SynthDef(\BendEnvelopeLoop, {
    arg start = 8192, peak = 8192, end = 8192,
        delayTime = 0, peakTime = 1, returnTime = 1, loopDuration = 2,
        chanIndex = 0, peakCurve = \lin, returnCurve = \lin, delayCurve = \lin,
        timeOffset = 0;  // Added parameter for instance-specific time offset
    
    var trigRate = 1 / loopDuration;  // Calculate trigger frequency from duration
    var trig = Impulse.kr(trigRate);  // Create trigger at specified rate
    var totalDelay = delayTime + timeOffset;  // Add offset to delay time
    var env = EnvGen.kr(
        Env(
            [start, start, peak, end],  // Four level points: start -> start -> peak -> end
            [totalDelay, peakTime, returnTime],  // Three segments: delay, reach peak, then return
            [delayCurve, peakCurve, returnCurve]  // Curve for each segment
        ),
        gate: Trig.kr(trig, totalDelay + peakTime + returnTime),  // Trigger envelope with proper duration
        doneAction: 0  // Don't free when done - keep looping
    );
    
    // Send debug trigger at start of each loop
    SendTrig.kr(trig, chanIndex, start);
    
    // Send values to OSC at high rate
    SendReply.kr(
        Impulse.kr(100),  // 100 Hz control rate
        '/bend',
        [chanIndex, env],
        replyID: chanIndex
    );
}).add;

// Looping version of the expression envelope
SynthDef(\ExpressionEnvelopeLoop, {
    arg start = 0, peak = 100, end = 0,
        delayTime = 0, attackTime = 0.5, releaseTime = 0.5, loopDuration = 2,
        chanIndex = 0, ccNum = 11, attackCurve = \sin, releaseCurve = \sin, delayCurve = \lin,
        timeOffset = 0;  // Added parameter for instance-specific time offset
    
    var trigRate = 1 / loopDuration;  // Calculate trigger frequency from duration
    var trig = Impulse.kr(trigRate);  // Create trigger at specified rate
    var totalDelay = delayTime + timeOffset;  // Add offset to delay time
    var env = EnvGen.kr(
        Env(
            [start, start, peak, end],  // Four level points: start -> start -> peak -> end
            [totalDelay, attackTime, releaseTime],  // Three segments: delay, reach peak, then release
            [delayCurve, attackCurve, releaseCurve]  // Curve for each segment
        ),
        gate: Trig.kr(trig, totalDelay + attackTime + releaseTime),  // Trigger envelope with proper duration
        doneAction: 0  // Don't free when done - keep looping
    );
    
    // Send debug trigger at start of each loop
    SendTrig.kr(trig, chanIndex + 100, start);
    
    // Send the control signal via OSC
    SendReply.kr(
        Impulse.kr(100),
        '/expression',
        [chanIndex, ccNum, env.round(1).clip(0, 127)],  // Round to integer and clip for MIDI CC
        replyID: chanIndex
    );
}).add;

// Add OSC responder for expression control
~expressionFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var vstKey = (\vsti ++ chanIndex).asSymbol;
    
    if(~vstList[vstKey].notNil) {
        ~vstList[vstKey].midi.control(chanIndex, ccNum, exprValue);
        
        // Debug logging (uncomment for debugging)
        if(~logCounter % 20 == 0) {
            "Expression OSC: chan: %, cc: %, value: %".format(chanIndex, ccNum, exprValue).postln;
        };
    };
}, '/expression', s.addr);

// Add trigger responder for debugging
~triggerResponder = OSCFunc({ |msg|
    var chanIndex = msg[2];
    var value = msg[3];
    "Bend starting for chan %: initial value %".format(chanIndex, value).postln;
}, '/tr', s.addr);

//
//Task
//
// Task for playing the chord with three-node envelope
~chordBendTask = Task({
    var activeNotes = List.new;
    var activeSynths = List.new;
    var activeExpressionSynths = List.new;  // Add list for expression synths
    var vstKey, vst;
    var targetBends = Array.newClear(3);
    var totalDurations = Array.newClear(3);
    var waitTime;

    "Starting chord transition...".postln;
    "Using start chord: %".format(~startChord).postln;
    "Using peak bend percentages: %".format(~bendPercents).postln;
    "Using end chord: %".format(~endChord).postln;

    // Pre-calculate all bend values and store in array
    3.do { |i|
        targetBends[i] = ~calcBendPercent.value(~bendPercents[i]);
        totalDurations[i] = ~bendDurations[i] + ~returnDurations[i];
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

    // Play notes and set up percentage-based bends
    3.do { |vstIndex|
        vstKey = (\vsti ++ vstIndex).asSymbol;
        vst = ~vstList[vstKey];

        if(vst.notNil) {
            var startNote = ~startChord[vstIndex];
            var endNote = ~endChord[vstIndex];
            var bendPercent = ~bendPercents[vstIndex];
            var bendDuration = ~bendDurations[vstIndex];
            var returnDuration = ~returnDurations[vstIndex];
            var bendCurve = ~bendCurves[vstIndex];
            var returnCurve = ~returnCurves[vstIndex];
            var targetBend = targetBends[vstIndex];
            
            // Expression envelope parameters from global arrays
            var exprCC = ~exprCC[vstIndex] ? 17;  // Default to CC 17 (dynamics) if not set
            var exprStartLevel = ~exprStartLevels[vstIndex] ? 0;  // Get start level
            var attackTime = ~exprAttackTimes[vstIndex] ? 0.1;
            var peakLevel = ~exprPeakLevels[vstIndex] ? 100;
            var releaseTime = ~exprReleaseTimes[vstIndex] ? (bendDuration + returnDuration - 0.5);
            var exprEndLevel = ~exprEndLevels[vstIndex] ? 0;  // Get end level

            // Double-check bend value isn't center (no bend)
            if(targetBend == 8192) {
                "Warning: Bend value is center (8192) for tuba %. No bend will occur."
                .format(vstIndex).postln;
            };

            // Play the note
            vst.midi.noteOn(vstIndex, startNote, 100);  // Velocity 100
            activeNotes.add([vstIndex, startNote, vst]);
            "Playing note % on tuba %".format(startNote, vstIndex).postln;

            // Start the three-node bend envelope
            activeSynths.add(
                Synth(\BendEnvelope, [
                    \start, 8192,              // Start at center
                    \peak, targetBend,         // Peak bend from calculation
                    \end, 8192,                // Return to center
                    \peakTime, bendDuration,   // Time to reach peak
                    \returnTime, returnDuration, // Time to return from peak
                    \chanIndex, vstIndex,      // Which VST to control
                    \peakCurve, bendCurve,     // Curve for reaching peak
                    \returnCurve, returnCurve  // Curve for returning
                ])
            );
            
            // Start the expression envelope
            activeExpressionSynths.add(
                Synth(\ExpressionEnvelope, [
                    \start, exprStartLevel,     // Use configured start level
                    \peak, peakLevel,          // Uses ~exprPeakLevels
                    \end, exprEndLevel,         // Use configured end level
                    \attackTime, attackTime,   // Uses ~exprAttackTimes
                    \releaseTime, releaseTime, // Uses ~exprReleaseTimes
                    \chanIndex, vstIndex,
                    \ccNum, exprCC,
                    \attackCurve, bendCurve,
                    \releaseCurve, returnCurve
                ])
            );

            // Print info with correct spacing and formatting
            "Tuba %: Bending note % by %% (bend value: %) over % sec with % curve, then returning over % sec with % curve"
            .format(
                vstIndex,
                startNote,
                bendPercent,
                targetBend,
                bendDuration,
                bendCurve,
                returnDuration,
                returnCurve
            ).postln;
            
            "Tuba %: Expression envelope - CC: %, start: %, peak: %, end: %, attack: %, release: %"
            .format(vstIndex, exprCC, exprStartLevel, peakLevel, exprEndLevel, attackTime, releaseTime).postln;
        } {
            "Error: VST not found for tuba %".format(vstIndex).postln;
        };
    };

    // Wait for longest total duration to complete
    waitTime = totalDurations.maxItem;
    "Waiting % seconds for full bend cycle to complete...".format(waitTime).postln;
    waitTime.wait;

    // Turn off all notes
    activeNotes.do { |noteData|
        var vstIndex, note, vst;
        #vstIndex, note, vst = noteData;
        if(vst.notNil) {
            vst.midi.noteOff(vstIndex, note, 0);
            "Turned off note % on tuba %".format(note, vstIndex).postln;
        };
    };
    
    // Release all expression synths by setting gate to 0
    activeExpressionSynths.do { |synth|
        synth.set(\gate, 0);
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

    "Chord transition complete.".postln;
    
    // Reset the task so it can be played again without re-evaluation
    thisThread.yieldAndReset;
});

// Change the default values in ~exprCC as well, if it exists elsewhere in the code
if(~exprCC.notNil) {
    ~exprCC = [17, 17, 17];  // Set default CCs to 17 for all tubas
    "Updated expression CC values to use dynamics controller (CC 17)".postln;
};

// Calculate bend value based on percentage from -100% to +100%
~calcBendPercent = {|percent|
    var semitones, unitsPerSemitone, bendValue;

    // Convert percentage (-100 to 100) to semitones (±12 semitones max)
    semitones = (percent / 100) * 12;

    // Calculate bend value
    unitsPerSemitone = 682;  // 8192/12 ≈ 682.67 units per semitone
    bendValue = 8192 + (semitones * unitsPerSemitone).asInteger;

    // Ensure bend value is within valid range
    bendValue = bendValue.clip(0, 16383);

    // Debug output
    "Bend calculation: %% = % semitones = bend value %"
    .format(percent, semitones, bendValue).postln;

    bendValue;
};
