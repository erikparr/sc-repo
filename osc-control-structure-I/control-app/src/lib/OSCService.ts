import OSC from 'osc-js';

class OSCService {
  private osc: OSC;

  constructor() {
    this.osc = new OSC({
      plugin: new OSC.WebsocketClientPlugin({
        port: 8080,
        host: 'localhost'
      })
    });
  }

  connect() {
    this.osc.open();
    console.log('OSC WebSocket connection opened');
  }

  sendNoteOn(note: number, velocity: number) {
    this.osc.send(new OSC.Message('/mpe/noteOn', note, velocity));
  }

  sendNoteOff(note: number, velocity: number) {
    this.osc.send(new OSC.Message('/mpe/noteOff', note, velocity));
  }

  disconnect() {
    this.osc.close();
  }
}

export const oscService = new OSCService(); 