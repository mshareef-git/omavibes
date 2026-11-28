#!/usr/bin/env python3
"""Regression checks without accessing a real keyboard or audio device.

Run after rebuilding: python3 tests/test_audio.py
Requires g++, the nlohmann JSON development headers, and Linux.
"""

import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent


with tempfile.TemporaryDirectory(prefix="omavibes-audio-tests-") as directory:
    temporary = Path(directory)
    mapping_test = temporary / "mapping.cpp"
    mapping_test.write_text(r'''
#include <cassert>
#include <fstream>
#include <string>
#include <unordered_map>
#include <linux/input-event-codes.h>
std::unordered_map<int, std::string> loadKeySoundMappings(const std::string &);
int main(int argc, char **argv) {
    std::ofstream(argv[1]) << R"({"defines":{
      "3675":"super.wav","3667":"delete.wav","57416":"up.wav",
      "60999":"kp7.wav","61000":"kp8.wav","61001":"kp9.wav",
      "61003":"kp4.wav","61005":"kp6.wav","61007":"kp1.wav",
      "61008":"kp2.wav","61009":"kp3.wav","61010":"kp0.wav",
      "61011":"kpdot.wav"}})";
    auto keys = loadKeySoundMappings(argv[1]);
    assert(keys.at(KEY_LEFTMETA) == "super.wav");
    assert(keys.at(KEY_RIGHTMETA) == "super.wav");
    assert(keys.at(KEY_DELETE) == "delete.wav");
    assert(keys.at(KEY_UP) == "up.wav");
    assert(keys.at(KEY_KP7) == "kp7.wav");
    assert(keys.at(KEY_KP8) == "kp8.wav");
    assert(keys.at(KEY_KP9) == "kp9.wav");
    assert(keys.at(KEY_KP4) == "kp4.wav");
    assert(keys.at(KEY_KP6) == "kp6.wav");
    assert(keys.at(KEY_KP1) == "kp1.wav");
    assert(keys.at(KEY_KP2) == "kp2.wav");
    assert(keys.at(KEY_KP3) == "kp3.wav");
    assert(keys.at(KEY_KP0) == "kp0.wav");
    assert(keys.at(KEY_KPDOT) == "kpdot.wav");
    assert(keys.count(KEY_HOME) == 0);
    // Explicit evdev mappings must win over translated aliases.
    std::ofstream(argv[1]) << R"({"defines":{"60999":"alias.wav","71":"native.wav"}})";
    keys = loadKeySoundMappings(argv[1]);
    assert(keys.at(KEY_KP7) == "native.wav");
}
''')
    executable = temporary / "mapping-test"
    subprocess.run([
        "g++", "-std=c++17", str(mapping_test),
        str(ROOT / "third_party/wayvibes/src/config.cpp"),
        "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable), str(temporary / "pack.json")], check=True)
    print("PASS: navigation, numpad, fallback and native key mappings", flush=True)

    config = temporary / "config/wayvibes"
    config.mkdir(parents=True)
    fifo = temporary / "fake-keyboard"
    os.mkfifo(fifo)
    (config / "input_device_path").write_text(str(fifo))
    writer = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
    env = dict(os.environ, XDG_CONFIG_HOME=str(temporary / "config"),
               XDG_STATE_HOME=str(temporary / "state"))
    process = subprocess.Popen([str(ROOT / "bin/wayvibes"), "--analytics-only"],
                               env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        time.sleep(0.2)
        # A press, repeat and release: only the press should be counted.
        for value in (1, 2, 0):
            os.write(writer, struct.pack("@llHHi", 0, 0, 1, 30, value))
        # Wait for a flush to prove events were consumed before disconnecting.
        stats = temporary / "state/omarchy/omavibes-analytics.json"
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if stats.exists():
                data = json.loads(stats.read_text())
                if data.get("keyCounts", {}).get("A") == 1:
                    break
            time.sleep(0.05)
        else:
            raise AssertionError("Fake key press was not recorded")
        assert sum(data["keyCounts"].values()) == 1, data
        print("PASS: repeat and release events do not inflate analytics", flush=True)
        os.close(writer)
        writer = None
        output, errors = process.communicate(timeout=2)
        assert process.returncode == 0, errors.decode()
        assert b"disconnected" in errors, errors.decode()
        print("PASS: disconnected input exits promptly instead of spinning", flush=True)
    finally:
        if writer is not None:
            os.close(writer)
        if process.poll() is None:
            process.kill()
        process.communicate()
