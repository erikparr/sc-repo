// =====================================================
// ProcMod Sequence with Overlap Timing
// =====================================================
// Demonstrates how to create melodies and chord bends
// with precise timing control and overlap


// =====================================================
// 1. MELODY PROCMOD - Create ProcMod for melodic gestures
// =====================================================

// ProcMod for a simple melody
~melodyProcMod = ProcMod(
  // Release node in envelope gives us control over timing
  Env([0, 1, 0.8, 0], [1, 2, 1], \sin, 2),
  // Amplitude
  0.7,
  // ID
  \melody,
  // Group, etc.
  nil, 0, 1,

  // Main function - Play melody
  { |group, envbus, server|
    var synth;
    "Starting melody...".postln;

    synth = {
      var env = In.kr(envbus, 1);
      var freq = EnvGen.kr(
        Env([300, 800, 500, 650], [0.5, 0.3, 0.4], \sin)
      );
      SinOsc.ar(freq) * env * 0.3;
    }.play(group);

    synth;
  },

  // Release function - after envelope completes
  { |group, envbus|
    "Melody completed.".postln;
  }
);

// =====================================================
// 2. CHORD BEND PROCMOD - Create ProcMod for chord bend gestures
// =====================================================

// ProcMod for chord bend effect
~chordBendProcMod = ProcMod(
  // Envelope with 6 second duration and release node
  Env([0, 1, 0.7, 0], [1.5, 3, 1.5], \sin, 2),
  // Amplitude
  0.6,
  // ID
  \chordBend,
  // Group, etc.
  nil, 0, 1,

  // Main function - Play chord with pitch bend
  { |group, envbus, server|
    var synth;
    "Starting chord bend...".postln;

    synth = {
      var env = In.kr(envbus, 1);
      var bend = SinOsc.kr(0.1).range(0, 50);
      var chord = Mix.ar([
        SinOsc.ar(300 + bend) * 0.3,
        SinOsc.ar(380 + (bend * 1.2)) * 0.3,
        SinOsc.ar(450 + (bend * 1.5)) * 0.3
      ]);
      chord * env * 0.5;
    }.play(group);

    synth;
  },

  // Release function - after envelope completes
  { |group, envbus|
    "Chord bend completed.".postln;
  }
);

// =====================================================
// 3. SEQUENCE TIMING - Functions to create ProcEvents with different timing
// =====================================================

// Create a function to build ProcEvents for sequential playback
~createSequentialProcEvents = {
  ProcEvents(
    [
      // First event: Play melody
      [ [~melodyProcMod], [] ],

      // Second event: Release melody, play chord bend
      [ [~chordBendProcMod], [~melodyProcMod] ]
    ],
    1, // amplitude
    nil, nil, \sequential
  );
};

// Create a function to build ProcEvents for overlapped playback
// Chord starts halfway through melody
~createOverlap50ProcEvents = {
  ProcEvents(
    [
      // First event: Play melody
      [ [~melodyProcMod], [] ],

      // Second event: Play chord bend while melody still running
      [ [~chordBendProcMod], [] ],

      // Third event: Release both
      [ [], [~melodyProcMod, ~chordBendProcMod] ]
    ],
    1, // amplitude
    nil, nil, \overlap50
  );
};

// Create a function to build ProcEvents for early-overlap playback
// Chord starts just as melody reaches peak
~createOverlap25ProcEvents = {
  ProcEvents(
    [
      // First event: Play melody
      [ [~melodyProcMod], [] ],

      // Second event: Play chord bend while melody still running
      [ [~chordBendProcMod], [] ],

      // Third event: Release both
      [ [], [~melodyProcMod, ~chordBendProcMod] ]
    ],
    1, // amplitude
    nil, nil, \overlap25
  );
};

// Create a function to build ProcEvents for late-overlap playback
// Chord starts just before melody would end
~createOverlap75ProcEvents = {
  ProcEvents(
    [
      // First event: Play melody
      [ [~melodyProcMod], [] ],

      // Second event: Play chord bend while melody still running
      [ [~chordBendProcMod], [] ],

      // Third event: Release both
      [ [], [~melodyProcMod, ~chordBendProcMod] ]
    ],
    1, // amplitude
    nil, nil, \overlap75
  );
};

// =====================================================
// 4. PLAYBACK FUNCTIONS - Methods to play sequences with different timing
// =====================================================

// Calculate timing constants based on melody and chord durations
~melodyDuration = 4; // Total envelope time of melody ProcMod
~chordDuration = 6;  // Total envelope time of chord ProcMod

// Function to play sequential (no overlap)
~playSequential = {
  var procEvents;
  "=== SEQUENTIAL PLAYBACK ===".postln;

  // Create a fresh ProcEvents instance
  procEvents = ~createSequentialProcEvents.value;

  // Trigger melody
  "Starting melody".postln;
  procEvents.next;

  // Schedule chord to start after melody completes
  SystemClock.sched(~melodyDuration, {
    "Starting chord bend (sequential)".postln;
    procEvents.next;
    nil;
  });
};

// Function to play with 25% overlap (chord starts early in melody)
~playOverlap25 = {
  var procEvents;
  "=== 25% OVERLAP PLAYBACK ===".postln;

  // Create a fresh ProcEvents instance
  procEvents = ~createOverlap25ProcEvents.value;

  // Trigger melody
  "Starting melody".postln;
  procEvents.next;

  // Schedule chord to start when melody is 25% complete
  SystemClock.sched(~melodyDuration * 0.25, {
    "Starting chord bend at 25% overlap".postln;
    procEvents.next;
    nil;
  });

  // Schedule final cleanup
  SystemClock.sched(~melodyDuration + ~chordDuration * 0.75, {
    "Releasing both gestures".postln;
    procEvents.next;
    nil;
  });
};

// Function to play with 50% overlap (chord starts midway through melody)
~playOverlap50 = {
  var procEvents;
  "=== 50% OVERLAP PLAYBACK ===".postln;

  // Create a fresh ProcEvents instance
  procEvents = ~createOverlap50ProcEvents.value;

  // Trigger melody
  "Starting melody".postln;
  procEvents.next;

  // Schedule chord to start when melody is 50% complete
  SystemClock.sched(~melodyDuration * 0.5, {
    "Starting chord bend at 50% overlap".postln;
    procEvents.next;
    nil;
  });

  // Schedule final cleanup
  SystemClock.sched(~melodyDuration + ~chordDuration * 0.5, {
    "Releasing both gestures".postln;
    procEvents.next;
    nil;
  });
};

// Function to play with 75% overlap (chord starts late in melody)
~playOverlap75 = {
  var procEvents;
  "=== 75% OVERLAP PLAYBACK ===".postln;

  // Create a fresh ProcEvents instance
  procEvents = ~createOverlap75ProcEvents.value;

  // Trigger melody
  "Starting melody".postln;
  procEvents.next;

  // Schedule chord to start when melody is 75% complete
  SystemClock.sched(~melodyDuration * 0.75, {
    "Starting chord bend at 75% overlap".postln;
    procEvents.next;
    nil;
  });

  // Schedule final cleanup
  SystemClock.sched(~melodyDuration + ~chordDuration * 0.25, {
    "Releasing both gestures".postln;
    procEvents.next;
    nil;
  });
};

// Function for direct control (no ProcEvents)
~playDirect = {
  "=== DIRECT TIMING CONTROL ===".postln;

  // Release any running instances
  if(~melodyProcMod.isRunning) { ~melodyProcMod.release };
  if(~chordBendProcMod.isRunning) { ~chordBendProcMod.release };

  // Short delay to ensure releases are processed
  SystemClock.sched(0.1, {
    "Starting melody directly".postln;
    ~melodyProcMod.play;

    // Schedule chord bend to start halfway through
    SystemClock.sched(~melodyDuration * 0.5, {
      "Starting chord bend directly".postln;
      ~chordBendProcMod.play;
      nil;
    });
    nil;
  });
};

// Safe release function
~releaseProcs = {
  "Releasing ProcMods individually...".postln;
  if(~melodyProcMod.isRunning) { ~melodyProcMod.release };
  if(~chordBendProcMod.isRunning) { ~chordBendProcMod.release };
};

// =====================================================
// 5. INSTRUCTIONS
// =====================================================

"=================================================".postln;
"PROCMOD SEQUENCE WITH OVERLAP TIMING READY".postln;
"=================================================".postln;
"Run these commands to test different overlap timings:".postln;
"  ~playSequential.value;  // Play melody then chord bend (no overlap)".postln;
"  ~playOverlap25.value;   // Play with 25% overlap (chord starts early)".postln;
"  ~playOverlap50.value;   // Play with 50% overlap (chord starts midway)".postln;
"  ~playOverlap75.value;   // Play with 75% overlap (chord starts late)".postln;
"  ~playDirect.value;      // Direct timing without ProcEvents".postln;
"  ~releaseProcs.value;    // Safely release ProcMods".postln;
"=================================================".postln;
"TIMING EXPLANATION:".postln;
"  Melody duration: 4 seconds".postln;
"  Chord bend duration: 6 seconds".postln;
"  25% overlap: Chord starts after 1 second of melody".postln;
"  50% overlap: Chord starts after 2 seconds of melody".postln;
"  75% overlap: Chord starts after 3 seconds of melody".postln;
"=================================================".postln;
   ~playOverlapped.value;