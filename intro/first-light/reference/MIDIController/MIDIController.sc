MIDIController {
    var <sliderValues;
    var <knobValues;
    var <knobRanges;
    var <midiFuncs;
    var <vstList;
    var <oscNetAddr;
    var <glissandoMode;
    var <glissandoNoteMode;
    var <bendSynth;
    var <numNotesPlaying;
    var <velocity;
    var <numKnobs;
    var <startCC;
    var <controlRoutine;
    var <pollRate;
    var <debug;

    *new { |vstList, oscNetAddr, bendSynth = nil, numKnobs = 16, startCC = 0, debug = false|
        ^super.new.init(vstList, oscNetAddr, bendSynth, numKnobs, startCC, debug);
    }

    init { |inVstList, inOscNetAddr, inBendSynth, inNumKnobs, inStartCC, inDebug|
        debug = inDebug;
        
        this.debug("Initializing MIDIController");
        
        // Initialize MIDI client if not already initialized
        MIDIClient.initialized.not.if {
            MIDIClient.init;
        };
        
        // Connect to all available MIDI sources and destinations
        MIDIIn.connectAll;
        MIDIClient.destinations.do { |dest|
            this.debug("Connected to MIDI destination: %".format(dest.name));
        };
        
        vstList = inVstList;
        oscNetAddr = inOscNetAddr;
        bendSynth = inBendSynth;
        numKnobs = inNumKnobs;
        startCC = inStartCC;
        
        // Initialize arrays for both sliders and knobs
        sliderValues = Array.fill(8, 0);
        knobValues = Array.fill(8, 0);
        knobRanges = Array.fill(8, 0);
        midiFuncs = IdentityDictionary.new;
        numNotesPlaying = 0;
        velocity = 100;
        
        // Initialize modes as false by default
        glissandoMode = false;
        glissandoNoteMode = false;
        
        this.initMIDIFuncs;
    }

    initMIDIFuncs {
        // Note On
        midiFuncs[\noteOn] = MIDIFunc.noteOn({ |veloc, pitch, chan|
            chan = 0;
            
            // Only use bendSynth if it exists
            if(bendSynth.notNil) {
                bendSynth.set(\gate, 1, \start, 0, \end, 0, \dur, 0.0001);
                
                if(glissandoNoteMode) {
                    SystemClock.sched(knobValues[1], {
                        bendSynth.set(\gate, 1, \start, 0, \end, 8192, \dur, knobValues[0]);
                    });
                };
            };

            if(glissandoMode) {
                oscNetAddr.sendMsg('/glissOn', chan, pitch);
            } {
                vstList.do { |item| 
                    item.midi.noteOn(chan, pitch, velocity);
                };
                oscNetAddr.sendMsg('/keyOn', chan, pitch);
            };
            
            numNotesPlaying = numNotesPlaying + 1;
            pitch.postln;
        });

        // Note Off
        midiFuncs[\noteOff] = MIDIFunc.noteOff({ |veloc, pitch, chan|
            chan = 0;
            vstList.do { |item| 
                item.midi.noteOff(chan, pitch, veloc);
            };
            oscNetAddr.sendMsg('/keyOff', chan, pitch);
            numNotesPlaying = 0;
        });

        // Pitch Bend
        midiFuncs[\bend] = MIDIFunc.bend({ |bendval, channel|
            channel = 0;
            bendval.postln;
            vstList.do { |item| 
                item.midi.bend(channel, bendval);
            };
        });

        // Initialize Sliders (CC 0-7)
        8.do { |i|
            var ccNum = i;
            var sliderKey = ("slider" ++ (i+1)).asSymbol;
            
            this.debug("Setting up % for CC number %".format(sliderKey, ccNum));
            
            midiFuncs[sliderKey] = MIDIFunc.cc({ |val, num, chan, src|
                this.debug("=== MIDI Input Debug ===");
                this.debug("Slider: %".format(sliderKey));
                this.debug("CC Number: %".format(num));
                this.debug("Value: %".format(val));
                
                sliderValues[i] = val;
                
                if(oscNetAddr.notNil) {
                    oscNetAddr.sendMsg(("/slider" ++ (i+1)).asSymbol, val);
                };
            }, ccNum);
        };

        // Initialize Knobs (CC 16-23)
        8.do { |i|
            var ccNum = i + 16;
            var knobKey = ("knob" ++ (i+1)).asSymbol;
            
            this.debug("Setting up % for CC number %".format(knobKey, ccNum));
            
            midiFuncs[knobKey] = MIDIFunc.cc({ |val, num, chan, src|
                this.debug("=== MIDI Input Debug ===");
                this.debug("Knob: %".format(knobKey));
                this.debug("CC Number: %".format(num));
                this.debug("Value: %".format(val));
                
                knobValues[i] = val;
                
                if(oscNetAddr.notNil) {
                    oscNetAddr.sendMsg(("/knob" ++ (i+1)).asSymbol, val);
                };
            }, ccNum);
        };

        // All Notes Off Button
        midiFuncs[\allNotesOff] = MIDIFunc.cc({ |val|
            vstList.do { |item|
                5.do { |chan|
                    item.midi.allNotesOff(chan);
                };
            };
        }, 48);
    }

    // Method to process all knobs with a function
    processKnobs { |func|
        numKnobs.do { |i|
            func.value(i, knobValues[i], knobRanges[i]);
        };
    }

    // Method to get a specific knob's values
    getKnob { |index|
        if(index < 8) {
            ^(
                value: knobValues[index],
                cc: index + 16
            )
        } {
            "Knob index out of range".error;
            ^nil
        }
    }

    // Method to set a specific knob's value
    setKnob { |index, value|
        if(index < 8) {
            knobValues[index] = value;
            knobRanges[index] = value.linlin(0, 127, 0.0, 1.0);
            oscNetAddr.sendMsg(("/knob" ++ (index+1)).asSymbol, value);
        } {
            "Knob index out of range".error;
        }
    }

    free {
        midiFuncs.do(_.free);
    }

    stop{ 
        controlRoutine.stop;
         }

    setGlissandoMode { |bool|
        glissandoMode = bool;
    }

    setGlissandoNoteMode { |bool|
        glissandoNoteMode = bool;
    }

    // Method to start continuous VST parameter mapping
    startVSTMapping { |vstMappings, ccMappings, rate = 0.02|
        this.debug("Starting VST mapping");
        
        pollRate = rate;
        controlRoutine.stop;
        
        // If old-style single VST mapping is provided, convert to new format
        if(vstMappings.isKindOf(Symbol)) {
            var vstKey = vstMappings;
            var mappings = ccMappings ?? {[
                [0, 16, 0],
                [0, 17, 1],
                [0, 18, 2]
            ]};
            vstMappings = Dictionary.new;
            vstMappings[vstKey] = mappings;
        };
        
        // Default mapping if none provided
        vstMappings = vstMappings ?? {Dictionary[\vsti -> [
            [0, 16, 0],
            [0, 17, 1],
            [0, 18, 2]
        ]]};
        
        if(debug) {
            "VST Mappings:".postln;
            vstMappings.keysValuesDo { |vstKey, mappings|
                "VST: %".format(vstKey).postln;
                mappings.do { |mapping|
                    "Channel: %, CC: %, Knob: % (current value: %)"
                    .format(mapping[0], mapping[1], mapping[2], knobValues[mapping[2]])
                    .postln;
                };
            };
        };
        
        controlRoutine = Routine({
            inf.do {
                vstMappings.keysValuesDo { |vstKey, mappings|
                    var vst = vstList.at(vstKey);
                    if(vst.notNil) {
                        mappings.do { |mapping|
                            var chan, cc, knobIndex;
                            #chan, cc, knobIndex = mapping;
                            
                            this.debug("Sending to VST '%': chan %, cc %, knobIndex %, value %"
                                .format(vstKey, chan, cc, knobIndex, knobValues[knobIndex]));
                            
                            vst.midi.control(
                                chan, 
                                cc, 
                                knobValues[knobIndex]
                            );
                        };
                    };
                };
                pollRate.wait;
            }
        }).play;
    }
    
    // Method to change polling rate while running
    setPollRate { |newRate|
        pollRate = newRate;
    }

    // Method to toggle debug mode
    setDebug { |bool|
        debug = bool;
        this.debug("Debug mode %".format(if(bool, "enabled", "disabled")));
    }
}
