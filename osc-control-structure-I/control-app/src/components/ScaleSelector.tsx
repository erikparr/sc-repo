import React from 'react';

const SCALES = {
  major: [0, 2, 4, 5, 7, 9, 11],
  minor: [0, 2, 3, 5, 7, 8, 10],
  pentatonic: [0, 2, 4, 7, 9],
  chromatic: Array.from({ length: 12 }, (_, i) => i)
};

interface ScaleSelectorProps {
  scale: keyof typeof SCALES;
  rootNote: number;
  onChange: (scale: keyof typeof SCALES, rootNote: number) => void;
}

export const ScaleSelector: React.FC<ScaleSelectorProps> = ({ 
  scale, 
  rootNote, 
  onChange 
}) => {
  return (
    <div className="scale-selector">
      <select 
        value={scale} 
        onChange={(e) => onChange(e.target.value as keyof typeof SCALES, rootNote)}
      >
        {Object.keys(SCALES).map(s => (
          <option key={s} value={s}>{s}</option>
        ))}
      </select>
      <input 
        type="number" 
        min="0" 
        max="11" 
        value={rootNote}
        onChange={(e) => onChange(scale, parseInt(e.target.value))}
      />
    </div>
  );
};
