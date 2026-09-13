import { defineConfig } from 'vite';

export default defineConfig({
  base: process.env.VITE_BASE_PATH || '/',
  server: {
    proxy: {
      '/api': {
        target: process.env.FORANEO_API_ORIGIN || 'http://localhost:8787',
        changeOrigin: true
      }
    }
  }
});
