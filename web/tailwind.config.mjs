/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,ts,jsx,tsx,md,mdx}'],
  theme: {
    extend: {
      colors: {
        // Amber CRT palette — mirrors app/theme/themes.dart so the
        // landing page and the app share a visual vocabulary.
        canvas: '#0A0606',
        surface: '#120A07',
        amber: {
          ghost: '#3a2102',
          dim: '#7a4404',
          DEFAULT: '#ffb200',
          bright: '#ffcb47',
        },
      },
      fontFamily: {
        body: ['"VT323"', 'monospace'],
        ui: ['"Share Tech Mono"', 'monospace'],
        header: ['"Press Start 2P"', 'monospace'],
      },
      boxShadow: {
        glow: '0 0 12px rgba(255, 178, 0, 0.55), 0 0 32px rgba(255, 178, 0, 0.22)',
      },
      keyframes: {
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 8px rgba(255, 178, 0, 0.45)' },
          '50%':      { boxShadow: '0 0 22px rgba(255, 178, 0, 0.85)' },
        },
        scanline: {
          '0%':   { transform: 'translateY(0)' },
          '100%': { transform: 'translateY(-4px)' },
        },
      },
      animation: {
        'pulse-glow': 'pulseGlow 1.6s ease-in-out infinite',
        'scanline-drift': 'scanline 4s linear infinite',
      },
    },
  },
};
