'use client';
import { useEffect, useRef } from 'react';

// 8x8 Bayer threshold matrix (values 0..63), built recursively.
const BAYER_8 = (() => {
    let matrix = [[0]];
    while (matrix.length < 8) {
        const size = matrix.length;
        const next = Array.from({ length: size * 2 }, () => new Array(size * 2));
        for (let y = 0; y < size; y += 1) {
            for (let x = 0; x < size; x += 1) {
                const value = matrix[y][x] * 4;
                next[y][x] = value;
                next[y][x + size] = value + 2;
                next[y + size][x] = value + 3;
                next[y + size][x + size] = value + 1;
            }
        }
        matrix = next;
    }
    return matrix;
})();

function hexToRgb(hex) {
    const value = parseInt(hex.replace('#', ''), 16);
    return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
}

/**
 * Ordered-dither glow: a radial falloff from (originX, originY) rendered as
 * chunky on/off pixels. Fills its positioned parent; purely decorative.
 * originX/originY are fractions of the box (1, 0 = top-right corner).
 */
export default function DitherField({
    color = '#dfe8d3',
    alpha = 0.32,
    pixel = 3,
    originX = 1,
    originY = 0,
    reach = 0.95,
    className = '',
}) {
    const canvasRef = useRef(null);

    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return undefined;
        const [r, g, b] = hexToRgb(color);
        const a = Math.round(alpha * 255);

        const draw = () => {
            const { width, height } = canvas.getBoundingClientRect();
            if (!width || !height) return;
            const cols = Math.ceil(width / pixel);
            const rows = Math.ceil(height / pixel);
            canvas.width = cols;
            canvas.height = rows;
            const context = canvas.getContext('2d');
            const image = context.createImageData(cols, rows);
            const cx = originX * cols;
            const cy = originY * rows;
            const radius = Math.hypot(cols, rows) * reach;
            for (let y = 0; y < rows; y += 1) {
                for (let x = 0; x < cols; x += 1) {
                    const falloff = 1 - Math.hypot(x - cx, y - cy) / radius;
                    const intensity = falloff <= 0 ? 0 : falloff * falloff;
                    if (intensity > (BAYER_8[y % 8][x % 8] + 0.5) / 64) {
                        const index = (y * cols + x) * 4;
                        image.data[index] = r;
                        image.data[index + 1] = g;
                        image.data[index + 2] = b;
                        image.data[index + 3] = a;
                    }
                }
            }
            context.putImageData(image, 0, 0);
        };

        draw();
        const observer = new ResizeObserver(draw);
        observer.observe(canvas);
        return () => observer.disconnect();
    }, [color, alpha, pixel, originX, originY, reach]);

    return (
        <canvas
            ref={canvasRef}
            aria-hidden="true"
            className={`pointer-events-none absolute inset-0 h-full w-full [image-rendering:pixelated] ${className}`}
        />
    );
}
