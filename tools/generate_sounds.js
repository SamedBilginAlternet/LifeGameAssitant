#!/usr/bin/env node
/**
 * Generates the CRT sound effects bundled with the Flutter app.
 * Outputs to ../app/assets/audio/. Re-run any time the spec in
 * docs/DESIGN.md changes — the files are checked in for reproducibility.
 *
 *   node tools/generate_sounds.js
 *
 * No dependencies — uses only Node's built-in Buffer.
 */

const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 22050;
const PEAK = 0.25; // -12 dB ceiling per DESIGN.md

function writeWav(filePath, samples) {
  const numSamples = samples.length;
  const dataSize = numSamples * 2; // 16-bit mono
  const buf = Buffer.alloc(44 + dataSize);

  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataSize, 4);
  buf.write('WAVE', 8);

  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);            // subchunk size
  buf.writeUInt16LE(1, 20);             // PCM
  buf.writeUInt16LE(1, 22);             // mono
  buf.writeUInt32LE(SAMPLE_RATE, 24);
  buf.writeUInt32LE(SAMPLE_RATE * 2, 28); // byte rate
  buf.writeUInt16LE(2, 32);             // block align
  buf.writeUInt16LE(16, 34);            // bits per sample

  buf.write('data', 36);
  buf.writeUInt32LE(dataSize, 40);

  for (let i = 0; i < numSamples; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }

  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, buf);
  console.log(`  wrote ${filePath} (${numSamples} samples, ${(numSamples / SAMPLE_RATE * 1000).toFixed(0)}ms)`);
}

function envelope(t, durationSec, attack = 0.01, release = 0.02) {
  // Trapezoidal attack/sustain/release to kill clicks at edges.
  if (t < attack) return t / attack;
  const tailStart = durationSec - release;
  if (t > tailStart) return Math.max(0, (durationSec - t) / release);
  return 1;
}

function squareSamples(freq, durationSec, peak = PEAK) {
  const n = Math.round(durationSec * SAMPLE_RATE);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SAMPLE_RATE;
    const phase = (t * freq) % 1;
    const sample = phase < 0.5 ? peak : -peak;
    out[i] = sample * envelope(t, durationSec, 0.0005, 0.001);
  }
  return out;
}

function sineSamples(freq, durationSec, peak = PEAK) {
  const n = Math.round(durationSec * SAMPLE_RATE);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SAMPLE_RATE;
    out[i] = Math.sin(2 * Math.PI * freq * t) * peak * envelope(t, durationSec);
  }
  return out;
}

function sweepSamples(startFreq, endFreq, durationSec, peak = PEAK) {
  const n = Math.round(durationSec * SAMPLE_RATE);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SAMPLE_RATE;
    const k = t / durationSec;
    const freq = startFreq * Math.pow(endFreq / startFreq, k);
    phase += (2 * Math.PI * freq) / SAMPLE_RATE;
    out[i] = Math.sin(phase) * peak * envelope(t, durationSec, 0.005, 0.05);
  }
  return out;
}

function concat(...buffers) {
  const total = buffers.reduce((s, b) => s + b.length, 0);
  const out = new Float32Array(total);
  let offset = 0;
  for (const b of buffers) {
    out.set(b, offset);
    offset += b.length;
  }
  return out;
}

const ASSETS = path.resolve(__dirname, '..', 'app', 'assets', 'audio');

console.log('Generating CRT audio assets:');

// 1. key-click.wav — 6ms square wave at ~1100 Hz. The "8-bit click"
//    that plays once per typewriter character.
writeWav(path.join(ASSETS, 'key-click.wav'), squareSamples(1100, 0.006));

// 2. power-on.wav — 180ms exponential pitch sweep 200 Hz → 1500 Hz.
//    Played on day-swipe transitions ("CRT power-on flicker").
writeWav(path.join(ASSETS, 'power-on.wav'), sweepSamples(200, 1500, 0.180));

// 3. confirm.wav — two-tone arpeggio (800 Hz then 1200 Hz, 60 ms each).
//    Played on save / commit success.
writeWav(
  path.join(ASSETS, 'confirm.wav'),
  concat(sineSamples(800, 0.060), sineSamples(1200, 0.060)),
);

// 4. error.wav — descending two-tone (600 Hz then 300 Hz, 80 ms each).
writeWav(
  path.join(ASSETS, 'error.wav'),
  concat(sineSamples(600, 0.080), sineSamples(300, 0.080)),
);

console.log('Done.');
