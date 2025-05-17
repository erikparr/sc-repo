// src/services/oscService.js
import OSC from 'osc-js';

const osc = new OSC({
    udpClient: { port: 57121 },  // Listen port
    udpServer: { port: 57120 }   // Send port
});

export const initOSC = (onMessage) => {
    osc.on('open', () => console.log('OSC Connected'));
    osc.on('*', message => onMessage(message));
    osc.open();
    return osc;
};

export const sendOSC = (address, ...args) => {
    osc.send(new OSC.Message(address, ...args));
};