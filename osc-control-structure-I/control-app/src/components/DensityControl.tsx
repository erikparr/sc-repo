import React from 'react';

interface DensityControlProps {
  value: number;
  onChange: (value: number) => void;
}

export const DensityControl: React.FC<DensityControlProps> = ({ value, onChange }) => {
  return (
    <div className="density-control">
      <h3>Note Density</h3>
      <input 
        type="range"
        min="0"
        max="1"
        step="0.01"
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
      />
      <span>{Math.round(value * 100)}%</span>
    </div>
  );
}; 