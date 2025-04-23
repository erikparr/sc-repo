// Wrap the VST search in a proper routine
~searchVSTs = {
    Routine({
        "Searching for VST plugins...".postln;
VSTPlugin.search(options: ( exclude: [ "/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3" ]));
        "VST plugin search complete.".postln;
    }).play;
};

// Call the search function
~searchVSTs.value;

// ~synth = Synth(\insert3, [\bus, 0]);
// ~testfx = VSTPluginController(~synth, \vsti).open("/Library/Audio/Plug-Ins/VST3/Omnisphere.vst3", editor: true);
// ~routefx = VSTPluginController(~synth, \vstiRoute).open("/Library/Audio/Plug-Ins/VST3/Pigments.vst3");
// 1.wait;
// ~testfx.editor;
// ~routefx.editor;

// automate with Dictionary

// SWAM TO PIGMENTS ROUTING
~vstList = Dictionary.new;
// !! set to 0,1 channels for main output
// ~synth = Synth(\insert4, [\bus1, 0, \bus2, 1]);

// six instruments / 3 channels
// ~synth = Synth(\insertStrings, [\bus, 2]); // set to 2 and 3 for routing to reaper (set up routing in totalmix)
//strings

// four instruments / 2 channels
~synth = Synth(\insert3, [\bus, 2]); // set to 2 and 3 for routing to reaper (set up routing in totalmix)
//strings
// ~dCello1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~dCello2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~dCello3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~dCello4 = VSTPluginController(~synth, \vsti3).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~dCello5 = VSTPluginController(~synth, \vsti4).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~dCello6 = VSTPluginController(~synth, \vsti5).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
//
~tuba1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", editor: true);
~tuba2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", editor: true);
~tuba3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Tuba.vst3", editor: true);
~vstList.add(\vsti0 -> ~tuba1);
~vstList.add(\vsti1 -> ~tuba2);
~vstList.add(\vsti2 -> ~tuba3);
// ~dCello1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
// ~dCello2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
// ~dCello3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
// ~dCello4 = VSTPluginController(~synth, \vsti3).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
// ~dCello5 = VSTPluginController(~synth, \vsti4).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
// ~dCello6 = VSTPluginController(~synth, \vsti5).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
//
// ~dCello1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Flugelhorn.vst3", editor: true);
// ~dCello2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Flugelhorn Eb.vst3", editor: true);
// ~dCello3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Piccolo Trumpet.vst3", editor: true);
// ~dCello4 = VSTPluginController(~synth, \vsti3).open("/Library/Audio/Plug-Ins/VST3/SWAM Trumpet.vst3", editor: true);
// ~dCello5 = VSTPluginController(~synth, \vsti4).open("/Library/Audio/Plug-Ins/VST3/SWAM Trumpet C.vst3", editor: true);
// ~dCello6 = VSTPluginController(~synth, \vsti5).open("/Library/Audio/Plug-Ins/VST3/SWAM Trumpet.vst3", editor: true);

//Double reeds
// ~bassoon1 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Bassoon 3.vst3", editor: true);
// ~conBasson1 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Contrabassoon 3.vst3", editor: true);
// ~engHorn1 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM English Horn 3.vst3", editor: true);
// ~oboe1 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Oboe 3.vst3", editor: true);
// //clarinet
// ~oboe1 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Bass Clarinet 3.vst3", editor: true);
// ~oboe1 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Clarinet 3.vst3", editor: true);

// ~pigments = VSTPluginController(~synth, \vstiRoute).open("/Library/Audio/Plug-Ins/VST3/Pigments.vst3");
// ~neutone = VSTPluginController(~synth, \vstiRoute).open("/Library/Audio/Plug-Ins/VST3/Neutone FX.vst3");
// ~vstList.add(\vsti0 -> ~cello1);

// ~vstList.add(\vsti0 -> ~dCello1);
// ~vstList.add(\vsti1 -> ~dCello2);
// ~vstList.add(\vsti2 -> ~dCello3);
// ~vstList.add(\vsti3 -> ~dCello4);
// ~vstList.add(\vsti3 -> ~dCello5);
// ~vstList.add(\vsti4 -> ~dCello6);
// ~vstList.add(\vstiRoute ->  ~pigments);
// ~vstList.add(\vstiRoute ->  ~neutone);

// Clarinet
// ~vstList = Dictionary.new;
// ~synth = Synth(\insert4, [\bus1, 0, \bus2, 1]);
// ~clarinet = VSTPluginController(~synth, \vsti).open("/Library/Audio/Plug-Ins/VST3/Emulator II V.vst3", editor: true);
// ~vstList.add(\vsti -> ~clarinet);




// KONTAKT TO PIGMENTS ROUTING
// ~vstList = Dictionary.new;
// ~synth = Synth(\insert3, [\bus, 0]);
// ~vstList.add(\vsti -> VSTPluginController(~synth, \vsti).open("/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3", editor: true));
// ~vstList.add(\vstiRoute ->  VSTPluginController(~synth, \vstiRoute).open("/Library/Audio/Plug-Ins/VST3/Pigments.vst3"));
//
// OMNISPHERE TO PIGMENTS ROUTING
// ~vstList = Dictionary.new;
// ~synth = Synth(\insert3, [\bus, 0]);
// ~vstList.add(\vsti -> VSTPluginController(~synth, \vsti).open("/Library/Audio/Plug-Ins/VST3/Omnisphere.vst3", editor: true));
// ~vstList.add(\vstiRoute ->  VSTPluginController(~synth, \vstiRoute).open("/Library/Audio/Plug-Ins/VST3/Pigments.vst3"));



// Set the current program number for the VST plugin controller
// ~vsti = VSTPluginController(Synth(\insert, [\bus, 0])).open("/Library/Audio/Plug-Ins/VST3/Choreographs.vst3", editor: true);
// ~vsti = VSTPluginController(Synth(\insert, [\bus, 0])).open("Kontakt", editor: true);
// ~vsti = VSTPluginController(Synth(\insert, [\bus, 0])).open("/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3", editor: true);
// ~vsti = VSTPluginController(Synth(\insert, [\bus, 0])).open("/Library/Audio/Plug-Ins/VST3/Kontakt.vst3", editor: true);

    // just pigments vst
// ~synth = Synth(\insert3, [\bus, 2]);
// ~vstList.add(\vsti ->  VSTPluginController(~synth, \vsti).open("/Library/Audio/Plug-Ins/VST3/Pigments.vst3"));
	// ~vsti = VSTPluginController(Synth(\insert, [\bus, 0])).open("/Library/Audio/Plug-Ins/VST3/Analog Lab V.vst3", editor: true);
	// ~vsti = VSTPluginController(Synth(\insert, [\bus, 0])).open("Omnisphere", editor: true);

// Open editors after a delay
// Routine({
//     5.wait;
//     // Open the editor window for the VST plugin controller
//     ~vstList.do { |item, i| item.editor; };
// }).play;

// Alternative approach using defer
SystemClock.sched(5, {
    // Open the editor window for the VST plugin controller
    ~vstList.do { |item, i| item.editor; };
    nil;
});
	