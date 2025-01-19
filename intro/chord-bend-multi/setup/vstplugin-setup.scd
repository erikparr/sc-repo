VSTPlugin.search(options: ( exclude: [ "/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3" ]));
2.5.wait;

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
~synth = Synth(\insertStrings, [\bus, 2]); // set to 2 and 3 for routing to reaper (set up routing in totalmix)
//strings
// ~cello1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~cello2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Cello 3.vst3", editor: true);
// ~dBass1 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
// ~viola1 = VSTPluginController(~synth, \vsti3).open("/Library/Audio/Plug-Ins/VST3/SWAM Viola 3.vst3", editor: true);
~dBass1 = VSTPluginController(~synth, \vsti0).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
~dBass2 = VSTPluginController(~synth, \vsti1).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
~dBass3 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
~dBass4 = VSTPluginController(~synth, \vsti3).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
~dBass5 = VSTPluginController(~synth, \vsti4).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
~dBass6 = VSTPluginController(~synth, \vsti5).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
// ~dBass4 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);
// ~dBass5 = VSTPluginController(~synth, \vsti2).open("/Library/Audio/Plug-Ins/VST3/SWAM Double Bass 3.vst3", editor: true);

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
// ~vstList.add(\vsti1 -> ~cello2);
// ~vstList.add(\vsti3 -> ~viola1);
~vstList.add(\vsti0 -> ~dBass1);
~vstList.add(\vsti1 -> ~dBass2);
~vstList.add(\vsti2 -> ~dBass3);
~vstList.add(\vsti3 -> ~dBass4);
~vstList.add(\vsti4 -> ~dBass5);
~vstList.add(\vsti5 -> ~dBass6);
// ~vstList.add(\vsti3 -> ~dBass4);
// ~vstList.add(\vsti4 -> ~dBass5);

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

	5.wait;
	// Open the editor window for the VST plugin controller
	~vstList.do { |item, i| item.editor; };
	