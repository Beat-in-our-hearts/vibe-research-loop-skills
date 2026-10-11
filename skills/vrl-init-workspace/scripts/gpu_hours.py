#!/usr/bin/env python3
"""Count the single-GPU hours that runs took, from the headers and footers of their logs, to count
what an idea's budget has used.

Usage: gpu_hours.py [--json] [--since TIME] [--until TIME] <log or folder>...

    Give the log folders of the idea's experiments, such as logs/<date>-<name>/, or single logs.
    Every regular file under a folder that holds a log header counts, whatever its name.
    A run counts from its `started` line to its `finished` line, times the GPUs on its `resources`
    line. Only a header before the stdout marker counts, and one with a `run-id` is closed only by
    an end marker with that id. A run with no footer counts up to now while it is alive, else up to
    the next start in its log, as an upper bound, or to the log's last write.

    --json         Print JSON instead of tables.
    --since TIME   Count only the hours after TIME, such as `2026-10-08 22:00 +04:00`.
    --until TIME   Count only the hours before TIME.

Run it where the logs are, on every machine that ran the experiments; totals are kept per machine,
by the name on each `resources` line, so logs synced from another machine count once. In remote mode:
    vrl_ssh.sh script <alias> --workspace <dir> -- gpu_hours.py logs/<date>-<name>/

Exit codes: 0 counted everything; 2 bad arguments; 3 some hours could not be counted (unreadable
GPUs, time, or file): it lists them and reports their hours apart as unknown. Needs Python 3.6 or
later, and nothing else.
"""

import datetime
import json
import os
import re
import sys
import time

KEY = re.compile(r"^\s*#\s*([A-Za-z-]+)\s*:\s?(.*)$")
STDOUT_MARK = re.compile(r"#\s*-{3,}\s*stdout\s*\+\s*stderr\s*-{3,}")
END_MARK = re.compile(r"#\s*-{3,}\s*end\b\s*([0-9a-fA-F]*)\s*-*")
TIME = re.compile(
    r"(\d{4}-\d{2}-\d{2})[ T](\d{1,2}:\d{2}(?::\d{2})?)(\.\d+)?\s*"
    r"(Z|UTC|GMT|[+-]\d{2}(?::?\d{2})?)?(?![\d:])",
    re.IGNORECASE,
)
DURATION = re.compile(r"\((\d+):(\d{2}):(\d{2})\)")
GPU_WORDS = re.compile(r"\bGPUs?\b\s*[:=]?\s*((?:\d+(?:\s*-\s*\d+)?)(?:\s*,\s*\d+(?:\s*-\s*\d+)?)*)(?![\w.])",
                       re.IGNORECASE)
CVD = re.compile(r"CUDA_VISIBLE_DEVICES\s*=\s*['\"]?((?:\d+(?:-\d+)?)(?:,\d+(?:-\d+)?)*)", re.IGNORECASE)
N_GPUS = re.compile(r"\b(\d+)\s*[x×]?\s*GPUs?\b", re.IGNORECASE)
NO_GPU = re.compile(r"\bno\s+GPUs?\b", re.IGNORECASE)
GPU_COMMAND = re.compile(r"CUDA_VISIBLE_DEVICES|torchrun|--nproc[_-]per[_-]node|\baccelerate\b|\bdeepspeed\b",
                         re.IGNORECASE)
PID = re.compile(r"\bPID\s+(\d+)")
SNIFF_BYTES = 65536
NOTES = {}


def parse_time(text, default_tz=None):
    """A datetime from text such as `2026-10-08 12:00:00 +04:00`; naive only when no zone is known."""
    m = TIME.search(text or "")
    if not m:
        return None
    day, clock, fraction, zone = m.groups()
    if clock.count(":") == 1:
        clock += ":00"
    try:
        t = datetime.datetime.strptime(day + " " + clock, "%Y-%m-%d %H:%M:%S")
        if fraction:
            t = t.replace(microsecond=int(round(float(fraction) * 1e6)) % 1000000)
        if zone:
            z = zone.upper()
            if z in ("Z", "UTC", "GMT"):
                return t.replace(tzinfo=datetime.timezone.utc)
            sign = 1 if zone[0] == "+" else -1
            digits = zone[1:].replace(":", "")
            hours, minutes = int(digits[:2]), int(digits[2:] or 0)
            if hours > 23 or minutes > 59:
                return None
            return t.replace(tzinfo=datetime.timezone(sign * datetime.timedelta(hours=hours, minutes=minutes)))
    except ValueError:
        return None
    return t.replace(tzinfo=default_tz) if default_tz else t


def expand_ids(text):
    """The GPU ids in text such as `0,1` or `0-3`, or None if it is not a list of ids."""
    ids = []
    for part in re.split(r"\s*,\s*", text.strip()):
        if not part:
            continue
        if "-" in part:
            low, _, high = (p.strip() for p in part.partition("-"))
            if not (low.isdigit() and high.isdigit()) or int(high) < int(low):
                return None
            ids.extend(range(int(low), int(high) + 1))
        elif part.isdigit():
            ids.append(int(part))
        else:
            return None
    return ids or None


def read_gpus(resources, command):
    """(GPU ids or None, GPU count or None, note) from a header's resources and command lines."""
    for pattern in (GPU_WORDS, CVD):
        for source in (resources, command):
            m = pattern.search(source or "")
            if m:
                ids = expand_ids(m.group(1))
                if ids:
                    return ids, len(set(ids)), None
    m = N_GPUS.search(resources or "")
    if m and not NO_GPU.search(resources or ""):
        return None, int(m.group(1)), None
    if NO_GPU.search(resources or ""):
        if GPU_COMMAND.search(command or ""):
            return None, None, "the header says no GPU, but the command looks like it uses GPUs"
        return [], 0, None
    return None, None, "GPUs not found on the resources line"


def machine_of(resources):
    name = (resources or "").split(",")[0].strip()
    return name or "unknown machine"


def writers(path):
    """True when one of this user's processes has the file open for writing, False when none has, and
    None when this machine gives no way to tell. Every process of a run holds its log open so."""
    real = os.path.realpath(path)
    if sys.platform.startswith("linux") and os.path.isdir("/proc/self/fd"):
        for pid in os.listdir("/proc"):
            if not pid.isdigit():
                continue
            fd_dir = "/proc/%s/fd" % pid
            try:
                fds = os.listdir(fd_dir)
            except OSError:
                continue
            for fd in fds:
                try:
                    if os.readlink(os.path.join(fd_dir, fd)) != real:
                        continue
                    # fdinfo starts with pos:, then flags:, the open mode in octal.
                    with open("/proc/%s/fdinfo/%s" % (pid, fd)) as f:
                        flags = next(int(line.split()[1], 8) for line in f if line.startswith("flags:"))
                except (OSError, ValueError, IndexError, StopIteration):
                    continue
                if flags & 3:  # O_WRONLY or O_RDWR
                    return True
        return False
    import shutil
    import subprocess
    if not shutil.which("lsof"):
        return None
    try:
        out = subprocess.run(["lsof", "-w", "-Fa", "--", real], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, universal_newlines=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    return any(line.startswith("a") and ("w" in line or "u" in line) for line in out.splitlines())


def pid_runs(pid, run_id, log_path):
    """True when the PID is alive and, as far as `ps` can tell, still the run's own shell."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    except OSError:
        return False
    try:
        with os.popen("ps -o command= -p %d 2>/dev/null" % pid) as f:
            command = f.read()
    except OSError:
        return True
    if not command.strip():
        return False
    return (run_id and run_id in command) or os.path.basename(log_path) in command


HEADER_KEYS = ("command", "purpose", "code", "outputs", "resources", "run-id", "session", "started")


def read_log(path):
    """The runs that start in one log. A start counts only inside a complete header, a run of header
    lines that ends at the stdout marker; a run with a run-id ends only at an end marker with its id."""
    runs, block, current = [], None, None
    with open(path, "r", errors="replace") as f:
        lines = f.read().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].rstrip("\r")
        if current is not None:
            e = END_MARK.search(line)
            want = current.get("run-id", "")
            if want and not (e and e.group(1).lower() == want.lower()):
                # The program's own output, whatever it prints, until the run's own end marker.
                i += 1
                continue
            if e and (not want or e.group(1).lower() == want.lower()):
                for j in range(i + 1, min(i + 3, len(lines))):
                    k = KEY.match(lines[j])
                    if k and k.group(1).lower() == "finished":
                        current["finished"] = k.group(2).strip()
                        i = j
                        break
                current, block = None, None
                i += 1
                continue
        m = KEY.match(line)
        # A header opens with a known field; inside it, any field counts, such as a plan line.
        if m and (m.group(1).lower() in HEADER_KEYS or (block is not None and m.group(1).lower() != "finished")):
            key = m.group(1).lower()
            if block is None:
                block = {}
            block[key] = m.group(2).strip()
            block["_last"] = key
        elif block is not None and block.get("_last") == "command" and line.startswith("#   "):
            block["command"] += "\n" + line.lstrip("#").strip()
        elif block is not None and STDOUT_MARK.search(line):
            if "started" in block:
                block.pop("_last", None)
                block["notes"] = []
                runs.append(block)
                current = block
            block = None
        else:
            block = None
        i += 1
    return runs


def count_log(path, since, until, now):
    rows = []
    runs = read_log(path)
    default_tz = None
    for r in runs:
        t = parse_time(r.get("started"))
        if t is not None and t.tzinfo is not None:
            default_tz = t.tzinfo
            break
    if default_tz is None:
        default_tz = datetime.datetime.now().astimezone().tzinfo
    last_write = datetime.datetime.fromtimestamp(os.path.getmtime(path), datetime.timezone.utc)
    previous_gpus = None
    for n, r in enumerate(runs):
        notes = r["notes"]
        start = parse_time(r.get("started"), default_tz)
        bare = parse_time(r.get("started"))
        if bare is not None and bare.tzinfo is None:
            notes.append("start time has no UTC offset: read in the log's time zone")
        end = None
        finished = r.get("finished")
        if finished is not None:
            end = parse_time(finished, default_tz)
            if end is None or start is None or end < start:
                d = DURATION.search(finished)
                if d and start is not None:
                    end = start + datetime.timedelta(hours=int(d.group(1)), minutes=int(d.group(2)),
                                                     seconds=int(d.group(3)))
                    notes.append("end taken from the footer's duration")
            if "unknown" in finished.lower():
                notes.append("closed by a restart at the log's last write: an upper bound")
        else:
            pid = PID.search(r.get("session", ""))
            alive = writers(path) if n == len(runs) - 1 else False
            if alive is None:
                alive = bool(pid) and pid_runs(int(pid.group(1)), r.get("run-id", ""), path)
            if n == len(runs) - 1 and alive:
                end = now
                notes.append("running: counted up to now")
            elif n + 1 < len(runs) and parse_time(runs[n + 1].get("started"), default_tz):
                end = parse_time(runs[n + 1].get("started"), default_tz)
                notes.append("no footer: counted up to the next start, an upper bound")
            else:
                end = last_write
                notes.append("no footer and no live process: counted up to the log's last write")
        ids, count, gpu_note = read_gpus(r.get("resources"), r.get("command"))
        if count is None and r.get("run-id") and NO_GPU.search(r.get("resources") or ""):
            ids, count, gpu_note = [], 0, None
        if count is None and previous_gpus is not None:
            ids, count = previous_gpus
            gpu_note = "GPUs taken from the previous start in this log"
        if gpu_note:
            notes.append(gpu_note)
        if count is not None:
            previous_gpus = (ids, count)
        hours = None
        if start is None or end is None:
            notes.append("unreadable start or end time")
        else:
            a, b = start, end
            if since is not None:
                a = max(a, since)
            if until is not None:
                b = min(b, until)
            hours = max(0.0, (b - a).total_seconds() / 3600)
        rows.append({
            "log": path,
            "machine": machine_of(r.get("resources")),
            "run_id": r.get("run-id"),
            "started": r.get("started"),
            "hours": hours,
            "gpu_ids": ids,
            "gpus": count,
            "gpu_hours": hours * count if hours is not None and count is not None else None,
            "notes": notes,
        })
    return rows


def has_header(path):
    try:
        with open(path, "rb") as f:
            head = f.read(SNIFF_BYTES)
    except OSError:
        return False
    return b"# command:" in head or b"# started:" in head


def find_logs(target, problems):
    if os.path.isfile(target):
        return [target]
    if not os.path.isdir(target):
        problems.append({"path": target, "note": "no such log or folder"})
        return []
    found, seen = [], set()

    def onerror(err):
        problems.append({"path": err.filename, "note": "cannot read: %s" % err.strerror})

    for root, dirs, names in os.walk(target, onerror=onerror, followlinks=True):
        real = os.path.realpath(root)
        if real in seen:
            dirs[:] = []
            continue
        seen.add(real)
        for name in sorted(names):
            p = os.path.join(root, name)
            if not os.path.isfile(p):
                if os.path.islink(p):
                    problems.append({"path": p, "note": "broken symlink"})
                continue
            if has_header(p):
                found.append(p)
    return sorted(set(found))


def shown(path):
    """A path relative to the current folder when it lies inside it, else as it is."""
    rel = os.path.relpath(path)
    return path if rel.startswith("..") else rel


def workspace_tz():
    """The time zone named by TZ in ./.env, else this process's own."""
    try:
        with open(".env") as f:
            for line in f:
                if line.startswith("TZ="):
                    name = line[3:].strip().strip("'\"")
                    try:
                        from zoneinfo import ZoneInfo  # Python 3.9 and later
                        return ZoneInfo(name)
                    except Exception:
                        os.environ["TZ"] = name
                        if hasattr(time, "tzset"):
                            time.tzset()
                        break
    except OSError:
        pass
    return datetime.datetime.now().astimezone().tzinfo


def in_remote_workspace():
    """True when this folder or one above it holds docs/AGENTS/remote.md: the local machine of a
    remote-mode workspace."""
    starts = [os.path.realpath(os.getcwd())]
    logical = os.environ.get("PWD", "")
    if logical and os.path.realpath(logical) == starts[0]:
        starts.append(logical)
    for d in starts:
        while True:
            if os.path.isfile(os.path.join(d, "docs", "AGENTS", "remote.md")):
                return True
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
    return False


def main(argv):
    as_json, since, until, targets = False, None, None, []
    args = list(argv)
    # The local machine of a remote-mode workspace runs no code; the remote host sets VRL_REMOTE.
    if in_remote_workspace() and not os.environ.get("VRL_REMOTE") \
            and not any(a in ("-h", "--help") for a in args):
        print("gpu_hours: this is the local machine of a remote-mode workspace: run gpu_hours.py on the "
              "remote host, through vrl_ssh.sh script", file=sys.stderr)
        return 2
    while args:
        a = args.pop(0)
        if a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if a == "--json":
            as_json = True
        elif a in ("--since", "--until"):
            if not args:
                print("gpu_hours: %s needs a time" % a, file=sys.stderr)
                return 2
            t = parse_time(args.pop(0), workspace_tz())
            if t is None:
                print("gpu_hours: cannot read the time after %s" % a, file=sys.stderr)
                return 2
            if a == "--since":
                since = t
            else:
                until = t
        elif a.startswith("-"):
            print("gpu_hours: unknown argument: " + a, file=sys.stderr)
            return 2
        else:
            targets.append(a)
    if not targets:
        print("gpu_hours: give the log folders of the idea's experiments", file=sys.stderr)
        return 2
    now = datetime.datetime.now(datetime.timezone.utc)
    problems, rows = [], []
    for target in targets:
        for path in find_logs(target, problems):
            try:
                found = count_log(path, since, until, now)
            except (OSError, UnicodeError) as err:
                problems.append({"path": path, "note": "cannot read: %s" % err})
                continue
            if not found:
                problems.append({"path": path, "note": "no complete header: not counted"})
            rows.extend(found)
    machines, by_gpu = {}, {}
    known = sum(r["gpu_hours"] for r in rows if r["gpu_hours"] is not None)
    unknown = sum(r["hours"] or 0 for r in rows if r["gpu_hours"] is None)
    for r in rows:
        m = machines.setdefault(r["machine"], {"gpu_hours": 0.0, "unknown_hours": 0.0})
        if r["gpu_hours"] is None:
            m["unknown_hours"] += r["hours"] or 0
        else:
            m["gpu_hours"] += r["gpu_hours"]
            for g in r["gpu_ids"] or []:
                key = "%s GPU %d" % (r["machine"], g)
                by_gpu[key] = by_gpu.get(key, 0.0) + r["hours"]
    incomplete = bool(problems) or any(r["gpu_hours"] is None for r in rows)
    if as_json:
        print(json.dumps({
            "runs": rows, "machines": machines, "by_gpu": by_gpu, "problems": problems,
            "single_gpu_hours": round(known, 2), "unknown_hours": round(unknown, 2),
        }, indent=2, default=str))
        return 3 if incomplete else 0
    print("| Log | Machine | Started | GPUs | Hours | Single-GPU hours | Notes |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        print("| %s | %s | %s | %s | %s | %s | %s |" % (
            shown(r["log"]).replace("|", "\\|"), r["machine"].replace("|", "\\|"),
            (r["started"] or "?").replace("|", "\\|"),
            "?" if r["gpus"] is None else ("GPU " + ",".join(map(str, r["gpu_ids"])) if r["gpu_ids"]
                                           else ("none" if r["gpus"] == 0 else "%d GPUs" % r["gpus"])),
            "?" if r["hours"] is None else "%.2f" % r["hours"],
            "?" if r["gpu_hours"] is None else "%.2f" % r["gpu_hours"],
            "; ".join(r["notes"]).replace("|", "\\|")))
    for p in problems:
        print("| %s | | | | | | %s |" % (p["path"], p["note"]))
    print()
    for name, m in sorted(machines.items()):
        line = "%s: %.2f single-GPU hours" % (name, m["gpu_hours"])
        if m["unknown_hours"]:
            line += ", plus %.2f hours with unknown GPUs" % m["unknown_hours"]
        print(line)
    print("Total: %.2f single-GPU hours" % known)
    if incomplete:
        print("Incomplete: %.2f hours with unknown GPUs, and %d files not counted; see the notes above."
              % (unknown, len(problems)))
    return 3 if incomplete else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
