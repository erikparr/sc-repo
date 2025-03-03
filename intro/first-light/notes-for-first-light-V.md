# First Light V - Generative String Ensemble

## Overview
A generative composition system for string ensemble that combines procedural generation with MIDI control capabilities. The system offers two distinct control modes and manages multiple VST instances for rich string textures.

## Control Modes

### Procedural Mode (`~proceduralMode = true`)
- **Rest Time**: Controlled by multiple envelope sequences
- **Chord Duration**: Controlled by multiple envelope sequences
- **Intensity**: CC 17 controlled by envelope sequences
- **Progression**: Each envelope change triggers next chord in sequence
- **Development**: Automatic cycle progression through harmonic patterns

### MIDI Control Mode (`~proceduralMode = false`)
- **Rest Time**: Controlled by Slider 2
- **Chord Duration**: Controlled by Slider 3
- **Intensity**: Manual control via mapped knobs
- **Progression**: Manual control of harmonic development

## VST Integration
- Supports 6 VST instances (vsti0 through vsti5)
- Automatic voice distribution
- MIDI CC parameter mapping
- Integrated intensity control

## Control Ranges
- **Rest Time**: 0.1 to 0.75 seconds (exponential curve)
- **Chord Duration**: 0.016 to 0.055 seconds (inverse exponential)
- **Tempo**: 60 to 400 BPM (quadratic curve)
- **Velocity**: 0 to 100 (linear)

## Development Cycles
- Multiple chord sequences
- Progressive harmonic development
- Automatic cycle advancement in procedural mode
- Configurable repetition counts

## Envelope System
- Multiple envelope sequences for rest time
- Multiple envelope sequences for chord duration
- Independent intensity envelopes
- Automatic progression between envelopes

## Usage
1. Set control mode: `~proceduralMode = true/false`
2. Start the sketch: `~sketch.play`
3. Adjust parameters via MIDI controller or let procedural system run
4. Stop the sketch: `~sketch.stop` 