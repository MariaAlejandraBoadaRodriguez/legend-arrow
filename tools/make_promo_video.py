#!/usr/bin/env python3
"""Edits the store promo videos from real Movie Maker footage.

Input: <work>/promo.avi (1080x1920 portrait, 30 fps, game audio) and
<work>/marks.txt ("<scene> <frame>"), both written by scripts/record_promo.sh.
Every shot is a cut of that recording; the only added elements are the title
and end cards (the real app icon on blurred game footage), English captions
in the game's font (Inter SemiBold), and the blurred side panels.

Output (H.264 + AAC, 30 fps):
  <out>/legend_arrow_promo_1920x1080.mp4   landscape, Google Play
  <out>/legend_arrow_promo_1080x1920.mp4   vertical, social media

  python3 tools/make_promo_video.py <work_dir> <out_dir>
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets/fonts/Inter-SemiBold.ttf")
ICON = os.path.join(ROOT, "assets/icon/icon_512.png")
FPS = 30
INK = "0x22303C"        # game text colour
ACCENT = "0x46657C"     # game primary button colour
FADE = 0.15             # seconds of fade at every cut


def marks(work):
    out = {}
    with open(os.path.join(work, "marks.txt")) as f:
        for line in f:
            name, frame = line.split()
            out[name] = int(frame)
    return out


def plan(m):
    """(kind, start_frame, end_frame, caption, fades). Frames index the AVI.
    fades: "i"/"o"/"io" fade from/to black; other cuts are hard cuts."""
    hook = m["hook_start"]
    return [
        # (1) Hook: arrows gather and the dragon appears through the mist.
        ("footage", hook + 15, hook + 105, "", "o"),
        # (2) Title card over the Home screen.
        ("title", m["home"], m["home"] + 120, "", "io"),
        # (3) How to play on a World 1 board.
        ("footage", m["play_start"] - 30, m["blocked"], "Tap an arrow with\na clear way out", "i"),
        ("footage", m["blocked"], m["blocked"] + 60, "Blocked? Clear its\npath first", ""),
        ("footage", m["blocked"] + 60, m["board_empty"] + 20, "Empty the board", ""),
        # (4) That dragon's photoreal awakening.
        ("footage", m["awaken_start"], m["awaken_end"], "Every board awakens\na dragon", ""),
        # (5) Speed and stars.
        ("footage", m["replay_start"], m["results_record"], "Beat the clock", ""),
        ("footage", m["results_record"], m["results_record_end"], "Beat the clock\nfor 3 stars", ""),
        # (6) Harder boards from later worlds, then the bestiary filling up.
        ("footage", m["hard_w05"] + 6, m["hard_w05"] + 84, "Harder boards in\nlater worlds", ""),
        ("footage", m["hard_w08"] + 6, m["hard_w08"] + 84, "Harder boards in\nlater worlds", ""),
        ("footage", m["hard_w10"] + 6, m["hard_w10"] + 92, "Harder boards in\nlater worlds", ""),
        ("footage", m["bestiary_few"], m["bestiary_few"] + 75, "Awaken 100\nlegendary dragons", ""),
        ("footage", m["bestiary_many"], m["bestiary_many_end"], "Awaken 100\nlegendary dragons", "o"),
        # (7) End card over the last dragon.
        ("end", hook + 30, hook + 210, "", "io"),
    ]


def esc(s):
    return s.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def text(tmp, s):
    """drawtext reads multi-line text from a file."""
    fd, path = tempfile.mkstemp(dir=tmp, suffix=".txt")
    with os.fdopen(fd, "w") as f:
        f.write(s)
    return path


def segment_filter(kind, landscape, cap_file, dur, fades, tmp):
    """filter_complex from input 0 (footage) and 1 (icon) to [v]."""
    W, H = (1920, 1080) if landscape else (1080, 1920)
    blur = "gblur=sigma=36,eq=brightness=-0.04:saturation=0.85"
    if landscape:
        bg = f"[f1]scale=1920:-2,crop=1920:1080,{blur}[bg]"
        fg = "[f2]scale=-2:1080[fg]"
        place = "overlay=(W-w)/2:0"
    else:
        # Footage at 90 % leaves a top band for the caption.
        bg = f"[f1]scale=1080:1920,{blur}[bg]"
        fg = "[f2]scale=972:1728[fg]"
        place = "overlay=(W-w)/2:192"
    chain = [f"[0:v]setpts=PTS-STARTPTS,split[f1][f2]", bg]
    if kind == "footage":
        chain.append(fg)
        chain.append(f"[bg][fg]{place}[base]")
    else:
        chain.append("[f2]nullsink")
        icon = 300 if landscape else 380
        iy = "(H-h)/2-150" if landscape else "(H-h)/2-260"
        chain.append(f"[1:v]scale={icon}:{icon}[ic]")
        chain.append(f"[bg][ic]overlay=(W-w)/2:{iy}[base0]")
        title_y = "h/2+70" if landscape else "h/2+10"
        t = f"drawtext=fontfile='{esc(FONT)}':text='Legend Arrow':fontsize={110 if landscape else 120}:fontcolor={INK}:shadowcolor=white@0.85:shadowx=0:shadowy=0:borderw=6:bordercolor=white@0.55:x=(w-tw)/2:y={title_y}"
        if kind == "end":
            sub = text(tmp, "100 dragons · 10 worlds · Play offline")
            sub_y = "h/2+220" if landscape else "h/2+170"
            t += (f",drawtext=fontfile='{esc(FONT)}':textfile='{esc(sub)}':fontsize={54 if landscape else 50}"
                  f":fontcolor=white:box=1:boxcolor={ACCENT}@0.95:boxborderw=26:x=(w-tw)/2:y={sub_y}")
        chain.append(f"[base0]{t}[base]")
    last = "base"
    if cap_file:
        if landscape:
            # Left panel (656 px wide), centred vertically.
            d = (f"drawtext=fontfile='{esc(FONT)}':textfile='{esc(cap_file)}':fontsize=58:line_spacing=14"
                 f":fontcolor=white:text_align=center:box=1:boxcolor={ACCENT}@0.93:boxborderw=30"
                 f":x=(656-tw)/2:y=(h-th)/2")
        else:
            d = (f"drawtext=fontfile='{esc(FONT)}':textfile='{esc(cap_file)}':fontsize=50:line_spacing=10"
                 f":fontcolor=white:text_align=center:box=1:boxcolor={ACCENT}@0.93:boxborderw=22"
                 f":x=(w-tw)/2:y=(192-th)/2")
        chain.append(f"[{last}]{d}[capd]")
        last = "capd"
    # Fades to/from black only where a shot asks for them; other cuts are hard.
    fx = []
    if "i" in fades:
        fx.append(f"fade=t=in:st=0:d={FADE * 2}")
    if "o" in fades:
        fx.append(f"fade=t=out:st={dur - FADE * 2:.3f}:d={FADE * 2}")
    fx.append("format=yuv420p")
    chain.append(f"[{last}]{','.join(fx)}[v]")
    return ";".join(chain)


def render_segment(i, seg, landscape, work, tmp):
    kind, a, b, cap, fades = seg
    dur = (b - a) / FPS
    out = os.path.join(tmp, f"{'L' if landscape else 'V'}{i:02d}.mkv")
    cap_file = text(tmp, cap) if cap else ""
    fc = segment_filter(kind, landscape, cap_file, dur, fades, tmp)
    # Audio: long fades where the picture fades, 20 ms at hard cuts (no clicks).
    fi = FADE * 2 if "i" in fades else 0.02
    fo = FADE * 2 if "o" in fades else 0.02
    af = f"afade=t=in:st=0:d={fi},afade=t=out:st={dur - fo:.3f}:d={fo}"
    cmd = ["ffmpeg", "-v", "error", "-y",
           "-ss", f"{a / FPS:.4f}", "-t", f"{dur:.4f}", "-i", os.path.join(work, "promo.avi"),
           "-loop", "1", "-t", f"{dur:.4f}", "-i", ICON,
           "-filter_complex", fc, "-map", "[v]", "-map", "0:a", "-af", af,
           "-r", str(FPS), "-c:v", "libx264", "-crf", "14", "-preset", "medium",
           "-c:a", "pcm_s16le", "-ar", "48000", out]
    subprocess.run(cmd, check=True)
    return out


def main():
    work, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    m = marks(work)
    segs = plan(m)
    total = sum((s[2] - s[1]) / FPS for s in segs)
    print(f"make_promo_video: {len(segs)} shots, {total:.1f} s")
    if not 45.0 <= total <= 60.0:
        sys.exit(f"make_promo_video: length {total:.1f} s is outside 45-60 s")
    with tempfile.TemporaryDirectory() as tmp:
        for landscape, name in [(True, "legend_arrow_promo_1920x1080.mp4"), (False, "legend_arrow_promo_1080x1920.mp4")]:
            parts = [render_segment(i, s, landscape, work, tmp) for i, s in enumerate(segs)]
            lst = os.path.join(tmp, "list.txt")
            with open(lst, "w") as f:
                f.writelines(f"file '{p}'\n" for p in parts)
            dst = os.path.join(out_dir, name)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
                            "-c:v", "libx264", "-profile:v", "high", "-crf", "20", "-preset", "slow",
                            "-pix_fmt", "yuv420p", "-r", str(FPS),
                            "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                            "-movflags", "+faststart", dst], check=True)
            print(f"make_promo_video: {dst} {os.path.getsize(dst)} bytes")


if __name__ == "__main__":
    main()
