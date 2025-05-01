# First Light: SuperCollider VST Controller System

This project is a SuperCollider-based system for controlling VST instruments with a focus on musical composition and performance. It implements a sophisticated modular architecture for controlling Sample Modeling SWAM instruments (specifically, bass tuba), with support for MIDI control, sequencing, and real-time parameter manipulation.

## Project Structure

The project uses a modular setup with separate files for different functionality:

- **Setup Files**: Initialize core components of the system
- **Controller Classes**: Custom classes for MIDI and VST interaction
- **ProcMod System**: High-level gestural control system for musical events
- **Main Implementation**: The `surfacing-procmod.scd` file implements the core musical logic

## Setup Files

### `_setup-loader-soloTuba.scd`

The entry point that loads all other setup files in the correct order:

```supercollider
~setupFiles = [
    "synths-setup.scd",          // SynthDefs for VST processing
    "vstplugin-setup-soloTuba.scd", // VST instrument setup
    "midi-setup.scd",            // MIDI controller setup
    "osc-setup.scd",             // OSC communication setup
    "../snapshotData/snapshot-functions.scd" // Parameter snapshots
];
```

### `synths-setup.scd`

Defines SynthDefs for processing VST instruments:
- `\insert`, `\insert2`, `\insert3`: Route audio through VST plugins
- `\insertStrings`, `\insertStrings4`: Specialized routing for string instruments
- `\BendEnvelope1`, `\BendEnvelopeLoop`: Pitch bend envelope generators
- `\ccEnvelopeLoop`: Control change (CC) envelope generator

### `vstplugin-setup-soloTuba.scd`

Sets up VST instruments:
1. Searches for available VST plugins
2. Creates the synth for routing audio through the VSTs
3. Loads the SWAM Bass Tuba VST plugins (3 instances)
4. Stores VST controllers in a dictionary for easy access
5. Opens VST editor windows

### `midi-setup.scd`

Configures MIDI handling:
1. Initializes variables for knob/controller values
2. Creates a `MIDIController` instance for VST parameter mapping
3. Sets up MIDI responders for:
   - Note on/off events
   - Control changes
   - Pitch bend
   - Button presses

### `osc-setup.scd`

Sets up OSC (Open Sound Control) communication:
1. Initializes variables for velocity and glissando modes
2. Creates OSC responders for:
   - Note events
   - Bend commands
   - Chord morphing
   - Glissando control
   - BPM settings

## Controller Classes

### `MIDIController.sc`

A custom class that handles:
1. MIDI input/output and mapping to VST parameters
2. Parameter snapshots for storing and recalling settings
3. Different mapping modes:
   - Multi-channel mode (distributes notes across MIDI channels)
   - Multi-instrument mode (routes different notes to different VSTs)
   - Velocity control mode
4. Bend control with envelope generation
5. Debug capabilities

### `VSTPluginController.sc`

Manages communication with VST plugins:
1. Loads and initializes VST plugins
2. Sends MIDI messages to VSTs
3. Controls VST parameters
4. Manages plugin presets
5. Handles plugin editor windows
6. Manages plugin programs/banks

## ProcMod System

The ProcMod system (from the JoshUGens library) provides high-level gestural control:

### `ProcMod`

A class for controlling modular processes:
1. Controls how events unfold over time with an amplitude envelope
2. Executes functions/tasks/routines when played
3. Handles clean release of events
4. Communicates state changes to listeners using a model-view-controller pattern

### `ProcModR`

An extension of ProcMod that adds real-time recording capabilities.

### `ProcEvents`

Manages sequences of ProcMod instances:
1. Plays and releases events in sequence
2. Controls timing between events
3. Provides performance and rehearsal GUIs
4. Records timelines for automated playback

## Main Implementation: `surfacing-procmod.scd`

This is the main composition file implementing a piece called "First Light" using the ProcMod system for better gestural control.

### Key Components

1. **Global Settings**:
   - Tempo, note durations, and rest times
   - Behavior modes (melodyRest, fermata, etc.)
   - Note offset and repetition controls

2. **Melody Dictionary**:
   - Collection of tuba melody patterns
   - Each melody has patterns and velocity multipliers
   - Development cycles define sequence order

3. **Helper Functions**:
   - `~processNote`: Modifies notes based on current settings
   - `~switchCycle`: Changes to a specific cycle
   - `~advanceCycle`: Advances to the next cycle

4. **OSC Responders**:
   - Handle note events
   - Manage fermata (held) notes

5. **ProcMod Implementation**:
   - Creates ProcMod instances for each melody
   - Handles note playback with precise timing
   - Manages melody transitions and repetitions

6. **Control Functions**:
   - `~playMelody`: Plays a specific melody
   - `~playAllMelodiesInSequence`: Plays through the entire sequence
   - `~nextMelody`: Advances to the next melody
   - `~stopAllMelodies`: Stops all currently playing melodies
   - `~setMode`: Configures behavior modes

### Execution Flow

1. Setup files are loaded when the script is executed
2. VST instruments (SWAM Bass Tubas) are initialized
3. MIDI and OSC responders are set up
4. Melody ProcMods are created
5. Playing a melody:
   - Creates a Task that plays each note in sequence
   - Applies velocity and timing variations
   - Sends OSC messages to trigger notes
   - Handles fermatas (held notes)
   - Manages note releases
6. Control functions provide an interface for performance

## Usage

1. Load the main file with: `(PathName(thisProcess.nowExecutingPath).pathOnly ++ "setup/_setup-loader-soloTuba.scd").load;`
2. Execute the main implementation: `surfacing-procmod.scd`
3. Control playback with functions like:
   - `~playAllMelodiesInSequence.value;`
   - `~stopAllMelodies.value;`
   - `~switchToCycle.value(1);`

## Design Philosophy

The system uses a modular approach to separate concerns:
1. VST instrument control (via VSTPluginController)
2. MIDI mapping and control (via MIDIController)
3. High-level gestural control (via ProcMod)
4. Musical structure and composition logic

This allows for flexibility in performance, with options for:
- Procedural melody generation
- Sequence-based playback
- Real-time parameter control via MIDI controllers
- Snapshot-based parameter recall

The ProcMod system provides a way to think about musical gestures as events with specific amplitude envelopes, functions to execute, and release behaviors, making it well-suited for composed electroacoustic music with precise control over timing and expression. 