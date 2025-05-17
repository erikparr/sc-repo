import { useEffect } from 'react';
import VSTList from './components/VSTList.jsx';
import { initOSC } from './services/oscService';
import './App.css';

function App() {
  useEffect(() => {
    const osc = initOSC((message) => {
      console.log('OSC Message:', message);
    });

    return () => {
      osc.close();
    };
  }, []);

  return (
    <div className="app">
      <h1>VST Controller</h1>
      <VSTList />
    </div>
  );
}

export default App;
