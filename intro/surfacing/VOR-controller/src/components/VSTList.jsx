import React, { useEffect, useState, useCallback } from 'react';
import { initOSC, sendOSC } from '../services/oscService';

const VSTList = () => {
  const [vsts, setVsts] = useState([]);
  const [selectedVST, setSelectedVST] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [status, setStatus] = useState('Disconnected');

  // Handle parameter changes
  const handleParamChange = useCallback((param, value) => {
    if (!selectedVST) return;
    
    const numValue = parseFloat(value);
    if (!isNaN(numValue)) {
      // Update local state
      setSelectedVST(prev => ({
        ...prev,
        params: { ...(prev?.params || {}), [param]: numValue }
      }));
      
      // Send update to server
      sendOSC('/vst/set', selectedVST.name, param, numValue);
    }
  }, [selectedVST]);

  // Handle incoming OSC messages
  const handleOSCMessage = useCallback((message) => {
    console.log('Received OSC:', message);
    
    // Handle VST list response
    if (message.address === '/vst/list') {
      const vstData = message.args[0];
      if (Array.isArray(vstData)) {
        setVsts(vstData);
      }
      setStatus('Connected');
    }
    
    // Handle parameter updates
    else if (message.address === '/vst/params' && selectedVST) {
      const params = {};
      for (let i = 1; i < message.args.length; i += 2) {
        const paramName = message.args[i];
        const paramValue = message.args[i + 1];
        if (paramName !== undefined && paramValue !== undefined) {
          params[paramName] = paramValue;
        }
      }
      setSelectedVST(prev => ({
        ...prev,
        params: { ...(prev?.params || {}), ...params }
      }));
    }
  }, [selectedVST]);

  // Handle refresh button click
  const refreshList = useCallback(() => {
    if (isConnected) {
      sendOSC('/vst/list');
    }
  }, [isConnected]);

  // Initialize OSC connection and set up message handling
  useEffect(() => {
    let osc;
    let interval;

    const setupOSC = async () => {
      try {
        osc = await initOSC(handleOSCMessage);
        setIsConnected(true);
        setStatus('Connected');
        refreshList();
        interval = setInterval(refreshList, 2000);
      } catch (error) {
        console.error('OSC Error:', error);
        setStatus(`Error: ${error.message}`);
      }
    };

    setupOSC();

    return () => {
      if (interval) clearInterval(interval);
      if (osc?.close) osc.close();
      setIsConnected(false);
      setStatus('Disconnected');
    };
  }, [handleOSCMessage, refreshList]);

  // Handle VST selection
  const handleVSTSelect = useCallback((vst) => {
    setSelectedVST(vst);
    // Request parameters for the selected VST
    if (vst?.name) {
      sendOSC('/vst/get', vst.name);
    }
  }, []);

  return (
    <div className="vst-list">
      <div className="status-bar">
        <span>Status: {status}</span>
        <button 
          onClick={refreshList} 
          disabled={!isConnected}
          className="refresh-btn"
        >
          Refresh
        </button>
      </div>
      
      <div className="vst-container">
        <div className="vst-instance-list">
          <h3>VST Instances</h3>
          {vsts.length === 0 ? (
            <p>No VST instances found</p>
          ) : (
            <ul>
              {vsts.map(vst => (
                <li 
                  key={vst.name} 
                  className={`vst-item ${selectedVST?.name === vst.name ? 'selected' : ''}`}
                  onClick={() => handleVSTSelect(vst)}
                  style={{ fontWeight: selectedVST?.name === vst.name ? 'bold' : 'normal' }}
                >
                  {vst.name} - {vst.active ? 'Active' : 'Inactive'}
                </li>
              ))}
            </ul>
          )}
        </div>
        
        {selectedVST && (
          <div className="vst-controller">
            <h3>{selectedVST.name} Controls</h3>
            {selectedVST.params ? (
              <div className="params-container">
                {Object.entries(selectedVST.params).map(([param, value]) => (
                  <div key={param} className="param-control">
                    <label>{param}</label>
                    <div className="slider-container">
                      <input
                        type="range"
                        min="0"
                        max="1"
                        step="0.01"
                        value={value}
                        onChange={(e) => handleParamChange(param, e.target.value)}
                        className="param-slider"
                      />
                      <span className="param-value">
                        {typeof value === 'number' ? value.toFixed(2) : String(value)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p>Loading parameters...</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default VSTList;