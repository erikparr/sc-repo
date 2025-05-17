~oscFunc.free;
~expressionFunc.free;
~triggerResponder.free;
// OSC Function for pitch bend with more debugging
~oscFunc = OSCFunc({ |msg|
    var replyID, chanIndex, bendValue, vstKey, vstInstance;
    
    replyID = msg[2];
    chanIndex = msg[3].asInteger; // This is the VST index (0, 1, 2...)
    bendValue = msg[4].asInteger;
    vstKey = (\vsti ++ chanIndex).asSymbol;
    vstInstance = ~vstManager.getInstances[vstKey];

    // Periodic Logging for /bend OSC
    if(~bendLogCounter.isNil) { ~bendLogCounter = 0 };
    ~bendLogCounter = (~bendLogCounter + 1);
    if((~bendLogCounter % 50 == 1) || (bendValue != 8192) ) { // Log frequently if bend is active
         ["[/bend OSC]: VST Idx:", chanIndex, "BendVal:", bendValue, "VSTKey:", vstKey].postln;
    };
    if(vstInstance.notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        // Send bend on MIDI Channel 0, not chanIndex
        if((~bendLogCounter % 50 == 1) || (bendValue != 8192) ) {
            [" -> Applying bend to", vstKey, "on MIDI Chan 0"].postln;
        };
        vstInstance.midi.bend(0, bendValue); // Use MIDI channel 0
    } {
        if(vstInstance.isNil) {
            "Error: VST not found for key %".format(vstKey).postln;
        } {
            "Error: Invalid bend value: %".format(bendValue).postln;
        };
    };
}, '/bend', s.addr);

// Add OSC responder for expression control
~expressionFunc.free;
~expressionFunc = OSCFunc({ |msg|
    var replyID, chanIndex, ccNum, exprValue, vstKey, vstInstance;
    
    replyID = msg[2];
    chanIndex = msg[3].asInteger; // This is now the VST index
    ccNum = msg[4].asInteger;
    exprValue = msg[5].asInteger.clip(0, 127);
    vstKey = (\vsti ++ chanIndex).asSymbol;
    vstInstance = ~vstManager.getInstances[vstKey];
    if(vstInstance.notNil) {
        // Here we use a fixed MIDI channel (0) regardless of the VST index
        vstInstance.midi.control(0, ccNum, exprValue);

    if(~logCounter.isNil) { ~logCounter = 0 };
    ~logCounter = ~logCounter + 1;

        // Debug logging (uncomment for debugging)
		// if(~logCounter % 20 == 0) {
		// 	"Expression OSC: chan: %, cc: %, value: %".format(chanIndex, ccNum, exprValue).postln;
		// };
    };
}, '/expression', s.addr);

