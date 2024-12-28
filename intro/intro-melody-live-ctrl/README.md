# Intro Melody Live Control

A SuperCollider-based interactive melodic pattern generator with live MIDI control capabilities.

## Overview

This project provides three different melodic pattern generators, each with increasing complexity and control:

1. **Melodic Part 1**: Basic arpeggiator with MIDI controller influence
2. **Melodic Part 2**: Enhanced version with additional control parameters
3. **Melodic Part 2 with Repetition and Random Mode**: Advanced version featuring:
   - Configurable repetitions
   - Random/Sequential melody selection
   - Chord-based patterns
4. **Melodic Part 2 with Individual Note Playback**: Final version featuring:
   - Single note sequencing
   - Customizable melody lists
   - Enhanced playback control

## Features

- Live tempo control via MIDI (60-400 BPM range)
- Adjustable note timing and rest periods
- MIDI velocity control
- Switchable melody patterns
- Random or sequential melody progression
- Configurable repetition counts

## Requirements

- SuperCollider
- MIDI Controller
- VST instruments (configured in setup)

## Usage

1. Load the SuperCollider file: `intrro-melody.scd`
2. Ensure your MIDI controller is connected
3. Run the desired melodic part section
4. Control using the following commands:

```supercollider
~burst.play;        // Start playback
~stop = true;       // Stop playback
~repetitions = 24;  // Set number of repetitions
~randomMode = true; // Enable random melody selection
```

## MIDI Controller Mapping

- Slider 1: Tempo control (60-400 BPM)
- Slider 2: Rest time (0.025-0.35 seconds)
- Slider 3: Wait time (0.001-0.25 seconds)
- Slider 4: Velocity control (0-100)

## Notes

- The project requires proper setup of VST instruments through the `setup/_setup-loader.scd` file
- Each melodic part can be run independently
- Changes to melody patterns can be made by modifying the `chordList` or `melodyList` arrays 