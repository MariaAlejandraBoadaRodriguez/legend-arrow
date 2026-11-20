#!/usr/bin/env python3
"""15-second promo cut (vertical 1080x1920 and landscape 1920x1080).

Same real Movie Maker footage as tools/make_promo_video.py, but from the
effects-only take (LEGEND_PROMO_SFX_ONLY=1 scripts/record_promo.sh): tighter
cuts, the arrow-clearing shots sped up in the edit (the game itself is not
faster), and the game's own sound effects processed to sound close and crisp
(ASMR style) over the game's own music track, mixed low.

  python3 tools/make_promo_short.py <sfx_work_dir> <out_dir>        # 15 s, both formats
  python3 tools/make_promo_short.py <sfx_work_dir> <out_dir> 50     # ~50 s, 1920x1080
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_promo_video as base  # noqa: E402

MUSIC = os.path.join(base.ROOT, "assets/audio/music_ambient.wav")
MAX_LEN = 15.0

# Close, crisp, a little room: highs lifted, dynamics squeezed so every tap
# and swoosh is up front, a very short early reflection, slightly wider.
ASMR = ("highpass=f=110,"
        "equalizer=f=3200:t=q:w=1.2:g=4,equalizer=f=8500:t=q:w=1.0:g=6,"
        "acompressor=threshold=-30dB:ratio=5:attack=1:release=50:makeup=9,"
        "aecho=0.85:0.55:14|29:0.22|0.12,extrastereo=m=1.4")


def plan(m):
    """(kind, start_frame, end_frame, caption, fades, speed)."""
    hook = m["hook_start"]
    return [
        ("footage", hook + 50, hook + 95, "", "", 1.0),                                  # dragon appears
        ("footage", m["play_start"] - 6, m["board_empty"] + 8, "Tap an arrow with\na clear way out", "", 1.8),
        ("footage", m["awaken_start"] + 55, m["awaken_start"] + 145, "Awaken 100\nlegendary dragons", "", 1.0),
        ("footage", m["replay_start"], m["results_record"], "Beat the clock\nfor 3 stars", "", 2.0),
        ("footage", m["results_record"] + 4, m["results_record"] + 62, "Beat the clock\nfor 3 stars", "", 1.0),
        ("footage", m["hard_w10"] + 6, m["hard_w10"] + 60, "", "", 1.6),
        ("end", hook + 60, hook + 126, "", "o", 1.0),
    ]


def plan_50(m):
    """The same style at ~50 s (landscape): every scene of the take."""
    hook = m["hook_start"]
    return [
        ("footage", hook + 15, hook + 105, "", "o", 1.0),                                # arrows gather, dragon appears
        ("title", m["home"], m["home"] + 135, "", "io", 1.0),
        ("footage", m["home"] + 10, m["play_start"] - 6, "Pick a dragon\nand play", "", 1.3),
        ("footage", m["play_start"] - 6, m["blocked"], "Tap an arrow with\na clear way out", "", 1.4),
        ("footage", m["blocked"], m["blocked"] + 60, "Blocked? Clear its\npath first", "", 1.0),
        ("footage", m["blocked"] + 60, m["board_empty"] + 8, "Empty the board", "", 1.6),
        ("footage", m["board_empty"] + 8, m["results_first"], "Every clear\nis timed", "", 1.0),
        ("footage", m["awaken_start"], m["awaken_end"], "Every board awakens\na dragon", "", 1.0),
        ("footage", m["replay_start"], m["results_record"], "Beat the clock", "", 1.6),
        ("footage", m["results_record"], m["results_record_end"], "Beat the clock\nfor 3 stars", "", 1.0),
        ("footage", m["hard_w05"] + 6, m["hard_w05_end"], "Harder boards in\nlater worlds", "", 1.25),
        ("footage", m["hard_w08"] + 6, m["hard_w08_end"], "Harder boards in\nlater worlds", "", 1.25),
        ("footage", m["hard_w10"] + 6, m["hard_w10_end"], "Harder boards in\nlater worlds", "", 1.25),
        ("footage", m["bestiary_few"], m["bestiary_few"] + 105, "Awaken 100\nlegendary dragons", "", 1.0),
        ("footage", m["bestiary_many"], m["bestiary_many_end"], "Awaken 100\nlegendary dragons", "", 1.0),
        ("footage", hook + 105, m["hook_end"], "Each dragon has\nits own awakening", "", 1.0),
        ("end", hook + 30, hook + 210, "", "o", 1.0),
    ]


def render(i, seg, landscape, work, tmp):
    kind, a, b, cap, fades, sp = seg
    src = (b - a) / base.FPS
    dur = src / sp
    out = os.path.join(tmp, f"{'L' if landscape else 'V'}{i:02d}.mkv")
    cap_file = base.text(tmp, cap) if cap else ""
    fc = base.segment_filter(kind, landscape, cap_file, dur, fades, tmp)
    fc = fc.replace("[0:v]setpts=PTS-STARTPTS", f"[0:v]setpts=(PTS-STARTPTS)/{sp}", 1)
    tempo = f"atempo={sp}," if sp != 1.0 else ""
    fo = 0.3 if "o" in fades else 0.015
    af = f"{tempo}afade=t=in:st=0:d=0.015,afade=t=out:st={dur - fo:.3f}:d={fo}"
    subprocess.run(["ffmpeg", "-v", "error", "-y",
                    "-ss", f"{a / base.FPS:.4f}", "-t", f"{src:.4f}", "-i", os.path.join(work, "promo.avi"),
                    "-loop", "1", "-t", f"{dur:.4f}", "-i", base.ICON,
                    "-filter_complex", fc, "-map", "[v]", "-map", "0:a", "-af", af,
                    "-r", str(base.FPS), "-t", f"{dur:.4f}", "-c:v", "libx264", "-crf", "14",
                    "-c:a", "pcm_s16le", "-ar", "48000", out], check=True)
    return out


def main():
    work, out_dir = sys.argv[1], sys.argv[2]
    long_cut = len(sys.argv) > 3 and sys.argv[3] == "50"
    os.makedirs(out_dir, exist_ok=True)
    segs = (plan_50 if long_cut else plan)(base.marks(work))
    total = sum((s[2] - s[1]) / base.FPS / s[5] for s in segs)
    print(f"make_promo_short: {len(segs)} shots, {total:.2f} s")
    if long_cut and not 49.0 <= total <= 51.0:
        sys.exit(f"make_promo_short: {total:.2f} s is not about 50 s")
    if not long_cut and total > MAX_LEN:
        sys.exit(f"make_promo_short: {total:.2f} s is longer than {MAX_LEN} s")
    outputs = ([(True, "legend_arrow_promo_50s_1920x1080.mp4")] if long_cut else
               [(False, "legend_arrow_promo_15s_1080x1920.mp4"), (True, "legend_arrow_promo_15s_1920x1080.mp4")])
    with tempfile.TemporaryDirectory() as tmp:
        for landscape, name in outputs:
            parts = [render(i, s, landscape, work, tmp) for i, s in enumerate(segs)]
            lst = os.path.join(tmp, "list.txt")
            with open(lst, "w") as f:
                f.writelines(f"file '{p}'\n" for p in parts)
            cut = os.path.join(tmp, "cut.mkv")
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
                            "-c", "copy", cut], check=True)
            mix = (f"[0:a]{ASMR}[fx];"
                   f"[1:a]volume=-21dB,afade=t=in:st=0:d=0.6,afade=t=out:st={total - 0.8:.3f}:d=0.8[mu];"
                   f"[fx][mu]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5:LRA=9[a]")
            dst = os.path.join(out_dir, name)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", cut, "-stream_loop", "-1", "-i", MUSIC,
                            "-filter_complex", mix, "-map", "0:v", "-map", "[a]",
                            "-c:v", "libx264", "-profile:v", "high", "-crf", "19", "-preset", "slow",
                            "-pix_fmt", "yuv420p", "-r", str(base.FPS),
                            "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", f"{total:.3f}",
                            "-movflags", "+faststart", dst], check=True)
            print(f"make_promo_short: {dst} {os.path.getsize(dst)} bytes")


if __name__ == "__main__":
    main()
