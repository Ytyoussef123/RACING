"""Decodes the screenshots printed by the Street Football CI job back into JPEG files.

The job's last step prints lines "SHOT_BEGIN <name>", "SHOT_DATA <base64>", "SHOT_END <name>"
(see street-football/tests/screenshot_tour.gd). Save the job log to a file, then run:

    python3 decode_screenshots.py <log file> <output folder>

The log file can be the raw GitHub Actions log, or a JSON object with a "logs_content" field.
"""
import base64
import json
import os
import re
import sys


def main() -> None:
    log_path, out_dir = sys.argv[1], sys.argv[2]
    text = open(log_path, encoding="utf-8").read()
    try:
        text = json.loads(text)["logs_content"]
    except (ValueError, KeyError, TypeError):
        pass
    os.makedirs(out_dir, exist_ok=True)
    shots, current = {}, None
    for line in text.splitlines():
        # Drop the timestamp GitHub puts in front of each log line.
        line = re.sub(r"^\S+Z ", "", line)
        if line.startswith("SHOT_BEGIN "):
            current = line.split(" ", 1)[1].strip()
            shots[current] = []
        elif line.startswith("SHOT_DATA ") and current:
            shots[current].append(line.split(" ", 1)[1].strip())
        elif line.startswith("SHOT_END "):
            current = None
    for name, parts in shots.items():
        with open(os.path.join(out_dir, name + ".jpg"), "wb") as f:
            f.write(base64.b64decode("".join(parts)))
    print(f"{len(shots)} screenshots: {', '.join(shots)}")


if __name__ == "__main__":
    main()
