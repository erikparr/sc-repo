(
// Define the setup directory path relative to this file
~setupDir = PathName(thisProcess.nowExecutingPath).pathOnly;

// List of setup files in desired loading order
~setupFiles = [
    "synths-setup.scd", //load first to set up synthdefs, buses etc
    "vstplugin-setup.scd",
    "midi-setup.scd",
    "osc-setup.scd",
    "../snapshotData/snapshot-functions.scd" // Load snapshot functions
];

// Load each setup file within a Routine
Routine({
    ~setupFiles.do { |filename|
        var filepath = ~setupDir +/+ filename;
        ("Loading setup file: " ++ filename).postln;
        filepath.load;
        0.1.wait; // Small wait between loads to ensure proper initialization
    };
}).play;
)
