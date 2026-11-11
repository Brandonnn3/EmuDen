#!/usr/bin/env python3
"""Create EmuDen's original menu instruments. No samples or quoted melodies.

Run with --check to verify the bundled PCM against this deterministic score.
The audition file is a development artifact and is never bundled with the app.
"""
import argparse
import hashlib
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
# duration, (onset, frequency, level, pan). Short, abstract interval gestures.
SCORE = {
    "focus": (0.105, [(0, 1174.66, 0.8, -0.12)]),
    "confirm": (0.205, [(0, 880, 0.65, -0.25), (0.045, 1318.51, 0.7, 0.25)]),
    "back": (0.155, [(0, 987.77, 0.55, 0.18), (0.035, 659.25, 0.65, -0.18)]),
    "launch": (0.245, [(0, 659.25, 0.6, -0.3), (0.042, 987.77, 0.6, 0), (0.084, 1567.98, 0.65, 0.3)]),
    "planned": (0.245, [(0, 783.99, 0.55, -0.25), (0.055, 1046.5, 0.5, 0.25)]),
    "search": (0.285, [(0, 523.25, 0.48, -0.22), (0.038, 1046.5, 0.3, 0.1), (0.074, 1567.98, 0.18, 0.3)]),
    "open": (0.245, [(0, 440, 0.5, -0.2), (0.03, 659.25, 0.35, 0), (0.055, 880, 0.22, 0.2)]),
    "unfold": (0.55, [(0, 196, 0.22, -0.18), (0.04, 392, 0.28, 0), (0.12, 783.99, 0.24, 0.12), (0.22, 1174.66, 0.16, 0.18)]),
    "save": (0.23, [(0, 783.99, 0.5, -0.12), (0.04, 1174.66, 0.6, 0.12)]),
}


def render(duration, notes):
    samples = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        channels = [0.0, 0.0]
        for onset, frequency, level, pan in notes:
            u = t - onset
            if u < 0:
                continue
            # A struck glass voice: detuned bell partials and a soft sine body.
            attack = min(1, u / 0.003)
            body = math.sin(math.tau * frequency * u) * math.exp(-u * 25)
            bell = math.sin(math.tau * frequency * 2.003 * u) * math.exp(-u * 43) * 0.22
            glint = math.sin(math.tau * frequency * 3.97 * u) * math.exp(-u * 65) * 0.055
            voice = (body + bell + glint) * attack * level
            channels[0] += voice * math.sqrt((1 - pan) / 2)
            channels[1] += voice * math.sqrt((1 + pan) / 2)
        fade = min(1, (duration - t) / 0.024)
        samples.append([v * fade for v in channels])
    # Remove any DC offset without introducing a boundary step.
    means = [sum(s[c] for s in samples) / len(samples) for c in range(2)]
    for i, sample in enumerate(samples):
        window = min(1, i / (RATE * 0.003), (len(samples) - 1 - i) / (RATE * 0.012))
        for c in range(2):
            sample[c] = (sample[c] - means[c]) * window
    gain = 0.62 / max(abs(v) for sample in samples for v in sample)
    pcm = [round(v * gain * 32767) for sample in samples for v in sample]
    assert max(abs(v) for v in pcm) < 32767
    assert pcm[:2] == [0, 0] and pcm[-2:] == [0, 0]
    assert 0.08 <= duration <= 0.6
    return struct.pack(f"<{len(pcm)}h", *pcm)


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as audio:
        audio.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        audio.writeframes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    audition = bytearray()
    for name, (duration, notes) in SCORE.items():
        data = render(duration, notes)
        path = ROOT / "Resources" / "MenuAudio" / f"{name}.wav"
        if args.check:
            with wave.open(str(path), "rb") as audio:
                assert audio.getparams()[:3] == (2, 2, RATE), name
                assert audio.readframes(audio.getnframes()) == data, name
        else:
            write(path, data)
        audition.extend(data)
        audition.extend(bytes(round(RATE * 0.45) * 4))
        print(f"{name}: {duration:.3f}s · PCM SHA256 {hashlib.sha256(data).hexdigest()}")
    if not args.check:
        write(ROOT / "build" / "EmuDen-Menu-Sound-Preview.wav", audition)


if __name__ == "__main__":
    main()
