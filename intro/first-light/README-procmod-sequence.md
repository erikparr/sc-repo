# ProcMod Sequencing System

## Overview

The `simple-procmod-sequence.scd` file demonstrates a robust framework for composing and performing complex musical sequences by combining multiple musical gestures using the ProcMod system. This approach allows for creating larger musical compositions from modular, reusable components with precise control over timing, transitions, and parameter settings.

## Key Components

### 1. ProcMod

ProcMods are self-contained musical gesture modules with their own:

- **Amplitude envelope** - Controls the overall amplitude shape
- **State management** - Tracks active notes, synths, and other resources
- **Functions**:
  - `mainFunc` - Creates and plays the gesture
  - `releaseFunc` - Executes after release has completed
  - `onReleaseFunc` - Executes immediately when release is triggered

ProcMods are the building blocks of larger musical structures, each responsible for cleanly managing its own resources.

### 2. ProcEvents

ProcEvents sequences multiple ProcMods by defining:

- **Event array** - A sequence of [play, release] pairs
- **Timing control** - Methods to advance through the sequence
- **State tracking** - Monitors which events are playing through the `\indexPlaying` message

## Design Architecture

The sequence demonstrates a 3-layer architecture:

1. **Parameter Layer** - Configuration and settings
2. **ProcMod Layer** - Individual musical gestures
3. **Sequence Layer** - Organization of gestures into a timeline

### Parameter Configuration

Before creating ProcMods, parameters are configured to ensure proper operation:

```supercollider
~configureChordBendParams = {
    if(~updateParams.notNil) {
        ~updateParams.value((
            duration: 8.0,              // Duration appropriate for sequence
            bendTime: 3.5,              // Time to reach peak bend
            returnTime: 3.0,            // Time to return from peak
            chord: [60, 55, 50],        // Notes appropriate for sequence
            bendPercents: [15, 12, 10], // Moderate bend percentages
            ccLevels: [90, 100, 110],   // Expression levels
            curveShape: \sin            // Smooth curve shape
        ));
    }
};
```

This ensures each musical gesture's parameters are optimized for its role in the sequence.

### ProcMod Creation

Each musical gesture is encapsulated as a ProcMod:

1. **Surfacing Melody ProcMod**
   - Plays a melody sequence from `surfacing-procmod.scd`
   - Uses OSC messaging for note control
   - Handles proper cleanup of notes and envelopes

2. **Chord Bend ProcMod**
   - Plays a chord with pitch bending from `simple-chord-bend.scd`
   - Uses unique ID for each chord instance
   - Manages bend and expression envelopes

### Sequence Organization

The sequence is organized using ProcEvents:

```supercollider
~procSequence = ProcEvents.new([
    // Start with surfacing melody
    [~surfacingMod, nil],
    
    // Then transition to chord bend, releasing surfacing
    [~chordBendMod, ~surfacingMod],
    
    // Finally release chord bend
    [nil, ~chordBendMod]
]);
```

## Communication Patterns

The system uses several communication patterns:

1. **OSC Messaging** - For note control and parameter envelopes
2. **SimpleController** - For observing state changes in ProcMods and ProcEvents
3. **Global Registry** - For tracking active notes across different contexts

## Robust Resource Management

The sequence implements several mechanisms to ensure resources are properly managed:

1. **Note Registry** - Tracks all active notes with their associated synths
2. **Multi-level Cleanup** - Each layer has its own cleanup mechanisms:
   - ProcMod's internal cleanup in `onReleaseFunc`
   - Sequence-level cleanup at transition points
   - Global cleanup functions as fallbacks

3. **Safety Margins** - Extra time buffers ensure processes complete before advancing

## Execution Control

The sequence provides several control functions:

```supercollider
~playFullSequence    // Play the full automated sequence
~stepSequence        // Manually advance to next step
~resetSequence       // Reset the sequence to beginning
~cleanup             // Clean up all objects
~updateChordBendForSequence // Modify chord bend timing
```

## Best Practices Demonstrated

1. **Encapsulation** - Each musical gesture manages its own state
2. **Clear Interfaces** - Functions like `~updateParams` provide clean APIs
3. **Defensive Programming** - Checking if functions exist before using them
4. **Proper Cleanup** - Multiple layers of cleanup ensure no hanging notes
5. **Parameter Configuration** - Explicit parameter settings for sequence context
6. **Logging** - Clear logging at key points for debugging

## Implementation Notes

### OSC-based Note Management

Notes are played through OSC messages rather than direct function calls:

```supercollider
NetAddr.localAddr.sendMsg('/chord/noteOn', 
    chordId,         // Unique ID for this chord instance
    vstIndex,        // VST instrument index
    note,            // MIDI note number
    velocity,        // Note velocity
    bendPercent,     // Bend amount
    // Additional parameters...
);
```

This approach:
1. Decouples note generation from playback
2. Allows for easier debugging
3. Creates a consistent messaging pattern

### Registry-based State Tracking

Active notes are tracked in a global registry:

```supercollider
~chordNoteRegistry[noteKey] = (
    chordId: chordId,
    vstIndex: vstIndex,
    note: note,
    vst: vst,
    bendSynth: bendSynth,
    ccSynth: ccSynth
);
```

This ensures:
1. Each note can be identified and released properly
2. Associated resources (synths) can be freed
3. The system can recover from unexpected states

## Extending the System

To add new musical gestures:

1. Create a new ProcMod for your gesture
2. Configure appropriate parameters
3. Add to the ProcEvents sequence at the desired position
4. Add necessary cleanup mechanisms

## Common Issues and Solutions

### Hanging Notes

If notes are not being released properly:
- Ensure the ProcMod's `onReleaseFunc` properly releases all notes
- Add explicit cleanup calls at transition points
- Use `~cleanupAllChordNotes` as a fallback

### Synth Node Errors

If you see errors like `/n_free Node not found`:
- The synth has already been freed automatically
- Modify SynthDefs to use `doneAction: 0` instead of `doneAction: 2`
- Add checks before trying to free synths

### Timing Issues

If gestures are being cut off or overlapping improperly:
- Adjust safety margins in sequence advancement
- Ensure ProcMod durations match their actual sound duration
- Add debugging output at key timing points

## Summary

The `simple-procmod-sequence.scd` system provides a robust model for creating complex musical compositions from modular components. By encapsulating musical gestures as ProcMods, configuring parameters appropriately for the sequence context, and managing resources carefully, it creates a reliable platform for expressive musical control.

This approach can be extended to handle more complex sequences with additional gestures, more sophisticated transitions, and dynamic parameter adjustments based on performance conditions. 