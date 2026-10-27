#!/usr/bin/env python3
"""16 KB page-size compatibility check for an APK (stdlib only).

For every native library lib/<abi>/*.so:
  * ELF: every PT_LOAD segment must have p_align >= 16384 (64-bit ELF only).
  * Zip: if stored uncompressed, its data must start at a 16384-byte offset
    (compressed libraries are extracted at install time, so no zip alignment
    applies).
Exit 1 on any violation or if no 64-bit library is found.
"""
import struct
import sys
import zipfile

PAGE = 16384
PT_LOAD = 1


def elf_load_aligns(data: bytes):
    if data[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    if data[4] != 2:
        return None  # 32-bit ELF: 16 KB rule targets 64-bit ABIs
    endian = "<" if data[5] == 1 else ">"
    e_phoff, = struct.unpack_from(endian + "Q", data, 0x20)
    e_phentsize, e_phnum = struct.unpack_from(endian + "HH", data, 0x36)
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, = struct.unpack_from(endian + "I", data, off)
        if p_type == PT_LOAD:
            p_align, = struct.unpack_from(endian + "Q", data, off + 0x30)
            aligns.append(p_align)
    return aligns


def data_offset(zf: zipfile.ZipFile, info: zipfile.ZipInfo) -> int:
    zf.fp.seek(info.header_offset)
    header = zf.fp.read(30)
    name_len, extra_len = struct.unpack("<HH", header[26:30])
    return info.header_offset + 30 + name_len + extra_len


def main(path: str) -> int:
    ok = True
    checked = 0
    with zipfile.ZipFile(path) as zf:
        for info in zf.infolist():
            if not (info.filename.startswith("lib/") and info.filename.endswith(".so")):
                continue
            aligns = elf_load_aligns(zf.read(info))
            if aligns is None:
                print(f"SKIP  {info.filename}: 32-bit ELF")
                continue
            checked += 1
            bad = [a for a in aligns if a < PAGE]
            status = "PASS" if not bad else "FAIL"
            print(f"{status}  {info.filename}: PT_LOAD p_align {sorted(set(aligns))}")
            ok &= not bad
            if info.compress_type == zipfile.ZIP_STORED:
                off = data_offset(zf, info)
                aligned = off % PAGE == 0
                print(f"{'PASS' if aligned else 'FAIL'}  {info.filename}: stored at offset {off} ({'16 KB aligned' if aligned else 'NOT 16 KB aligned'})")
                ok &= aligned
            else:
                print(f"PASS  {info.filename}: compressed in APK (extracted at install; no zip alignment needed)")
    if checked == 0:
        print("FAIL  no 64-bit native libraries found")
        ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
