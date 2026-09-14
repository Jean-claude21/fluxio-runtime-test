import { defineConfig } from 'vite'
import { devtools } from '@tanstack/devtools-vite'

import { tanstackStart } from '@tanstack/react-start/plugin/vite'

import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { nitro } from 'nitro/vite'
import netlify from '@netlify/vite-plugin'

const config = defineConfig({
  resolve: { tsconfigPaths: true },
  server: {
    host: true,
    // Runtime Fluxio : le conteneur est servi derriere le proxy Coolify sur un
    // domaine externe. Vite bloque les hotes inconnus par defaut (403).
    allowedHosts: true,
    hmr: { clientPort: 443, protocol: 'wss' },
  },
  plugins: [
    devtools(),
    nitro({ rollupConfig: { external: [/^@sentry\//] } }),
    tailwindcss(),
    tanstackStart(),
    viteReact(),
    netlify(),
  ],
})

export default config
