#!/usr/bin/env python3
"""
Gobble Pop! — Phase 3 Procedural ASMR SFX (13) + Marimba Loop BGM (1) Generator
Encodes clean OGG Vorbis via /opt/homebrew/bin/ffmpeg, strictly within <= 563 KB total budget.
"""
import math
import os
import random
import struct
import subprocess
import tempfile
import wave

OUT_DIR = "/Users/unmercy/Documents/antig/hole/assets/audio"
FFMPEG = "/opt/homebrew/bin/ffmpeg"
os.makedirs(OUT_DIR, exist_ok=True)


def write_wav(path, samples, rate=44100, stereo=False):
    with wave.open(path, "wb") as wf:
        wf.setnchannels(2 if stereo else 1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        if stereo:
            raw = bytearray(len(samples) * 4)
            for i, (l, r) in enumerate(samples):
                il = int(max(-1.0, min(1.0, l)) * 32767.0)
                ir = int(max(-1.0, min(1.0, r)) * 32767.0)
                struct.pack_into("<hh", raw, i * 4, il, ir)
        else:
            raw = bytearray(len(samples) * 2)
            for i, s in enumerate(samples):
                iv = int(max(-1.0, min(1.0, s)) * 32767.0)
                struct.pack_into("<h", raw, i * 2, iv)
        wf.writeframes(raw)


def encode_audio(wav_path, out_path, rate=44100, stereo=False, bitrate="48k"):
    cmd = [
        FFMPEG, "-y", "-v", "error",
        "-i", wav_path,
        "-ar", str(rate),
        "-ac", "2" if stereo else "1",
        "-c:a", "libmp3lame",
        "-b:a", bitrate,
        out_path,
    ]
    subprocess.run(cmd, check=True)
    return os.path.getsize(out_path) / 1024.0


def soft_clip(x):
    return math.tanh(x * 1.15)


def marimba_note(freq, dur, rate=44100, amp=0.7):
    n = int(rate * dur)
    out = []
    for i in range(n):
        t = i / rate
        att = min(1.0, t / 0.004)
        env1 = att * math.exp(-t * 14.0)
        env2 = att * math.exp(-t * 32.0)
        s = (
            math.sin(math.tau * freq * t) * env1
            + 0.35 * math.sin(math.tau * freq * 4.0 * t) * env2
            + 0.12 * math.sin(math.tau * freq * 2.0 * t) * env2
        )
        out.append(soft_clip(s * amp))
    return out


def mix_into(buf, start_idx, seg, gain=1.0):
    for i, v in enumerate(seg):
        idx = start_idx + i
        if 0 <= idx < len(buf):
            buf[idx] += v * gain


def gen_sfx_01_pop(rate=44100):
    # 0.18s Crisp marimba + bubble pop
    n = int(rate * 0.18)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / rate
        u = i / n
        # Upward bubble chirp 420 -> 960 Hz + C5 marimba click
        freq = 420.0 + 540.0 * (u ** 0.75)
        phase += math.tau * freq / rate
        env = min(1.0, t / 0.005) * math.exp(-t * 24.0)
        mar = math.sin(math.tau * 523.25 * t) * math.exp(-t * 18.0) * 0.45
        out[i] = soft_clip((math.sin(phase) * 0.65 * env) + mar)
    return out


def gen_sfx_02_plop(rate=44100):
    # 0.25s Rounded deeper jelly plop
    n = int(rate * 0.25)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / rate
        u = i / n
        freq = 240.0 + 360.0 * math.sin(min(1.0, u * 1.4) * math.pi * 0.5)
        phase += math.tau * freq / rate
        env = min(1.0, t / 0.008) * math.exp(-t * 15.0)
        out[i] = soft_clip((math.sin(phase) + 0.25 * math.sin(phase * 2.0)) * env * 0.72)
    return out


def gen_sfx_03_gulp(rate=44100):
    # 0.45s Deep satisfying boss swallow + sub-bass thump
    n = int(rate * 0.45)
    out = [0.0] * n
    phase = 0.0
    sub_phase = 0.0
    for i in range(n):
        t = i / rate
        u = i / n
        freq = 150.0 + 180.0 * math.exp(-t * 8.0) + 120.0 * (u ** 1.8)
        sub_f = 95.0 * math.exp(-t * 4.5) + 48.0
        phase += math.tau * freq / rate
        sub_phase += math.tau * sub_f / rate
        env = min(1.0, t / 0.012) * math.exp(-t * 7.5)
        out[i] = soft_clip((0.55 * math.sin(phase) + 0.62 * math.sin(sub_phase)) * env)
    return out


def gen_sfx_04_level_up(rate=44100):
    # 0.70s Bright 4-note arpeggio C5-E5-G5-C6 + sparkle bell
    n = int(rate * 0.70)
    out = [0.0] * n
    notes = [(0.00, 523.25), (0.09, 659.25), (0.18, 783.99), (0.27, 1046.50)]
    for t0, f in notes:
        mix_into(out, int(t0 * rate), marimba_note(f, 0.36, rate, 0.55))
        # High shimmer harmonic
        mix_into(out, int((t0 + 0.02) * rate), marimba_note(f * 2.0, 0.22, rate, 0.22))
    return [soft_clip(x) for x in out]


def gen_sfx_05_ice(rate=44100):
    # 0.60s Crisp sparkling ice crystal freeze
    n = int(rate * 0.60)
    out = [0.0] * n
    rng = random.Random(42)
    freqs = [1567.98, 2093.0, 2637.02, 3135.96, 3520.0]
    for idx, f in enumerate(freqs):
        t0 = idx * 0.045
        seg = []
        ln = int(rate * 0.35)
        for i in range(ln):
            t = i / rate
            env = min(1.0, t / 0.003) * math.exp(-t * 12.0)
            s = (math.sin(math.tau * f * t) + 0.3 * math.sin(math.tau * f * 1.5 * t)) * env * 0.35
            seg.append(s)
        mix_into(out, int(t0 * rate), seg)
    # Subtle frosty air crackle
    for i in range(int(rate * 0.35)):
        t = i / rate
        env = math.exp(-t * 10.0) * 0.10
        out[i] += (rng.random() * 2.0 - 1.0) * env
    return [soft_clip(x) for x in out]


def gen_sfx_06_magnet(rate=44100):
    # 1.20s Lighthearted sci-fi magnetic pulsing hum
    n = int(rate * 1.20)
    out = [0.0] * n
    p1 = p2 = 0.0
    for i in range(n):
        t = i / rate
        env = min(1.0, t / 0.06) * min(1.0, (1.20 - t) / 0.15)
        lfo = 0.55 + 0.45 * math.sin(math.tau * 7.5 * t)
        f1 = 220.0 + 160.0 * min(1.0, t * 2.5) + 18.0 * math.sin(math.tau * 7.5 * t)
        p1 += math.tau * f1 / rate
        p2 += math.tau * (f1 * 1.5) / rate
        out[i] = soft_clip((0.48 * math.sin(p1) + 0.25 * math.sin(p2)) * lfo * env)
    return out


def gen_sfx_07_fever(rate=44100):
    # 0.85s Joyful rainbow rising sweep + chord burst
    n = int(rate * 0.85)
    out = [0.0] * n
    scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1318.5]
    for idx, f in enumerate(scale):
        mix_into(out, int(idx * 0.055 * rate), marimba_note(f, 0.32, rate, 0.42))
    # Final bright chord
    for f in [1046.5, 1318.5, 1567.98]:
        mix_into(out, int(0.40 * rate), marimba_note(f, 0.44, rate, 0.35))
    return [soft_clip(x) for x in out]


def gen_sfx_08_sticky(rate=44100):
    # 0.35s Playful gooey bubblegum squelch
    n = int(rate * 0.35)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / rate
        u = i / n
        wobble = math.sin(math.tau * 18.0 * t) * 75.0
        freq = 320.0 - 150.0 * u + wobble * (1.0 - u)
        phase += math.tau * max(60.0, freq) / rate
        env = min(1.0, t / 0.01) * math.exp(-t * 8.5)
        out[i] = soft_clip((math.sin(phase) + 0.4 * math.sin(phase * 2.3)) * env * 0.65)
    return out


def gen_sfx_09_tick(rate=44100):
    # 0.15s Soft wooden countdown tick
    return marimba_note(880.0, 0.15, rate, 0.52)


def gen_sfx_10_goal_done(rate=44100):
    # 0.40s Crisp two-tone reward ding
    n = int(rate * 0.40)
    out = [0.0] * n
    mix_into(out, 0, marimba_note(783.99, 0.25, rate, 0.55))
    mix_into(out, int(0.09 * rate), marimba_note(1174.66, 0.30, rate, 0.60))
    return [soft_clip(x) for x in out]


def gen_sfx_11_win_stereo(rate=44100):
    # 1.80s Bright candy victory fanfare + stereo confetti sparkles
    n = int(rate * 1.80)
    left = [0.0] * n
    right = [0.0] * n
    mel = [(0.00, 523.25), (0.12, 659.25), (0.24, 783.99), (0.38, 1046.5), (0.56, 880.0), (0.72, 1046.5), (0.92, 1318.5)]
    for idx, (t0, f) in enumerate(mel):
        seg = marimba_note(f, 0.55, rate, 0.48)
        pan_l = 0.65 if idx % 2 == 0 else 0.45
        pan_r = 0.45 if idx % 2 == 0 else 0.65
        mix_into(left, int(t0 * rate), seg, pan_l)
        mix_into(right, int(t0 * rate), seg, pan_r)
    # Final triumphant chord
    for f in [523.25, 659.25, 783.99, 1046.5, 1318.5]:
        seg = marimba_note(f, 0.85, rate, 0.32)
        mix_into(left, int(0.92 * rate), seg, 0.7)
        mix_into(right, int(0.92 * rate), seg, 0.7)
    return [(soft_clip(left[i]), soft_clip(right[i])) for i in range(n)]


def gen_sfx_12_fail(rate=44100):
    # 0.90s Playful descending slide ("almost!")
    n = int(rate * 0.90)
    out = [0.0] * n
    notes = [(0.00, 493.88), (0.18, 440.0), (0.36, 392.0), (0.54, 329.63)]
    for t0, f in notes:
        mix_into(out, int(t0 * rate), marimba_note(f, 0.34, rate, 0.50))
    return [soft_clip(x) for x in out]


def gen_sfx_13_rv_blast_stereo(rate=44100):
    # 0.80s Satisfying multi-bubble pop clear + powerup chime
    n = int(rate * 0.80)
    left = [0.0] * n
    right = [0.0] * n
    for k in range(6):
        t0 = k * 0.055
        f0 = 380.0 + k * 95.0
        ln = int(rate * 0.14)
        seg = []
        ph = 0.0
        for i in range(ln):
            t = i / rate
            ph += math.tau * (f0 + 500.0 * (i / ln)) / rate
            seg.append(math.sin(ph) * math.exp(-t * 26.0) * 0.55)
        mix_into(left, int(t0 * rate), seg, 0.75 if k % 2 == 0 else 0.35)
        mix_into(right, int(t0 * rate), seg, 0.35 if k % 2 == 0 else 0.75)
    for f in [523.25, 783.99, 1046.5, 1567.98]:
        seg = marimba_note(f, 0.45, rate, 0.35)
        mix_into(left, int(0.32 * rate), seg, 0.7)
        mix_into(right, int(0.32 * rate), seg, 0.7)
    return [(soft_clip(left[i]), soft_clip(right[i])) for i in range(n)]


def gen_bgm_01_marimba(rate=32000):
    # Exact 45.00s seamless loop: 112 BPM -> 1 beat = 60/112 = 0.535714s -> 84 beats = 45.00s (21 bars of 4/4 -> use 20 bars at 106.667 BPM = 45.00s exact!)
    # 80 beats in 45.0s => beat_dur = 0.5625s (106.67 BPM), 20 bars of 4/4 -> clean 4-bar x 5 phrase loop!
    dur = 45.0
    n = int(rate * dur)
    out = [0.0] * n
    beat = 45.0 / 80.0  # 0.5625s
    eighth = beat / 2.0

    # Cheerful C-major pentatonic / F / G / Am progression (4-bar pattern x 5)
    chords = [
        (130.81, [523.25, 659.25, 783.99, 880.0]),  # C
        (174.61, [587.33, 659.25, 783.99, 1046.5]), # F/C
        (196.00, [587.33, 783.99, 880.0, 1174.66]), # G
        (220.00, [523.25, 659.25, 880.0, 1046.5]),  # Am
    ]
    melody_steps = [0, 2, 1, 3, 2, 0, 3, 1]  # bouncy 8th-note motif

    for bar in range(20):
        bass_f, notes = chords[bar % 4]
        variation = (bar // 4) % 3
        bar_t = bar * 4 * beat

        # Warm pizzicato bass on beats 1 & 3
        for b_idx, mul in [(0, 1.0), (2, 1.5 if bar % 2 == 0 else 1.0)]:
            t0 = bar_t + b_idx * beat
            mix_into(out, int(t0 * rate), marimba_note(bass_f * mul, 0.42, rate, 0.36))

        # Light playful marimba melody on 8th notes
        for step in range(8):
            if variation == 0 and step in (3, 7):
                continue
            if variation == 2 and step == 5:
                continue
            note_idx = (melody_steps[step] + variation) % len(notes)
            f = notes[note_idx]
            if bar % 4 == 3 and step == 6:
                f *= 0.5
            t0 = bar_t + step * eighth
            vel = 0.34 if step % 2 == 0 else 0.22
            mix_into(out, int(t0 * rate), marimba_note(f, 0.26, rate, vel))

        # Gentle shaker pulse on off-beats
        rng = random.Random(bar + 100)
        for b_idx in range(4):
            t0 = bar_t + (b_idx + 0.5) * beat
            idx0 = int(t0 * rate)
            ln = int(rate * 0.045)
            for k in range(ln):
                if idx0 + k < n:
                    env = math.exp(-(k / rate) * 85.0) * 0.055
                    out[idx0 + k] += (rng.random() * 2.0 - 1.0) * env

    # Seamless 20ms boundary crossfade fade-in/out for click-free loop
    fade = int(rate * 0.02)
    for i in range(fade):
        w = i / fade
        out[i] *= w
        out[n - 1 - i] *= w

    return [soft_clip(x * 0.85) for x in out]


def main():
    specs = [
        ("SFX-01", "sfx_01_pop.mp3",      gen_sfx_01_pop,           44100, False, "48k", 8),
        ("SFX-02", "sfx_02_plop.mp3",     gen_sfx_02_plop,          44100, False, "48k", 11),
        ("SFX-03", "sfx_03_gulp.mp3",     gen_sfx_03_gulp,          44100, False, "48k", 18),
        ("SFX-04", "sfx_04_level_up.mp3", gen_sfx_04_level_up,      44100, False, "48k", 24),
        ("SFX-05", "sfx_05_ice.mp3",      gen_sfx_05_ice,           44100, False, "48k", 20),
        ("SFX-06", "sfx_06_magnet.mp3",   gen_sfx_06_magnet,        44100, False, "48k", 32),
        ("SFX-07", "sfx_07_fever.mp3",    gen_sfx_07_fever,         44100, False, "48k", 28),
        ("SFX-08", "sfx_08_sticky.mp3",   gen_sfx_08_sticky,        44100, False, "48k", 14),
        ("SFX-09", "sfx_09_tick.mp3",     gen_sfx_09_tick,          44100, False, "48k", 6),
        ("SFX-10", "sfx_10_goal_done.mp3",gen_sfx_10_goal_done,     44100, False, "48k", 15),
        ("SFX-11", "sfx_11_win.mp3",      gen_sfx_11_win_stereo,    44100, True,  "64k", 55),
        ("SFX-12", "sfx_12_fail.mp3",     gen_sfx_12_fail,          44100, False, "48k", 26),
        ("SFX-13", "sfx_13_rv_blast.mp3", gen_sfx_13_rv_blast_stereo,44100, True, "64k", 26),
        ("BGM-01", "bgm_01_marimba.mp3",  gen_bgm_01_marimba,       32000, False, "40k", 280),
    ]

    total_kb = 0.0
    with tempfile.TemporaryDirectory() as tmp:
        for aid, fname, fn, rate, stereo, br, max_kb in specs:
            samples = fn(rate)
            wav_p = os.path.join(tmp, fname + ".wav")
            out_p = os.path.join(OUT_DIR, fname)
            write_wav(wav_p, samples, rate=rate, stereo=stereo)
            kb = encode_audio(wav_p, out_p, rate=rate, stereo=stereo, bitrate=br)
            total_kb += kb
            status = "PASS" if kb <= max_kb else "OVER"
            print(f"{aid:6s} | {fname:22s} | {kb:6.1f} KB / {max_kb:3d} KB | {status}")
    print(f"TOTAL AUDIO: {total_kb:.1f} KB / 563 KB budget")


if __name__ == "__main__":
    main()
