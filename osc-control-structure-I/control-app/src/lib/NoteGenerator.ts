import { oscService } from './OSCService';

export class NoteGenerator {
  private density: number = 0.5;
  private scale: number[] = [0, 2, 4, 5, 7, 9, 11];
  private rootNote: number = 60;
  private range: [number, number] = [48, 72];
  private intervalId: NodeJS.Timer | null = null;
  private activeNotes: Map<number, number> = new Map();

  constructor() {
    oscService.connect();
  }

  setDensity(value: number) {
    this.density = Math.max(0, Math.min(1, value));
  }

  setScale(scale: number[]) {
    this.scale = scale;
  }

  private getRandomNote(): number {
    const octaveRange = Math.floor((this.range[1] - this.range[0]) / 12);
    const octave = Math.floor(Math.random() * octaveRange) * 12;
    const scaleNote = this.scale[Math.floor(Math.random() * this.scale.length)];
    return this.rootNote + octave + scaleNote;
  }

  start() {
    this.intervalId = setInterval(() => {
      if (Math.random() < this.density) {
        const note = this.getRandomNote();
        const velocity = 0.3 + Math.random() * 0.7;
        oscService.sendNoteOn(note, velocity);
        this.activeNotes.set(note, velocity);
        
        setTimeout(() => {
          const storedVelocity = this.activeNotes.get(note) || 0;
          oscService.sendNoteOff(note, storedVelocity);
          this.activeNotes.delete(note);
        }, 500 + Math.random() * 2000);
      }
    }, 100);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      
      // Clean up any active notes with their stored velocities
      this.activeNotes.forEach((velocity, note) => {
        oscService.sendNoteOff(note, velocity);
      });
      this.activeNotes.clear();
    }
  }

  cleanup() {
    this.stop();
    oscService.disconnect();
  }
} 