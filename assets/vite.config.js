import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [
    tailwindcss(),
    resumeStdinPlugin(),
  ],
  build: {
    outDir: "../priv/static",
    emptyOutDir: false,
    rollupOptions: {
      input: {
        app: "js/app.js",
      },
      output: {
        // Match paths expected by root.html.heex in prod: /assets/app.js, /assets/app.css
        entryFileNames: "assets/[name].js",
        chunkFileNames: "assets/[name].js",
        assetFileNames: "assets/[name].[ext]",
      },
    },
  },
  // base "./" breaks the Vite dev server; only needed for prod build paths
  server: {
    port: 4432,
    host: "0.0.0.0",
    origin: "http://localhost:4432",
  },
});

// Keeps the Vite dev server alive when Phoenix spawns it as a watcher
// (Phoenix closes stdin when the watcher should stop)
function resumeStdinPlugin() {
  return {
    name: "resume-stdin",
    configureServer() {
      if (process.env.WATCH_STDIN === "1") {
        process.stdin.resume();
      }
    },
  };
}
