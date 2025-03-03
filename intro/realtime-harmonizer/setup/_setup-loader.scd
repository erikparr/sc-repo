(
Routine({
    // Define the setup directory path relative to this file
    ~setupDir = PathName(thisProcess.nowExecutingPath).pathOnly;
    ~projectDir = ~setupDir.dirname;  // Get parent directory
    ~libDir = ~projectDir +/+ "lib";  // Get lib directory

    // Load lib files first
    [
        "config.scd",
        "note-mapping.scd",
        "vst-controller.scd"
    ].do { |filename|
        var filepath = ~libDir +/+ filename;
        ("Loading lib file: " ++ filename).postln;
        filepath.load;
        0.1.wait;
    };

    // Then load setup files
    [
        "synths-setup.scd",
        "vstplugin-setup.scd",
        "midi-setup.scd"
    ].do { |filename|
        var filepath = ~setupDir +/+ filename;
        ("Loading setup file: " ++ filename).postln;
        filepath.load;
        0.1.wait;
    };

    ("Setup loader complete").postln;
}).play;
) 