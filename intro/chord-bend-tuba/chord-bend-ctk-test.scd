(
// Chord bend parameters (customize as needed)
var startChord = [92, 92, 92];
var bendPercents = [20, 20, 20];
var bendDurations = [10.0, 7.5, 6.0];
var exprLevels = [100, 110, 120];
var exprDurations = [1.0, 1.2, 1.4];

// Make sure ~vstList and ~calcBendPercent are defined and populated

~chordBendCTK = CtkEvent(0.0, 1, 1, server: s);
~chordBendCTK.function_({ |event, group, envbus, inc, server|
    3.do { |i|
        var vstKey = ("vsti" ++ i).asSymbol;
        var vst = ~vstList[vstKey];
        var bendValue = ~calcBendPercent.value(bendPercents[i]);
        var note = startChord[i];
        var bendDur = bendDurations[i];
        var exprLevel = exprLevels[i];
        var exprDur = exprDurations[i];

        if(vst.notNil) {
            // Send noteOn to VST
            vst.midi.noteOn(i, note, 100);

            // Start bend envelope synth (will send OSC to bend handler)
            Synth(\BendEnvelope, [
                \start, 8192,         // Center
                \peak, bendValue,     // Calculated bend
                \end, 8192,           // Return to center
                \peakTime, bendDur,   // Time to reach peak
                \returnTime, 0.5,     // Time to return (customize as needed)
                \chanIndex, i
            ]);

            // Start expression envelope synth (optional)
            Synth(\ExpressionEnvelope, [
                \start, 0,
                \peak, exprLevel,
                \end, 0,
                \attackTime, exprDur,
                \releaseTime, 0.5,
                \chanIndex, i,
                \ccNum, 17
            ]);

            // Schedule noteOff after bend + return duration
            Routine({
                (bendDur + 0.5).wait;
                vst.midi.noteOff(i, note, 0);
            }).play;
        } {
            ("VST not found for tuba " ++ i).postln;
        }
    };
    event.next_(nil); // Only run once
});
)
~chordBendCTK.play;
~chordBendCTK.stop;
