# OSC Control Structure I

A real-time generative music system that uses OSC (Open Sound Control) to bridge between a web interface and SuperCollider, enabling MPE (MIDI Polyphonic Expression) control of VST instruments.

## System Architecture

1. **Web Interface (React + TypeScript)**
   - Generates notes based on musical parameters
   - Sends OSC messages via WebSocket
   - Controls: density, scale selection, playback

2. **OSC Bridge Server (Node.js)**
   - Runs on port 8080 for WebSocket connections
   - Forwards messages to SuperCollider on port 57120
   - Handles bidirectional communication

3. **SuperCollider Backend**
   - Receives OSC messages and converts to MPE MIDI
   - Manages VST instruments and voice allocation
   - Handles sophisticated MIDI mapping and automation

## Key Components

### Web Interface
- `OSCService`: Manages WebSocket connection and message sending
- `NoteGenerator`: Handles algorithmic note generation
- React components for user interface controls

### SuperCollider
- MPE channel management (1-15, excluding master channel 16)
- Dynamic voice allocation
- VST instrument hosting and automation
- Supports multiple MIDI controllers and mappings

## Message Protocol

### OSC Messages
1. Note Events:
   - `/mpe/noteOn [note(int), velocity(float 0-1)]`
   - `/mpe/noteOff [note(int), velocity(float 0-1)]`

2. Expression Controls:
   - `/mpe/pitchBend [note(int), bend(float -1 to 1)]`
   - `/mpe/pressure [note(int), pressure(float 0-1)]`
   - `/mpe/timbre [note(int), timbre(float 0-1)]`

## Development Guidelines

1. **Web Interface**
   - Keep OSC message format consistent with SuperCollider expectations
   - Normalize all continuous controllers to 0-1 range
   - Handle WebSocket connection state appropriately

2. **SuperCollider**
   - Maintain MPE channel allocation system
   - Scale incoming values appropriately (0-1 to MIDI ranges)
   - Handle cleanup for stuck notes and reset controllers

3. **VST Integration**
   - Support multiple VST instances
   - Handle MIDI mapping configurations
   - Manage audio routing and mixing

## Setup Requirements

1. Node.js environment for web interface and bridge
2. SuperCollider with VST plugin support
3. Compatible VST instruments
4. WebSocket-capable browser

## Project Structure Reference

## File Structure

```
control-app/
├── src/
│   ├── lib/
│   │   ├── OSCService.ts      # WebSocket/OSC communication
│   │   └── NoteGenerator.ts   # Algorithmic note generation
│   ├── components/
│   │   ├── DensityControl.tsx # UI for note density
│   │   └── ScaleSelector.tsx  # UI for scale selection
│   └── App.tsx               # Main React application
├── bridge-server.js          # WebSocket to UDP bridge
└── setup/
    ├── _setup-loader.scd     # SuperCollider initialization
    ├── synths-setup.scd      # Synth definitions
    ├── vstplugin-setup.scd   # VST configuration
    ├── midi-setup.scd        # MIDI routing setup
    └── osc-setup.scd         # OSC message handlers
```