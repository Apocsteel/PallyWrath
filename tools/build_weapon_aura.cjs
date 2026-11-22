const fs = require("node:fs");
const path = require("node:path");

const media = path.join(__dirname, "..", "Media");
const width = 128;
const frames = 16;
const tau = Math.PI * 2;
const widen = 1.375; // Display at 176 × 352 UI units to keep the original artwork aligned.

// Per-weapon outlines in the default upright view. Points are relative to its center.
const modelOutlines = {
    model_thunderfury: [
        [2,-111],[7,-79],[9,-47],[14,-13],[21,9],[12,7],[7,20],[2,23],
        [2,78],[13,85],[4,90],[0,105],[-4,93],[-5,43],[-13,41],[-5,36],
        [-14,31],[-6,27],[-9,18],[-22,14],[-18,0],[-15,-21],[-8,-59],[-3,-85],
    ],
    model_corrupted: [
        [-35,-105],[-14,-89],[12,-79],[26,-77],[17,-56],[13,-27],[14,18],
        [32,19],[23,32],[12,38],[0,40],[-2,83],[9,87],[-5,103],[-20,88],
        [-9,83],[-7,41],[-18,41],[-22,22],[-13,19],[-15,-18],[-32,-30],
        [-34,-45],[-26,-57],[-24,-75],
    ],
    model_ashbringer: [
        [-20,-84],[-7,-76],[13,-68],[10,-56],[11,-28],[11,7],[20,8],
        [17,22],[9,30],[-12,29],[-17,24],[-17,13],[-10,9],[-11,-25],
        [-17,-28],[-23,-35],[-24,-44],[-20,-51],[-13,-54],[-11,-56],[-14,-62],
    ],
    model_rivendare: [
        [0,-92],[3,-79],[5,-49],[4,-33],[6,-15],[5,-4],[8,21],
        [11,29],[22,29],[16,35],[7,41],[-7,41],[-16,35],[-22,29],[-11,29],
        [-8,21],[-5,-4],[-6,-15],[-4,-33],[-5,-49],[-3,-79],
    ],
};
const flameEnds = { model_ashbringer: 164, model_rivendare: 172 };

function silhouette(name, height) {
    if (name === "sulfuras") {
        return (x, y) => ((x - 64) / 30) ** 2 + ((y - 68) / 26) ** 2 <= 1;
    }
    const outline = modelOutlines[name];
    if (outline) {
        const units = widen * 0.768; // Reference preview scaling used to measure the outlines.
        return (x, y) => {
            const px = (x + 0.5 - width / 2) * units;
            const py = (y + 0.5 - height / 2) * units;
            let inside = false;
            for (let i = 0; i < outline.length; i++) {
                const [ax, ay] = outline[i];
                const [bx, by] = outline[(i + 1) % outline.length];
                if ((ay > py) !== (by > py) && px < ax + (bx - ax) * (py - ay) / (by - ay)) inside = !inside;
            }
            return inside;
        };
    }
    const tga = fs.readFileSync(path.join(media, name + ".tga"));
    const w = tga.readUInt16LE(12), h = tga.readUInt16LE(14);
    if (tga[2] !== 2 || tga[16] !== 32 || w !== 256 || h !== 512) {
        throw new Error("Expected a 256 × 512 uncompressed 32-bit TGA for " + name);
    }
    const topDown = (tga[17] & 32) !== 0;
    const start = 18 + tga[0];
    return (x, y) => {
        const u = Math.floor(w / 2 + (x + 0.5 - width / 2) * widen * 2);
        const v = Math.floor(h / 2 + (y + 0.5 - height / 2) * widen * 2);
        if (u < 0 || u >= w || v < 0 || v >= h) return false;
        const row = topDown ? v : h - 1 - v;
        return tga[start + (row * w + u) * 4 + 3] >= 60;
    };
}

function distanceField(inside, height) {
    const field = new Float32Array(width * height).fill(1e4);
    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            if (inside(x, y)) field[y * width + x] = 0;
        }
    }
    for (const step of [1, -1]) {
        for (let y = step > 0 ? 0 : height - 1; y >= 0 && y < height; y += step) {
            for (let x = step > 0 ? 0 : width - 1; x >= 0 && x < width; x += step) {
                const i = y * width + x;
                if (x - step >= 0 && x - step < width) {
                    field[i] = Math.min(field[i], field[i - step] + 1);
                }
                if (y - step < 0 || y - step >= height) continue;
                const previousRow = i - step * width;
                field[i] = Math.min(field[i], field[previousRow] + 1);
                if (x > 0) field[i] = Math.min(field[i], field[previousRow - 1] + Math.SQRT2);
                if (x < width - 1) field[i] = Math.min(field[i], field[previousRow + 1] + Math.SQRT2);
            }
        }
    }
    return field;
}

function build(name) {
    const mace = name === "sulfuras";
    const model = Boolean(modelOutlines[name]);
    const flameEnd = flameEnds[name];
    const height = mace ? 128 : 256;
    const rise = flameEnd ? 11 : mace || model ? 17 : 8;
    const variation = flameEnd ? 6 : mace || model ? 8 : 5;
    const reach = flameEnd ? 24 : mace || model ? 43 : 29;
    const edgeWidth = flameEnd ? 6 : 9;
    const inside = silhouette(name, height);
    const distance = distanceField(inside, height);
    const inset = distanceField((x, y) => !inside(x, y), height);
    const atlasWidth = width * frames;
    const output = Buffer.alloc(18 + atlasWidth * height * 4);
    output[2] = 2;
    output.writeUInt16LE(atlasWidth, 12);
    output.writeUInt16LE(height, 14);
    output[16] = 32;
    output[17] = 40;

    for (let f = 0; f < frames; f++) {
        const time = tau * f / frames;
        for (let y = 4; y < height - 4; y++) {
            // The blade ends at the crossguard. Let the flames die out above the grip.
            const fadeAtGuard = flameEnd ? Math.max(0, Math.min(1, (flameEnd - y) / 14)) : 1;
            if (!fadeAtGuard) break;
            for (let x = 4; x < width - 4; x++) {
                const wave = Math.sin(x * 0.37 + y * 0.15 + time)
                    + 0.53 * Math.sin(x * 0.78 - y * 0.22 - time * 2);
                const lean = Math.round(3 * Math.sin(y * 0.17 + x * 0.13 + time));
                const tip = Math.round(rise + variation * wave);
                const sampleX = Math.max(0, Math.min(width - 1, x + lean));
                const sampleY = Math.max(0, Math.min(height - 1, y + tip));
                const edge = distance[y * width + x];
                let lift = distance[sampleY * width + sampleX];
                if (model) {
                    const side = Math.round(Math.max(0, tip) * (flameEnd ? 0.58 : 0.69));
                    const sideRow = Math.min(height - 1, y + Math.round(tip * 0.58)) * width;
                    lift = Math.min(lift, distance[sideRow + Math.min(width - 1, x + side)],
                        distance[sideRow + Math.max(0, x - side)]);
                }
                const core = Math.max(0, 1 - edge / edgeWidth) ** 2;
                const tongues = Math.max(0, 1 - lift / 12) ** 2 * Math.max(0, 1 - edge / reach);
                const flicker = 0.74 + 0.26 * Math.sin(x * 0.53 + y * 0.24 + time);
                const rim = Math.max(0, 1 - inset[y * width + x] / 4);
                const alpha = Math.min(255, Math.round((218 * core + 232 * tongues * flicker) * rim * fadeAtGuard));
                if (!alpha) continue;
                const i = 18 + (y * atlasWidth + f * width + x) * 4;
                output[i] = 255;
                output[i + 1] = 255;
                output[i + 2] = 255;
                output[i + 3] = alpha;
            }
        }
    }
    fs.writeFileSync(path.join(media, "aura_" + name + ".tga"), output);
}

const names = process.argv.slice(2);
if (names.length === 0 || names.some(name => !/^[a-z][a-z0-9_]*$/.test(name))) {
    throw new Error("Pass one or more artwork basenames, for example: shadowmourne");
}
for (const name of names) build(name);
