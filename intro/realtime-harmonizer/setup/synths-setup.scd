(
// Set up audio routing
Server.default.options.numOutputBusChannels = 8;  // Ensure enough output channels

// Main SynthDef for VST string instruments
SynthDef(\insertStrings, { arg bus;
    var sig1, sig2, sig3, sig4, sig5, sig6;
    sig1 = In.ar(bus, 2);
    sig2 = In.ar(bus, 2);
    sig3 = In.ar(bus, 2);
    sig4 = In.ar(bus, 2);
    sig5 = In.ar(bus, 2);
    sig6 = In.ar(bus, 2);
    sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
    sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
    sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);
    sig4 = VSTPlugin.ar(sig4, 2, id: \vsti3);
    sig5 = VSTPlugin.ar(sig5, 2, id: \vsti4);
    sig6 = VSTPlugin.ar(sig6, 2, id: \vsti5);
    
    // Output to ADAT channels as defined in Babyface Pro manual
    ReplaceOut.ar(2, Mix.new([sig1, sig4]));  // ADAT 3/4
    ReplaceOut.ar(4, Mix.new([sig2, sig5]));  // ADAT 5/6
    ReplaceOut.ar(6, Mix.new([sig3, sig6]));  // ADAT 7/8
}).add;

// Wait for SynthDef to be added
s.sync;

("SynthDefs loaded").postln;
) 