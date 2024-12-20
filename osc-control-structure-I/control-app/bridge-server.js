import OSC from 'osc-js';

const config = {
  udpClient: {
    port: 57120,
    host: 'localhost'
  },
  wsServer: {
    port: 8080
  }
};

const osc = new OSC({ plugin: new OSC.BridgePlugin(config) });

osc.open();
console.log('OSC Bridge running on port 8080');

// Handle errors and cleanup
process.on('SIGINT', () => {
  console.log('Closing OSC bridge...');
  osc.close();
  process.exit();
});
