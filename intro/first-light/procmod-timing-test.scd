// ProcMod Timing Test - Simplified
// Demonstrates sequential and overlapped timing of ProcMods

(
// 1. Create two simple ProcMods with distinct sounds

// First ProcMod - Sine sweep with 5 second duration
~procMod1 = ProcMod(
  Env([0, 1, 0], [2, 3], \sin, 1),
  0.5,
  \sine,
  nil, 0, 1,
  {|group, envbus, server|
    "Starting sine sweep".postln;
    {
      var env = In.kr(envbus, 1);
      var freq = LFSaw.kr(0.2).range(300, 1200);
      SinOsc.ar(freq) * env * 0.3;
    }.play(group);
  }
);

// Second ProcMod - Noise burst with 4 second duration
~procMod2 = ProcMod(
  Env([0, 1, 0], [2, 2], \sin, 1),
  0.5,
  \noise,
  nil, 0, 1,
  {|group, envbus, server|
    "Starting noise burst".postln;
    {
      var env = In.kr(envbus, 1);
      BPF.ar(PinkNoise.ar(), LFNoise1.kr(0.5).range(400, 2000), 0.2) * env * 0.4;
    }.play(group);
  }
);

// Create a function to build a new ProcEvents for sequential playback
~createSequentialProcEvents = {
  ProcEvents(
    [
      // First event: Play ~procMod1
      [ [~procMod1], [] ],
      
      // Second event: Release ~procMod1, Play ~procMod2
      [ [~procMod2], [~procMod1] ]
    ],
    1, // amplitude
    nil, nil, \sequential
  );
};

// Create a function to build a new ProcEvents for overlapped playback
~createOverlappedProcEvents = {
  ProcEvents(
    [
      // First event: Play ~procMod1
      [ [~procMod1], [] ],
      
      // Second event: Play ~procMod2 while ~procMod1 is still running
      [ [~procMod2], [] ],
      
      // Third event: Release both
      [ [], [~procMod1, ~procMod2] ]
    ],
    1, // amplitude
    nil, nil, \overlapped
  );
};

// Function to demonstrate sequential playback
~playSequential = {
  var procEvents;
  "=== SEQUENTIAL PLAYBACK ===".postln;
  
  // Create a fresh ProcEvents instance each time
  procEvents = ~createSequentialProcEvents.value;
  
  // Trigger first event
  "Starting first ProcMod".postln;
  procEvents.next;
  
  // Schedule the second ProcMod after the first one's envelope time (5 seconds)
  SystemClock.sched(5, {
    "Triggering second event (sequential)".postln;
    procEvents.next; // Start second ProcMod
    nil;
  });
};

// Function to demonstrate overlapped playback
~playOverlapped = {
  var procEvents;
  "=== OVERLAPPED PLAYBACK ===".postln;
  
  // Create a fresh ProcEvents instance each time
  procEvents = ~createOverlappedProcEvents.value;
  
  // Trigger first event
  "Starting first ProcMod".postln;
  procEvents.next;
  
  // Schedule the second ProcMod halfway through the first one
  SystemClock.sched(2.5, {
    "Triggering second event (overlapped)".postln;
    procEvents.next; // Start second ProcMod
    nil;
  });
  
  // Schedule the cleanup
  SystemClock.sched(7, {
    "Releasing both ProcMods".postln;
    procEvents.next; // Release both
    nil;
  });
};

// Function to demonstrate direct ProcMod timing without ProcEvents
~playDirect = {
  "=== DIRECT TIMING CONTROL ===".postln;
  
  // Always release any potentially running instances first
  if(~procMod1.isRunning) { ~procMod1.release };
  if(~procMod2.isRunning) { ~procMod2.release };
  
  // Short delay to ensure releases are processed
  SystemClock.sched(0.1, {
    "Starting first ProcMod directly".postln;
    ~procMod1.play;
    
    // Schedule second ProcMod to overlap with first
    SystemClock.sched(2.5, {
      "Starting second ProcMod directly".postln;
      ~procMod2.play;
      nil;
    });
    nil;
  });
};

// Safe individual release function
~releaseProcs = {
  "Releasing ProcMods individually...".postln;
  if(~procMod1.isRunning) { ~procMod1.release };
  if(~procMod2.isRunning) { ~procMod2.release };
};

"ProcMod timing test ready.".postln;
"Run these commands to test:".postln;
"  ~playSequential.value;  // Play ProcMods sequentially".postln;
"  ~playOverlapped.value;  // Play ProcMods with overlap".postln;
"  ~playDirect.value;      // Direct timing without ProcEvents".postln;
"  ~releaseProcs.value;    // Safely release ProcMods".postln;
) 