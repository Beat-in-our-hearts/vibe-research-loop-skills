#!/usr/bin/env python3
"""Count the GPU hours that runs took, from the headers and footers of their logs
(docs/AGENTS/log_template.md), to count what an idea's budget has used.

Usage: gpu_hours.py [--json] <log or folder>...

    Give the log folders of the idea's experiments, such as logs/<date>-<name>/, or single logs. Each start
    of a run in a log, its first launch or a restart, counts from its `started` line to its `finished` line,
    times the number of GPU ids on its `resources` line. A start with no footer counts up to the next start
    in the same log, if any, as an upper bound for a run that was killed, and else up to the log's last
    write, for a run that is still going or was killed. A start whose GPU ids cannot be read is flagged and
    left out of the totals.

    --json   Print the counts as JSON instead of tables.

Only the logs on this machine count: run it on every machine that ran the idea's experiments, and add up.
In remote mode, run it on the remote host:
    vrl_ssh.sh script <alias> --workspace <dir> -- gpu_hours.py logs/<date>-<name>/

Needs Python 3.6 or later, and nothing outside its standard library.
"""

import datetime
import json
import os
import re
import sys

TIME = re.compile(r"(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}(?::\d{2})?)\s*([+-]\d{2}:?\d{2}|Z)?")
GPU_IDS = re.compile(r"\bGPUs?\s+(\d[\d,\s-]*)")


def parse_time(text):
    m = TIME.search(text)
    if not m:
        return None
    day, clock, zone = m.groups()
    if len(clock) == 5:
        clock += ":00"
    t = datetime.datetime.strptime(day + " " + clock, "%Y-%m-%d %H:%M:%S")
    if zone and zone != "Z":
        sign = 1 if zone[0] == "+" else -1
        digits = zone[1:].replace(":", "")
        offset = datetime.timedelta(hours=int(digits[:2]), minutes=int(digits[2:]))
        return t.replace(tzinfo=datetime.timezone(sign * offset))
    if zone == "Z":
        return t.replace(tzinfo=datetime.timezone.utc)
    return t  # No offset: compared only with other times of the same log.


def gpu_count(resources):
    """The number of GPU ids on a resources line, such as `box1, GPU 0,1 (A100)`; 0 for `no GPU`."""
    if re.search(r"\bno GPUs?\b", resources, re.IGNORECASE):
        return 0
    m = GPU_IDS.search(resources)
    if not m:
        return None
    count = 0
    for part in re.split(r"[,\s]+", m.group(1).strip()):
        if not part:
            continue
        if "-" in part:
            low, _, high = part.partition("-")
            if not (low.isdigit() and high.isdigit()) or int(high) < int(low):
                return None
            count += int(high) - int(low) + 1
        elif part.isdigit():
            count += 1
        else:
            return None
    return count or None


def read_starts(path):
    """Every start of a run in one log: its start, end, GPU count, and notes."""
    starts = []
    resources = None
    current = None
    after_end = False
    with open(path, errors="replace") as f:
        for line in f:
            if line.startswith("# resources:"):
                resources = line.split(":", 1)[1].strip()
            elif line.startswith("# started:"):
                current = {
                    "started": parse_time(line),
                    "finished": None,
                    "gpus": gpu_count(resources) if resources is not None else None,
                    "notes": [],
                }
                if current["started"] is None:
                    current["notes"].append("unreadable started line")
                starts.append(current)
                resources = None
                after_end = False
            elif line.startswith("# ---------- end ----------"):
                after_end = True
            elif line.startswith("# finished:") and after_end and current is not None:
                current["finished"] = parse_time(line)
                after_end = False
    last_write = datetime.datetime.fromtimestamp(os.path.getmtime(path), datetime.timezone.utc)
    for i, s in enumerate(starts):
        if s["finished"] is not None or s["started"] is None:
            continue
        if i + 1 < len(starts) and starts[i + 1]["started"] is not None:
            s["finished"] = starts[i + 1]["started"]
            s["notes"].append("no footer: counted up to the next start, an upper bound")
        else:
            start = s["started"]
            s["finished"] = last_write if start.tzinfo else last_write.astimezone().replace(tzinfo=None)
            s["notes"].append("no footer: counted up to the log's last write; still running or killed")
    for s in starts:
        if s["gpus"] is None:
            s["notes"].append("GPU ids not found on the resources line: left out of the totals")
    return starts


def hours(s):
    if s["started"] is None or s["finished"] is None:
        return 0.0
    try:
        return max(0.0, (s["finished"] - s["started"]).total_seconds() / 3600)
    except TypeError:  # One time has a UTC offset and the other has none.
        return 0.0


def collect(targets):
    groups = []
    for target in targets:
        if os.path.isdir(target):
            logs = sorted(
                os.path.join(root, name)
                for root, _, names in os.walk(target)
                for name in names
                if name.endswith(".log")
            )
            name = os.path.basename(os.path.normpath(target))
        elif os.path.isfile(target):
            logs = [target]
            name = os.path.basename(os.path.dirname(os.path.abspath(target)))
        else:
            raise SystemExit("gpu_hours: no such log or folder: " + target)
        rows = []
        for log in logs:
            starts = read_starts(log)
            if not starts:
                continue
            counted = [s for s in starts if s["gpus"] is not None]
            rows.append({
                "log": log,
                "starts": len(starts),
                "gpus": sorted({s["gpus"] for s in counted}),
                "hours": round(sum(hours(s) for s in starts), 2),
                "gpu_hours": round(sum(hours(s) * s["gpus"] for s in counted), 2),
                "notes": sorted({n for s in starts for n in s["notes"]}),
            })
        groups.append({
            "folder": name,
            "logs": rows,
            "gpu_hours": round(sum(r["gpu_hours"] for r in rows), 2),
        })
    return groups


def main(argv):
    as_json = False
    targets = []
    for arg in argv:
        if arg in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if arg == "--json":
            as_json = True
        elif arg.startswith("-"):
            print("gpu_hours: unknown argument: " + arg, file=sys.stderr)
            return 2
        else:
            targets.append(arg)
    if not targets:
        print("gpu_hours: give the log folders of the idea's experiments", file=sys.stderr)
        return 2
    groups = collect(targets)
    total = round(sum(g["gpu_hours"] for g in groups), 2)
    if as_json:
        print(json.dumps({"groups": groups, "total_gpu_hours": total}, indent=2))
        return 0
    for g in groups:
        print("**%s**: %.2f GPU hours\n" % (g["folder"], g["gpu_hours"]))
        print("| Log | Starts | GPUs | Hours | GPU hours | Notes |")
        print("|---|---|---|---|---|---|")
        for r in g["logs"]:
            print("| %s | %d | %s | %.2f | %.2f | %s |" % (
                os.path.basename(r["log"]), r["starts"], ", ".join(str(n) for n in r["gpus"]) or "?",
                r["hours"], r["gpu_hours"], "; ".join(r["notes"])))
        if not g["logs"]:
            print("| (no log with a header) | | | | | |")
        print()
    print("Total: %.2f GPU hours" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
