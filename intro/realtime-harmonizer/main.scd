(
Routine({
    // Load setup files
    (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;
    
    // Wait for setup to complete
    2.wait;
    
    // Verify noteMapper exists
    if(~noteMapper.isNil) {
        "Error: Note mapper not initialized!".postln;
    } {
        // Configure note mappings
        ~noteMapper.addMapping(60, [64, 67, 71]);  // C4 triggers E4, G4, B4
        ~noteMapper.addMapping(62, [65, 69, 72]);  // D4 triggers F4, A4, C5
        ~noteMapper.setDelayTime(~config.defaultDelayTime);
        
        // Print current mappings
        "Current note mappings:".postln;
        ~noteMapper.mappings.postln;
    };

    ("Setup complete. Ready for MIDI input.").postln;
}).play;
)

// To stop and cleanup
// ~cleanup.value; 