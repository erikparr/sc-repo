# SuperCollider Project Template

A SuperCollider project template for creating dynamic MIDI-controlled compositions with pitch bend and continuous controller automation. This template is designed for working with multiple VST instruments and includes sophisticated envelope control for pitch bending and bow-like expression.

## Features

- Multi-VST instrument support with automatic distribution of voices
- Sophisticated pitch bend automation with custom envelopes
- Bow-like expression control using CC messages
- Automatic chord progression system
- Built-in safety features for MIDI cleanup and reset

## Project Structure

```
.
├── project-composition-example.scd  # Main composition example file
├── setup/                          # Setup and initialization scripts
└── reference/                      # Reference materials and documentation
```

## Prerequisites

- SuperCollider (latest version recommended)
- VST instruments compatible with SuperCollider
- SuperCollider VST plugin support installed

## Setup

1. Make sure SuperCollider is properly installed with VST support
2. Place your VST instruments in the appropriate VST directory for your system
3. Load the setup script first:
   ```supercollider
   (PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader.scd").load;
   ```

## Usage

The template provides several key functions for controlling your composition:

### Basic Controls

```supercollider
~chordBend.play;   // Start the chord progression
~chordBend.stop;   // Stop the progression
~chordBend.reset;  // Reset the progression to the beginning
```

### Emergency Cleanup

To stop all notes and reset all pitch bends:
```supercollider
~vstList.do { |vst, index|
    (0..15).do { |chan|
        vst.midi.allNotesOff(chan);
        vst.midi.bend(chan, 8192);  // Reset pitch bend to center
    };
};
```

### Customization

The template includes several parameters you can modify:

- `~waitTime`: Controls the duration of each chord (default: 12 seconds)
- `~chordSequence`: Define your own chord progressions
- Envelope parameters in `\BendEnvelope1` and `\BowEnvelope` SynthDefs

## Contributing

Feel free to fork this template and adapt it to your needs. Pull requests for improvements are welcome.

## License

This project is open source and available under the MIT License. 