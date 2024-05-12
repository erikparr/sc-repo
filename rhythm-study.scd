
(
~pseq = Pbind(
    \type, \vst_midi,
    \vst, ~vsti,
    \degree, Pn(Pseries(-6, 3, 2), inf),
    \dur, Pseq([0.15, 0.2, 0.25, 0.3], inf), // complex rhythm pattern
    \legato, Pwrand([0.4, 1.01], [0.8, 0.2], inf),
    \amp, 0.5 // velocity
).play;

(~pseq = Pbind(
    \type, \vst_midi,
    \vst, ~vsti,
    \degree, Pn(Pseries(-12, 3, 2), inf),
    \dur, Pseq([0.2, 0.2, 0.2, 0.2], inf), // complex rhythm pattern
    \legato, Pseq([0.4, 0.4, 0.4, 0.4], inf),
    \amp, 0.5 // velocity
).play;)
)
s

~pseq.start;~pseq2.start;
~pseq.stop;~pseq2.stop;
