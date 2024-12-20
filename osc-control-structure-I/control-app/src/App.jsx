import { useState, useEffect } from 'react';
import { DensityControl } from './components/DensityControl';
import { ScaleSelector } from './components/ScaleSelector';
import { NoteGenerator } from './lib/NoteGenerator';
import './App.css';

const SCALES = {
  major: [0, 2, 4, 5, 7, 9, 11],
  minor: [0, 2, 3, 5, 7, 8, 10],
  pentatonic: [0, 2, 4, 7, 9],
  chromatic: Array.from({ length: 12 }, (_, i) => i)
};

function App() {
  const [density, setDensity] = useState(0.5);
  const [scale, setScale] = useState('major');
  const [rootNote, setRootNote] = useState(60); // Middle C
  const [generator, setGenerator] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);

  useEffect(() => {
    const noteGen = new NoteGenerator();
    setGenerator(noteGen);

    return () => {
      if (noteGen) {
        noteGen.cleanup();
      }
    };
  }, []);

  const handleScaleChange = (newScale, newRoot) => {
    setScale(newScale);
    setRootNote(newRoot);
    if (generator) {
      generator.setScale(SCALES[newScale]);
    }
  };

  const handleDensityChange = (value) => {
    setDensity(value);
    if (generator) {
      generator.setDensity(value);
    }
  };

  const togglePlayback = () => {
    if (!isPlaying && generator) {
      generator.start();
    } else if (generator) {
      generator.stop();
    }
    setIsPlaying(!isPlaying);
  };

  return (
    <div className="app-container">
      <h1>Generative MPE Controller</h1>
      
      <div className="controls">
        <DensityControl 
          value={density} 
          onChange={handleDensityChange} 
        />
        
        <ScaleSelector 
          scale={scale} 
          rootNote={rootNote} 
          onChange={handleScaleChange}
        />

        <button 
          onClick={togglePlayback}
          className={`playback-button ${isPlaying ? 'playing' : ''}`}
        >
          {isPlaying ? 'Stop' : 'Start'}
        </button>
      </div>
    </div>
  );
}

export default App;
