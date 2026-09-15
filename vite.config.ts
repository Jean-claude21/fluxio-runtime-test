import { defineConfig } from 'vite'
import { devtools } from '@tanstack/devtools-vite'

import { tanstackStart } from '@tanstack/react-start/plugin/vite'

import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { nitro } from 'nitro/vite'
import netlify from '@netlify/vite-plugin'

// The Netlify plugin is only needed to produce the production build. In the
// persistent dev runtime it loads an emulation layer that breaks `vite dev`,
// so it is enabled for builds only.
const isDevRuntime = process.env.FLUXIO_REPO !== undefined

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
    ...(isDevRuntime ? [] : [netlify()]),
  ],
})

export default config
