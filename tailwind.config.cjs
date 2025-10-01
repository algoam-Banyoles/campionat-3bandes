/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{svelte,js,ts}'],
  theme: {
    extend: {
      fontSize: {
        'xs': ['1rem', { lineHeight: '1.6' }],        // 16px, era 12px
        'sm': ['1.125rem', { lineHeight: '1.6' }],    // 18px, era 14px
        'base': ['1.25rem', { lineHeight: '1.6' }],   // 20px, era 16px
        'lg': ['1.375rem', { lineHeight: '1.6' }],    // 22px, era 18px
        'xl': ['1.5rem', { lineHeight: '1.5' }],      // 24px, era 20px
        '2xl': ['1.75rem', { lineHeight: '1.4' }],    // 28px, era 24px
        '3xl': ['2.25rem', { lineHeight: '1.3' }],    // 36px, era 30px
        '4xl': ['2.5rem', { lineHeight: '1.2' }],     // 40px, era 36px
      },
      colors: {
        // High contrast colors for accessibility
        'accessible': {
          'black': '#000000',
          'white': '#ffffff',
          'blue': '#0000ee',
          'purple': '#551a8b',
          'red': '#cc0000',
          'green': '#008000',
        }
      },
      spacing: {
        // Larger touch targets
        'touch': '48px',
        'touch-lg': '56px',
      }
    }
  },
  plugins: [
    require('@tailwindcss/typography'),
    // Custom plugin for accessibility utilities
    function({ addUtilities }) {
      addUtilities({
        '.focus-visible-enhanced': {
          '&:focus-visible': {
            outline: '3px solid #2563eb',
            outlineOffset: '3px',
            boxShadow: '0 0 0 2px white, 0 0 0 5px #2563eb',
          }
        },
        '.touch-target': {
          minHeight: '48px',
          minWidth: '48px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        },
        '.sr-only': {
          position: 'absolute',
          width: '1px',
          height: '1px',
          padding: '0',
          margin: '-1px',
          overflow: 'hidden',
          clip: 'rect(0, 0, 0, 0)',
          whiteSpace: 'nowrap',
          border: '0',
        }
      })
    }
  ]
}
