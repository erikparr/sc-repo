// vstplugin-setup.scd - VST Manager Setup

// 1. Search for VSTs (same as original)
"Searching for VST plugins...".postln;
VSTPlugin.search(options: (exclude: ["/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3"]));
"VST plugin search complete.".postln;

// 2. Create synth (same as original)
~synth = Synth(\insert3, [\bus, 2]); // set to 2 and 3 for routing to reaper (set up routing in totalmix)

// 3. Initialize VSTManager
~vstManager = VSTManager.new(s);
"VSTManager initialized.".postln;

// 4. Add VST instances (matching original behavior)
fork {
    // Small delay to ensure VST search completes
    5.wait;
    
    // Add VSTs with same IDs and paths as original
    ~vstManager.addVST(\vsti0, ~synth, "/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", true);
    ~vstManager.addVST(\vsti1, ~synth, "/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", true);
    ~vstManager.addVST(\vsti2, ~synth, "/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", true);
    
    // Create a group that matches the original vstList behavior
    ~vstManager.createGroup(\vstList, [\vsti0, \vsti1, \vsti2]);
    
    // Open editors after delay (same as original)
    SystemClock.sched(5, {
        fork {
            ~vstManager.vstInstances.do { |inst| 
                inst.controller.editor;
                0.1.wait; // Small delay between opening editors
            };
        };
        nil;
    });
    
    "VSTManager setup complete with 3 SWAM Bass Tuba instances".postln;
};

// // Wrap the VST search in a proper routine
// ~searchVSTs = {
//     Routine({
//         "Searching for VST plugins...".postln;
//         VSTPlugin.search(options: ( exclude: [ "/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3" ]));
//         "VST plugin search complete.".postln;
//     }).play;
// };

// // Call the search function
// ~searchVSTs.value;

// // SWAM TO PIGMENTS ROUTING
// ~vstList = Dictionary.new;

// // four instruments / 2 channels
// ~synth = Synth(\insert3, [\bus, 2]); // set to 2 and 3 for routing to reaper (set up routing in totalmix)

// ~tuba1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", editor: true);
// ~tuba2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", editor: true);
// ~tuba3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", editor: true);
// ~vstList.add(\vsti0 -> ~tuba1);
// ~vstList.add(\vsti1 -> ~tuba2);
// ~vstList.add(\vsti2 -> ~tuba3);

// // Alternative approach using defer
// SystemClock.sched(5, {
//     // Open the editor window for the VST plugin controller
//     ~vstList.do { |item, i| item.editor; };
//     nil;
// });


// In your setup file: