/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./app/**/*.{js,ts,jsx,tsx,mdx}",
        "./components/**/*.{js,ts,jsx,tsx,mdx}",
    ],
    theme: {
        extend: {
            colors: {
                brand: {
                    primary: '#f97316',
                    secondary: '#ea580c',
                    light: '#ffedd5',
                    dark: '#7c2d12',
                },
                text: {
                    primary: '#111827',
                    secondary: '#6b7280',
                },
                neutral: {
                    background: '#F0F8FF',
                    surface: '#f7fbff',
                },
            },
            fontFamily: {
                primary: ['"Inter Tight"', 'sans-serif'],
                secondary: ['Inter', 'sans-serif'],
            },
            boxShadow: {
                cta: '0 4px 14px 0 rgba(249, 115, 22, 0.39)',
            },
        },
    },
    plugins: [],
};
