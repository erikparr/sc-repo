(
// Create vstController prototype
~vstController = (
    vsts: Dictionary.new,
    synthObj: nil,  // renamed from synth to synthObj
    
    init: { |self, synthArg|
        self.vsts = Dictionary.new;
        self.synthObj = synthArg;
        self;  // Return self for method chaining
    },
    
    addVST: { |self, id, vst|
        self.vsts.put(id, vst);
        ("Added VST with ID: " ++ id).postln;  // Debug output
        self.vsts.postln;  // Debug: show all VSTs
    },
    
    playNote: { |self, vstIndex, note, velocity, channel=0|
        var vstId = ('vsti' ++ vstIndex).asSymbol;
        ("Playing note on VST " ++ vstId ++ ": " ++ note).postln;  // Debug output
        if(self.vsts[vstId].notNil) {
            self.vsts[vstId].midi.noteOn(channel, note, velocity);
        } {
            ("VST " ++ vstId ++ " not found!").postln;  // Debug output
        };
    },
    
    releaseNote: { |self, vstIndex, note, channel=0|
        var vstId = ('vsti' ++ vstIndex).asSymbol;
        if(self.vsts[vstId].notNil) {
            self.vsts[vstId].midi.noteOff(channel, note, 0);
        };
    },
    
    handleError: { |self, error|
        ("VST Error: " ++ error).postln;
    },
    
    checkVST: { |self, vstIndex|
        if(vstIndex >= self.vsts.size) {
            self.handleError("VST index out of range");
            false;
        } {
            true;
        };
    }
);
) 