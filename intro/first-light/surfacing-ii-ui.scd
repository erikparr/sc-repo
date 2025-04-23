(
// First, make sure we have the required Quark
Quarks.install("TabbedView2");
)

(
// Declare all variables at the beginning
var window, mainLayout, titleLayout, titleText, tabs;
var mainTab, mainLayout, playbackLayout, playButton, stopButton;
var tempoLayout, bpmSlider, bpmNumber, repSlider, repNumber;
var modeLayout, row, createModeToggle;
var offsetLayout, offsetSlider, offsetNumber;
var cycleLayout, cycleButtons;
var rampTab, rampLayout;
var startMultLayout, startMultSlider, startMultNumber;
var endMultLayout, endMultSlider, endMultNumber;
var curveLayout, curveSlider, curveNumber;
var minRestLayout, minRestSlider, minRestNumber;
var curveTypeLayout, curveTypeMenu;
var snapshotsTab, snapshotsLayout, snapshotsList, refreshSnapshots;
var snapshotControlsLayout, loadSnapshotButton, saveSnapshotButton, disableProgrammedButton;
var fileOperationsLayout, saveToFileButton, loadFromFileButton, listFilesButton;

// Create main window
window = Window("Surfacing II Controls", Rect(100, 100, 800, 600));
mainLayout = VLayout();
window.layout = mainLayout;

// Add title
titleLayout = HLayout();
titleText = StaticText().string_("SURFACING II").font_(Font("Arial", 24, true));
titleLayout.add(titleText, align: \center);
mainLayout.add(titleLayout);

// Create tabbed interface - either use built-in or fall back to simpler approach
try {
    // Try to use TabbedView2 if available
    tabs = TabbedView2(window, Rect(10, 50, 780, 540))
    .resize_(5)
    .tabPosition_(\top)
    .tabHeight_(30);
} {
    // If TabbedView2 isn't available, use a simpler approach with views and buttons
    "TabbedView2 not available, using fallback approach".postln;
    tabs = ();
    tabs.views = [];
    tabs.currentView = 0;
    tabs.tabContainer = CompositeView(window, Rect(10, 50, 780, 30));
    tabs.viewContainer = CompositeView(window, Rect(10, 80, 780, 510));
    tabs.tabContainer.layout = HLayout();
    
    tabs.add = {|self, name|
        var view = CompositeView(self.viewContainer, Rect(0, 0, 780, 510));
        var button = Button(self.tabContainer, Rect(0, 0, 100, 30))
            .states_([[name, Color.black, Color.white], [name, Color.white, Color.black]])
            .action_({|btn|
                self.views.do {|v, i| 
                    v.visible = (i == self.views.indexOf(view));
                    self.tabContainer.children[i].value = (i == self.views.indexOf(view)).asInteger;
                };
                self.currentView = self.views.indexOf(view);
            });
        self.tabContainer.layout.add(button);
        view.visible = (self.views.size == 0);
        button.value = (self.views.size == 0).asInteger;
        self.views = self.views.add(view);
        view;
    };
};

// ===== Main Controls Tab =====
mainTab = tabs.add("Main Controls");
mainLayout = VLayout();
mainTab.layout = mainLayout;

// Playback controls section
playbackLayout = HLayout();
playButton = Button().states_([["Play", Color.black, Color.green]]).action_({
    ~sketch.play;
});
stopButton = Button().states_([["Stop", Color.white, Color.red]]).action_({
    ~stop = true;
});

playbackLayout.add(playButton, stretch: 1);
playbackLayout.add(stopButton, stretch: 1);
mainLayout.add(playbackLayout);

// BPM and repetitions
tempoLayout = HLayout();
tempoLayout.add(StaticText().string_("BPM:"));
bpmSlider = Slider().orientation_(\horizontal)
.value_(~bpm.linlin(60, 400, 0, 1))
.action_({|sl| 
    ~bpm = sl.value.linlin(0, 1, 60, 400).round(0.1);
    bpmNumber.value = ~bpm;
});
bpmNumber = NumberBox().value_(~bpm)
.action_({|nb| 
    ~bpm = nb.value; 
    bpmSlider.value = ~bpm.linlin(60, 400, 0, 1);
});
tempoLayout.add(bpmSlider, stretch: 3);
tempoLayout.add(bpmNumber, stretch: 1);

tempoLayout.add(StaticText().string_("Repetitions:"));
repSlider = Slider().orientation_(\horizontal)
.value_(~repetitions.linlin(1, 10, 0, 1))
.action_({|sl| 
    ~repetitions = sl.value.linlin(0, 1, 1, 10).asInteger;
    repNumber.value = ~repetitions;
});
repNumber = NumberBox().value_(~repetitions)
.action_({|nb| 
    ~repetitions = nb.value.asInteger; 
    repSlider.value = ~repetitions.linlin(1, 10, 0, 1);
});
tempoLayout.add(repSlider, stretch: 3);
tempoLayout.add(repNumber, stretch: 1);
mainLayout.add(tempoLayout);

// Mode toggles section
modeLayout = GridLayout();
row = 0;

// Helper function for creating mode toggles
createModeToggle = {|label, varName, row, col|
    var checkbox = CheckBox().string_(label)
    .value_(currentEnvironment[varName])
    .action_({|cb| 
        currentEnvironment[varName] = cb.value;
        ["Setting", varName, "to", cb.value].postln;
    });
    modeLayout.add(checkbox, row, col, align: \left);
};

createModeToggle.("Melody Rest Mode", \melodyRestMode, row, 0);
createModeToggle.("Fermata Mode", \fermataMode, row, 1);
row = row + 1;
createModeToggle.("Ramp Tempo Mode", \rampTempoMode, row, 0);
createModeToggle.("Velocity Multiply Mode", \velocityMultiplyMode, row, 1);
row = row + 1;
createModeToggle.("Note Offset Mode", \noteOffsetMode, row, 0);
createModeToggle.("Remove Last Mode", \removeLastMode, row, 1);

mainLayout.add(modeLayout);

// Note Offset control
offsetLayout = HLayout();
offsetLayout.add(StaticText().string_("Note Offset:"));
offsetSlider = Slider().orientation_(\horizontal)
.value_(~noteOffset.linlin(-24, 24, 0, 1))
.action_({|sl| 
    ~noteOffset = sl.value.linlin(0, 1, -24, 24).round.asInteger;
    offsetNumber.value = ~noteOffset;
});
offsetNumber = NumberBox().value_(~noteOffset)
.action_({|nb| 
    ~noteOffset = nb.value.asInteger; 
    offsetSlider.value = ~noteOffset.linlin(-24, 24, 0, 1);
});
offsetLayout.add(offsetSlider, stretch: 3);
offsetLayout.add(offsetNumber, stretch: 1);
mainLayout.add(offsetLayout);

// Development cycles section
cycleLayout = HLayout();
cycleLayout.add(StaticText().string_("Development Cycle:"));
cycleButtons = 5.collect({|i|
    var btn = Button()
    .states_([[i+1, Color.black, Color.white]])
    .action_({
        ~switchCycle.value(i+1);
    });
    cycleLayout.add(btn);
    btn;
});
mainLayout.add(cycleLayout);

// ===== Tempo Ramp Tab =====
rampTab = tabs.add("Tempo Ramp");
rampLayout = VLayout();
rampTab.layout = rampLayout;

// Ramp Start Multiplier
startMultLayout = HLayout();
startMultLayout.add(StaticText().string_("Ramp Start Multiplier:"));
startMultSlider = Slider().orientation_(\horizontal)
.value_(~rampTempoStartMult.linlin(0.01, 5, 0, 1))
.action_({|sl| 
    ~rampTempoStartMult = sl.value.linlin(0, 1, 0.01, 5).round(0.01);
    startMultNumber.value = ~rampTempoStartMult;
});
startMultNumber = NumberBox().value_(~rampTempoStartMult)
.action_({|nb| 
    ~rampTempoStartMult = nb.value; 
    startMultSlider.value = ~rampTempoStartMult.linlin(0.01, 5, 0, 1);
});
startMultLayout.add(startMultSlider, stretch: 3);
startMultLayout.add(startMultNumber, stretch: 1);
rampLayout.add(startMultLayout);

// Ramp End Multiplier
endMultLayout = HLayout();
endMultLayout.add(StaticText().string_("Ramp End Multiplier:"));
endMultSlider = Slider().orientation_(\horizontal)
.value_(~rampTempoEndMult.linlin(0.01, 10, 0, 1))
.action_({|sl| 
    ~rampTempoEndMult = sl.value.linlin(0, 1, 0.01, 10).round(0.01);
    endMultNumber.value = ~rampTempoEndMult;
});
endMultNumber = NumberBox().value_(~rampTempoEndMult)
.action_({|nb| 
    ~rampTempoEndMult = nb.value; 
    endMultSlider.value = ~rampTempoEndMult.linlin(0.01, 10, 0, 1);
});
endMultLayout.add(endMultSlider, stretch: 3);
endMultLayout.add(endMultNumber, stretch: 1);
rampLayout.add(endMultLayout);

// Ramp Curve
curveLayout = HLayout();
curveLayout.add(StaticText().string_("Ramp Curve:"));
curveSlider = Slider().orientation_(\horizontal)
.value_(~rampTempoCurve.linlin(-5, 5, 0, 1))
.action_({|sl| 
    ~rampTempoCurve = sl.value.linlin(0, 1, -5, 5).round(0.1);
    curveNumber.value = ~rampTempoCurve;
});
curveNumber = NumberBox().value_(~rampTempoCurve)
.action_({|nb| 
    ~rampTempoCurve = nb.value; 
    curveSlider.value = ~rampTempoCurve.linlin(-5, 5, 0, 1);
});
curveLayout.add(curveSlider, stretch: 3);
curveLayout.add(curveNumber, stretch: 1);
rampLayout.add(curveLayout);

// Ramp Minimum Rest
minRestLayout = HLayout();
minRestLayout.add(StaticText().string_("Minimum Rest Time (s):"));
minRestSlider = Slider().orientation_(\horizontal)
.value_(~rampTempoMinRest.linlin(0.001, 1, 0, 1))
.action_({|sl| 
    ~rampTempoMinRest = sl.value.linlin(0, 1, 0.001, 1).round(0.001);
    minRestNumber.value = ~rampTempoMinRest;
});
minRestNumber = NumberBox().value_(~rampTempoMinRest)
.action_({|nb| 
    ~rampTempoMinRest = nb.value; 
    minRestSlider.value = ~rampTempoMinRest.linlin(0.001, 1, 0, 1);
});
minRestLayout.add(minRestSlider, stretch: 3);
minRestLayout.add(minRestNumber, stretch: 1);
rampLayout.add(minRestLayout);

// Curve Type
curveTypeLayout = HLayout();
curveTypeLayout.add(StaticText().string_("Curve Type:"));
curveTypeMenu = PopUpMenu()
.items_([\linear, \exponential, \sine, \cosine, \bell, \welch, \perlin, \step])
.action_({|menu|
    ~rampTempoCurveType = menu.items[menu.value];
    ["Setting curve type to", ~rampTempoCurveType].postln;
});
// Set initial selection
curveTypeMenu.value = curveTypeMenu.items.indexOf(~rampTempoCurveType) ? 0;
curveTypeLayout.add(curveTypeMenu);
rampLayout.add(curveTypeLayout);

// ===== Snapshots Tab =====
snapshotsTab = tabs.add("Snapshots");
snapshotsLayout = VLayout();
snapshotsTab.layout = snapshotsLayout;

// Snapshots list
snapshotsList = ListView().background_(Color.white);
refreshSnapshots = {
    defer {
        ~listSnapshots.value();
        var snapshots = if(~snapshots.notNil) { ~snapshots.keys.asArray.sort } { [] };
        snapshotsList.items = snapshots;
    };
};

snapshotsLayout.add(StaticText().string_("Available Snapshots:"));
snapshotsLayout.add(snapshotsList, stretch: 3);

// Snapshot controls
snapshotControlsLayout = HLayout();

loadSnapshotButton = Button().states_([["Load Selected", Color.black, Color.white]])
.action_({
    var selected = snapshotsList.value;
    if(selected.notNil) {
        var snapshotName = snapshotsList.items[selected];
        ~enableProgrammedMode.value(snapshotName);
        ["Loaded snapshot:", snapshotName].postln;
    };
});

saveSnapshotButton = Button().states_([["Save Current", Color.black, Color.white]])
.action_({
    var dialog = TextField()
    .string_("new-snapshot")
    .action_({|tf|
        ~saveSnapshot.value(tf.string);
        ["Saved snapshot:", tf.string].postln;
        refreshSnapshots.value();
        dialog.remove;
    });
    var saveWindow = Window("Save Snapshot", Rect(300, 300, 300, 60));
    saveWindow.layout = VLayout(
        StaticText().string_("Enter snapshot name:"),
        dialog
    );
    saveWindow.front;
});

disableProgrammedButton = Button().states_([["Disable Programmed Mode", Color.black, Color.white]])
.action_({
    ~disableProgrammedMode.value();
    "Disabled programmed mode".postln;
});

snapshotControlsLayout.add(loadSnapshotButton, stretch: 1);
snapshotControlsLayout.add(saveSnapshotButton, stretch: 1);
snapshotControlsLayout.add(disableProgrammedButton, stretch: 1);
snapshotsLayout.add(snapshotControlsLayout);

// File operations
fileOperationsLayout = HLayout();

saveToFileButton = Button().states_([["Save To File", Color.black, Color.white]])
.action_({
    var dialog = TextField()
    .string_("surfacing-ii-snap.scd")
    .action_({|tf|
        ~saveSnapshotsToFile.value(tf.string);
        ["Saved snapshots to file:", tf.string].postln;
        dialog.remove;
    });
    var saveWindow = Window("Save Snapshots File", Rect(300, 300, 300, 60));
    saveWindow.layout = VLayout(
        StaticText().string_("Enter file name:"),
        dialog
    );
    saveWindow.front;
});

loadFromFileButton = Button().states_([["Load From File", Color.black, Color.white]])
.action_({
    var dialog = TextField()
    .string_("surfacing-ii-snap.scd")
    .action_({|tf|
        ~loadSnapshotsFromFile.value(tf.string);
        ["Loaded snapshots from file:", tf.string].postln;
        refreshSnapshots.value();
        dialog.remove;
    });
    var loadWindow = Window("Load Snapshots File", Rect(300, 300, 300, 60));
    loadWindow.layout = VLayout(
        StaticText().string_("Enter file name:"),
        dialog
    );
    loadWindow.front;
});

listFilesButton = Button().states_([["List Snapshot Files", Color.black, Color.white]])
.action_({
    ~listSnapshotFiles.value();
});

fileOperationsLayout.add(saveToFileButton, stretch: 1);
fileOperationsLayout.add(loadFromFileButton, stretch: 1);
fileOperationsLayout.add(listFilesButton, stretch: 1);
snapshotsLayout.add(fileOperationsLayout);

// Refresh snapshots on load
refreshSnapshots.value();

// On window close, do any cleanup if needed
window.onClose = {
    // Any cleanup code here
};

// Open the window
window.front;
) 