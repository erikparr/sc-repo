(
// Search for VST plugins
VSTPlugin.search(options: ( exclude: [ "/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3" ]));
2.5.wait;

// Initialize Dictionary for VST list
~vstList = Dictionary.new;

// Create main synth with bus routing to ADAT
~synth = Synth(\insertStrings, [\bus, 2]);  // set to 2 and 3 for routing to reaper

// Initialize VST instances
~dCello1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
~dCello2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
~dCello3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
~dCello4 = VSTPluginController(~synth, \vsti3).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
~dCello5 = VSTPluginController(~synth, \vsti4).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
~dCello6 = VSTPluginController(~synth, \vsti5).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);

// Add VSTs to dictionary
~vstList.add(\vsti0 -> ~dCello1);
~vstList.add(\vsti1 -> ~dCello2);
~vstList.add(\vsti2 -> ~dCello3);
~vstList.add(\vsti3 -> ~dCello4);
~vstList.add(\vsti4 -> ~dCello5);
~vstList.add(\vsti5 -> ~dCello6);

// Wait for VSTs to initialize
5.wait;

// Open editors
~vstList.do { |item, i| item.editor; };

("VST setup complete").postln;
)