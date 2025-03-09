document.addEventListener('DOMContentLoaded', () => {
  // DOM elements
  const midiStatus = document.getElementById('midiStatus');
  const recordBtn = document.getElementById('recordBtn');
  const clearBtn = document.getElementById('clearBtn');
  const copyBtn = document.getElementById('copyBtn');
  const toggleFormatBtn = document.getElementById('toggleFormatBtn');
  const noteOutput = document.getElementById('noteOutput');

  // Application state
  let isRecording = false;
  let keystationInput = null;
  let noteHistory = [];
  let midiNumberHistory = []; // Store MIDI numbers
  let showMidiNumbers = false; // Toggle state for display format

  // Initialize WebMIDI
  WebMidi
    .enable()
    .then(onMIDISuccess)
    .catch(err => {
      midiStatus.textContent = `WebMIDI could not be enabled: ${err}`;
      console.error(err);
    });

  // Handle successful MIDI initialization
  function onMIDISuccess() {
    console.log('WebMIDI enabled successfully!');
    
    // Look for Keystation device
    findKeystationDevice();
    
    // Set up a listener for when devices are connected/disconnected
    WebMidi.addListener('connected', () => {
      console.log('MIDI device connected');
      findKeystationDevice();
    });
    
    WebMidi.addListener('disconnected', () => {
      console.log('MIDI device disconnected');
      findKeystationDevice();
    });
  }

  // Find the Keystation MIDI device
  function findKeystationDevice() {
    keystationInput = null;
    
    // Look for a device with "Keystation" in the name
    for (const input of WebMidi.inputs) {
      if (input.name.toLowerCase().includes('keystation')) {
        keystationInput = input;
        break;
      }
    }
    
    // If no Keystation device is found, use the first available MIDI input
    if (!keystationInput && WebMidi.inputs.length > 0) {
      keystationInput = WebMidi.inputs[0];
      console.log(`No Keystation device found. Using ${keystationInput.name} instead.`);
    }
    
    if (keystationInput) {
      midiStatus.textContent = `Connected to: ${keystationInput.name}`;
      midiStatus.className = 'status connected';
      
      // Enable buttons
      recordBtn.disabled = false;
      clearBtn.disabled = false;
      copyBtn.disabled = false;
      toggleFormatBtn.disabled = false;
      
      // Set up MIDI note listeners
      setupMIDIListeners();
    } else {
      midiStatus.textContent = 'No MIDI devices found. Please connect your Keystation.';
      midiStatus.className = 'status disconnected';
      
      // Disable buttons
      recordBtn.disabled = true;
      clearBtn.disabled = true;
      copyBtn.disabled = true;
      toggleFormatBtn.disabled = true;
    }
  }

  // Set up MIDI note listeners
  function setupMIDIListeners() {
    // Remove any existing listeners
    if (keystationInput) {
      keystationInput.removeListener();
      
      // Listen for note on events
      keystationInput.addListener('noteon', e => {
        if (isRecording) {
          const noteName = e.note.name + e.note.octave;
          const midiNumber = e.note.number;
          const velocity = e.velocity;
          console.log(`Note On: ${noteName} (MIDI: ${midiNumber}, velocity: ${velocity})`);
          
          // Add note to history
          noteHistory.push(noteName);
          midiNumberHistory.push(midiNumber);
          
          // Update display
          updateNoteDisplay();
        }
      });
    }
  }

  // Update the note display
  function updateNoteDisplay() {
    if (showMidiNumbers) {
      noteOutput.value = midiNumberHistory.join(', ');
    } else {
      noteOutput.value = noteHistory.join(' ');
    }
    // Scroll to bottom
    noteOutput.scrollTop = noteOutput.scrollHeight;
  }

  // Toggle recording state
  function toggleRecording() {
    isRecording = !isRecording;
    
    if (isRecording) {
      midiStatus.textContent = `Recording notes from: ${keystationInput.name}`;
      midiStatus.className = 'status recording';
      recordBtn.textContent = 'Stop Recording (Enter)';
    } else {
      midiStatus.textContent = `Connected to: ${keystationInput.name}`;
      midiStatus.className = 'status connected';
      recordBtn.textContent = 'New Take (Enter)';
    }
  }

  // Clear the note history
  function clearNotes() {
    noteHistory = [];
    midiNumberHistory = [];
    updateNoteDisplay();
  }

  // Copy notes to clipboard
  function copyNotes() {
    if ((showMidiNumbers && midiNumberHistory.length > 0) || 
        (!showMidiNumbers && noteHistory.length > 0)) {
      navigator.clipboard.writeText(noteOutput.value)
        .then(() => {
          const originalText = copyBtn.textContent;
          copyBtn.textContent = 'Copied!';
          setTimeout(() => {
            copyBtn.textContent = originalText;
          }, 2000);
        })
        .catch(err => {
          console.error('Failed to copy notes: ', err);
        });
    }
  }

  // Toggle between note names and MIDI numbers
  function toggleNoteFormat() {
    showMidiNumbers = !showMidiNumbers;
    
    if (showMidiNumbers) {
      toggleFormatBtn.textContent = 'Show Note Names (T)';
    } else {
      toggleFormatBtn.textContent = 'Show MIDI Numbers (T)';
    }
    
    updateNoteDisplay();
  }

  // Button event listeners
  recordBtn.addEventListener('click', toggleRecording);
  clearBtn.addEventListener('click', clearNotes);
  copyBtn.addEventListener('click', copyNotes);
  toggleFormatBtn.addEventListener('click', toggleNoteFormat);

  // Keyboard shortcuts
  document.addEventListener('keydown', (e) => {
    // Ignore keyboard events when typing in a text field
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
      return;
    }
    
    // Enter key - toggle recording
    if (e.key === 'Enter' && !recordBtn.disabled) {
      e.preventDefault();
      toggleRecording();
    }
    
    // Space key - clear notes
    if (e.key === ' ' && !clearBtn.disabled) {
      e.preventDefault();
      clearNotes();
    }
    
    // Ctrl+C - copy notes (custom shortcut, not the browser's copy)
    if (e.key === 'c' && (e.ctrlKey || e.metaKey) && !copyBtn.disabled) {
      // Don't prevent default here to allow the browser's copy functionality to work as well
      copyNotes();
    }
    
    // T key - toggle note format
    if ((e.key === 't' || e.key === 'T') && !toggleFormatBtn.disabled) {
      e.preventDefault();
      toggleNoteFormat();
    }
  });
}); 