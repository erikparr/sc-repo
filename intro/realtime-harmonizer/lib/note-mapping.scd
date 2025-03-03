(
// Debug function
~debug = { |msg| ("DEBUG: " ++ msg).postln };

// Create noteMapper prototype
~noteMapper = (
    mappings: Dictionary.new,
    delayTime: 0.1,
    
    addMapping: { |self, inputNote, outputNotes|
        ~debug.value("Adding mapping:" + inputNote + "->" + outputNotes);
        self.mappings[inputNote] = outputNotes;
    },
    
    getOutputNotes: { |self, inputNote|
        ~debug.value("Getting output notes for:" + inputNote);
        self.mappings[inputNote];
    },
    
    setDelayTime: { |self, time|
        ~debug.value("Setting delay time to:" + time);
        self.delayTime = time;
    },
    
    init: { |self|
        ~debug.value("Initializing note mapper");
        self.mappings = Dictionary.new;
        self.delayTime = 0.1;
        self;
    }
);

// Initialize the noteMapper
~noteMapper = ~noteMapper.init;
~debug.value("Note mapper initialization complete");

// Verify initialization
if(~noteMapper.notNil) {
    ~debug.value("Note mapper exists");
    ~debug.value("Current mappings:" + ~noteMapper.mappings);
} {
    ~debug.value("ERROR: Note mapper is nil!");
};
)