# MIDI Response System

A SuperCollider system for real-time MIDI harmonization using VST instruments.

## Architecture

MIDI Input → Note Mapper → VST Controller → Audio Output
                ↓             ↓
           Note Mappings    VST List

### Core Components

1. **Note Mapper** (`lib/note-mapping.scd`)
   - Handles MIDI note mapping logic
   - Maps input notes to arrays of output notes
   - Configurable delay between triggered notes

2. **VST Controller** (`lib/vst-controller.scd`)
   - Manages VST plugin instances
   - Handles note triggering and release
   - Routes audio to ADAT outputs

3. **Config** (`lib/config.scd`)
   - Global configuration settings
   - VST paths, instance counts, timing, etc.

### Setup Components

1. **Synth Setup** (`setup/synths-setup.scd`)
   - Defines audio routing architecture
   - Creates VST plugin matrix
   - Routes to ADAT outputs 3/4, 5/6, 7/8

2. **VST Setup** (`setup/vstplugin-setup.scd`)
   - Initializes VST instances
   - Creates VST dictionary
   - Opens plugin editors

3. **MIDI Setup** (`setup/midi-setup.scd`)
   - Configures MIDI input
   - Sets up note-on/off responders
   - Routes MIDI to VST instances

## File Structure

midi-response-system/
├── lib/
│   ├── config.scd         # Global settings
│   ├── note-mapping.scd   # Note mapping logic
│   └── vst-controller.scd # VST management
├── setup/
│   ├── _setup-loader.scd  # Load order manager
│   ├── synths-setup.scd   # Audio routing
│   ├── vstplugin-setup.scd# VST initialization
│   └── midi-setup.scd     # MIDI configuration
└── main.scd               # Main entry point

## Usage

1. Configure note mappings in main.scd:
   ~noteMapper.addMapping(60, [64, 67, 71]);  // C4 triggers E4, G4, B4

2. Run the system:
   - Open main.scd in SuperCollider
   - Execute the code block
   - VST editors will open automatically
   - Play MIDI notes to trigger harmonies

3. Cleanup:
   ~cleanup.value;  // Stops all notes and closes editors

## Audio Routing

- VST1 & VST4 → ADAT 3/4
- VST2 & VST5 → ADAT 5/6
- VST3 & VST6 → ADAT 7/8

## Dependencies

- SuperCollider 3.x
- SC3-plugins (for VSTPlugin)
- SWAM Viola VST3 or compatible VST

## Debug Mode

To enable debug output:
~debug.value("Your debug message");

Debug messages include:
- MIDI input events
- Note mapping operations
- VST triggering events
- Audio routing status

## Signal Flow

1. MIDI Input
   - Note-on/off messages received
   - Velocity and channel data preserved

2. Note Mapping
   - Input note checked against mapping dictionary
   - Corresponding output notes retrieved
   - Delay time applied between notes

3. VST Control
   - Input note sent to first VST
   - Mapped notes distributed to additional VSTs
   - All notes properly released on note-off

4. Audio Output
   - VSTs mixed in pairs
   - Routed to ADAT