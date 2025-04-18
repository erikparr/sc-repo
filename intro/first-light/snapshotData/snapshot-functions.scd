// Global functions for snapshot management
// These functions provide an easy interface to the MIDIController's snapshot functionality

// Save current slider and knob values as a snapshot
~saveSnapshot = { |name|
    ~midiController.saveSnapshot(name);
};

// Load a snapshot
~loadSnapshot = { |name|
    ~midiController.loadSnapshot(name);
};

// List all available snapshots
~listSnapshots = {
    ~midiController.listSnapshots;
};

// Delete a snapshot
~deleteSnapshot = { |name|
    ~midiController.deleteSnapshot(name);
};

// Save snapshots to a file in the snapshotData directory
~saveSnapshotsToFile = { |filename|
    ~midiController.saveSnapshotsToFile(filename);
};

// Load snapshots from a file in the snapshotData directory
~loadSnapshotsFromFile = { |filename|
    ~midiController.loadSnapshotsFromFile(filename);
};

// List all available snapshot files
~listSnapshotFiles = {
    ~midiController.listSnapshotFiles;
};

// Enable programmed mode with a specific snapshot
~enableProgrammedMode = { |snapshotName|
    ~midiController.setProgrammedMode(true, snapshotName);
};

// Disable programmed mode
~disableProgrammedMode = {
    ~midiController.setProgrammedMode(false);
};

// Get current snapshot name
~getCurrentSnapshot = {
    ~midiController.getCurrentSnapshot;
};

// Check if programmed mode is active
~isProgrammedMode = {
    ~midiController.isProgrammedMode;
};

// Get slider value with programmed mode support
~getSliderValue = { |index|
    ~midiController.getSliderValue(index);
};

// Get knob value with programmed mode support
~getKnobValue = { |index|
    ~midiController.getKnobValue(index);
};

// Example usage:
/*
// Save current slider and knob values as a snapshot
~saveSnapshot.value("my_snapshot");

// Load a snapshot
~loadSnapshot.value("my_snapshot");

// List all available snapshots
~listSnapshots.value();

// Delete a snapshot
~deleteSnapshot.value("my_snapshot");

// Save snapshots to a file
~saveSnapshotsToFile.value("my_snapshots.scd");

// Load snapshots from a file
~loadSnapshotsFromFile.value("my_snapshots.scd");

// List all available snapshot files
~listSnapshotFiles.value();

// Enable programmed mode with a specific snapshot
~enableProgrammedMode.value("my_snapshot");

// Disable programmed mode
~disableProgrammedMode.value();

// Get current snapshot name
~getCurrentSnapshot.value();

// Check if programmed mode is active
~isProgrammedMode.value();

// Get slider value with programmed mode support
~getSliderValue.value(0);  // Get value of first slider

// Get knob value with programmed mode support
~getKnobValue.value(0);  // Get value of first knob
*/ 