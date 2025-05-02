~oscFunc.free;
~expressionFunc.free;
~triggerResponder.free;
// OSC Function for pitch bend with more debugging
~oscFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    var vstKey = (\vsti ++ chanIndex).asSymbol;

    // Add logging for debugging (every 20 messages to avoid flooding)
    if(~logCounter.isNil) { ~logCounter = 0 };
    ~logCounter = ~logCounter + 1;
	// if(~logCounter % 20 == 0) {
	// 	"Bend OSC: chan: %, bend: %".format(chanIndex, bendValue).postln;
	// };
	//
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

// Add OSC responder for expression control
~expressionFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger; // This is now the VST index
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var vstKey = (\vsti ++ chanIndex).asSymbol;

    if(~vstList[vstKey].notNil) {
        // Here we use a fixed MIDI channel (0) regardless of the VST index
        ~vstList[vstKey].midi.control(0, ccNum, exprValue);
   
    if(~logCounter.isNil) { ~logCounter = 0 };
    ~logCounter = ~logCounter + 1;

        // Debug logging (uncomment for debugging)
		// if(~logCounter % 20 == 0) {
		// 	"Expression OSC: chan: %, cc: %, value: %".format(chanIndex, ccNum, exprValue).postln;
		// };
    };
}, '/expression', s.addr);

