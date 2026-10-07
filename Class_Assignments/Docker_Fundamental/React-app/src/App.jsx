import { useState } from "react";

export default function App() {
  const [clicks, setClicks] = useState(0);
  return (
    <div style={{ fontFamily: "sans-serif", textAlign: "center", marginTop: "15%" }}>
      <h1>Hello World</h1>
      <p>from a React app (built with Vite, served by Nginx)</p>
      <button onClick={() => setClicks(clicks + 1)}>Clicked {clicks} times</button>
    </div>
  );
}
