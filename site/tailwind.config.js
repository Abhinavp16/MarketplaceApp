/** @type {import('tailwindcss').Config} */
// Note: Tailwind v4 reads theme tokens from the @theme block in app/globals.css.
// This file mirrors the same generic indigo/teal demo palette for tooling.
module.exports = {
    content: [
        "./app/**/*.{js,ts,jsx,tsx,mdx}",
        "./components/**/*.{js,ts,jsx,tsx,mdx}",
    ],
    theme: {
        extend: {
            colors: {
                brand: {
                    primary: '#3730a3',
                    secondary: '#4f46e5',
                    light: '#e0e7ff',
                    dark: '#1e1b4b',
                    accent: '#0d9488',
                },
                text: {
                    primary: '#131530',
                    secondary: '#5b6079',
                },
                neutral: {
                    background: '#e0e7ff',
                    surface: '#eef2ff',
                },
            },
            fontFamily: {
                primary: ['"Cabinet Grotesk"', 'sans-serif'],
                secondary: ['"Cabinet Grotesk"', 'system-ui', 'sans-serif'],
            },
            boxShadow: {
                cta: '0 4px 14px 0 rgba(55, 48, 163, 0.39)',
            },
        },
    },
    plugins: [],
};
