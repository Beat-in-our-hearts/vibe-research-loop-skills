"""Tests for gpu_hours.py: python3 -m unittest test_gpu_hours, from tests/scripts."""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "skills", "vrl-init-workspace",
                      "scripts", "gpu_hours.py")
START, END = "2026-10-08 12:00:00 +04:00", "2026-10-08 14:00:00 +04:00"


def header(resources="box, GPU 0,1 (NVIDIA H100 80GB HBM3), Python env v", start=START, run_id="abc123def456",
           session="PID 999999", command="python train.py", extra=""):
    lines = ["# command:   " + command, "# purpose:   d / r: a test", "# code:      none", "# outputs:   none"]
    if resources is not None:
        lines.append("# resources: " + resources)
    if run_id:
        lines.append("# run-id:    " + run_id)
    lines += ["# session:   " + session, "# started:   " + start, extra, "# ---------- stdout + stderr ----------"]
    return "\n".join(l for l in lines if l) + "\n"


def footer(end=END, run_id="abc123def456", code="0", duration="(2:00:00)"):
    return "# ---------- end %s ----------\n# finished:  %s %s, exit code %s\n" % (run_id, end, duration, code)


class GpuHours(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def write(self, name, text, mtime=None):
        path = os.path.join(self.dir, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", newline="") as f:
            f.write(text)
        if mtime is not None:
            os.utime(path, (mtime, mtime))
        return path

    def count(self, *args):
        out = subprocess.run([sys.executable, SCRIPT, "--json"] + list(args) + [self.dir], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, universal_newlines=True)
        self.assertIn(out.returncode, (0, 3), out.stderr)
        result = json.loads(out.stdout)
        result["rc"] = out.returncode
        return result

    def test_basic(self):
        self.write("a.log", header() + "hi\n" + footer())
        r = self.count()
        self.assertAlmostEqual(r["single_gpu_hours"], 4.0)
        self.assertEqual(r["rc"], 0)

    def test_output_cannot_fake_a_start_or_an_end(self):
        fake = "# started: 2026-10-08 12:05:00 +04:00\n# ---------- end ----------\n# finished: 2026-10-08 12:06:00 +04:00\n"
        self.write("a.log", header() + fake + "more\n" + footer())
        self.assertAlmostEqual(self.count()["single_gpu_hours"], 4.0)

    def test_running_process_counts_to_now(self):
        start = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(time.time() - 3600)) + " " + \
            time.strftime("%z")[:3] + ":" + time.strftime("%z")[3:]
        path = self.write("a.log", header(start=start, session="PID 999999"))
        # A run's processes hold its log open for writing; that, not the PID, says it runs.
        log = open(path, "a")
        proc = subprocess.Popen(["sleep", "30"], stdout=log)
        try:
            os.utime(path, (time.time() - 3500, time.time() - 3500))
            r = self.count()
            self.assertAlmostEqual(r["single_gpu_hours"], 2.0, delta=0.05)
            self.assertIn("running", " ".join(r["runs"][0]["notes"]))
        finally:
            proc.kill()
            log.close()

    def test_time_formats(self):
        for i, (s, e) in enumerate([("2026-10-08T12:00:00+04:00", "2026-10-08T14:00:00+04:00"),
                                    ("2026-10-08 08:00:00.123 Z", "2026-10-08 10:00:00 UTC"),
                                    ("2026-10-08 12:00:00 +0400", "2026-10-08 14:00:00 +04")]):
            self.write("t%d.log" % i, header(start=s) + footer(end=e))
        self.assertAlmostEqual(self.count()["single_gpu_hours"], 12.0)

    def test_gpu_spellings(self):
        cases = ["box, gpu 0,1 (A100)", "box, GPUs: 0,1", "box, 2 GPUs (A100)", "box, GPU 0,1 - A100",
                 "box, CUDA_VISIBLE_DEVICES=0,1", "box, GPU 0-1 80GB H100"]
        for i, res in enumerate(cases):
            self.write("g%d.log" % i, header(resources=res) + footer())
        r = self.count()
        self.assertEqual([x["gpus"] for x in r["runs"]], [2] * len(cases))

    def test_no_gpu_but_command_uses_gpus_is_unknown(self):
        # A hand-written log, without a run-id: launch_run would have emptied CUDA_VISIBLE_DEVICES.
        self.write("a.log", header(resources="box, no GPU, Python env v", command="torchrun --nproc_per_node=4 t.py",
                                   run_id="") + footer(run_id=""))
        r = self.count()
        self.assertEqual(r["rc"], 3)
        self.assertAlmostEqual(r["unknown_hours"], 2.0)

    def test_unknown_gpus_are_reported_not_dropped(self):
        self.write("a.log", header(resources="box, Python env v") + footer())
        r = self.count()
        self.assertEqual(r["rc"], 3)
        self.assertAlmostEqual(r["unknown_hours"], 2.0)

    def test_restart_closed_by_launch_run(self):
        text = header() + "x\n" + footer(end="2026-10-08 13:00:00 +04:00", duration="(unknown)",
                                         code="unknown: closed by a restart at the log's last write")
        text += header(start="2026-10-08 13:30:00 +04:00", run_id="ffffffffffff") + footer(end=END, run_id="ffffffffffff")
        self.write("a.log", text)
        self.assertAlmostEqual(self.count()["single_gpu_hours"], 3.0)

    def test_files_of_any_name_and_symlinked_folders(self):
        self.write("sub/run2.txt", header() + footer())
        other = tempfile.mkdtemp()
        with open(os.path.join(other, "b.log"), "w") as f:
            f.write(header() + footer())
        os.symlink(other, os.path.join(self.dir, "linked"))
        os.symlink(os.path.join(self.dir, "missing.log"), os.path.join(self.dir, "broken.log"))
        r = self.count()
        self.assertAlmostEqual(r["single_gpu_hours"], 8.0)
        self.assertIn("broken symlink", [p["note"] for p in r["problems"]])

    def test_since_until_and_machines(self):
        self.write("a.log", header() + footer())
        self.write("b.log", header(resources="other, GPU 3 (A100)") + footer())
        r = self.count("--since", "2026-10-08 13:00 +04:00")
        self.assertAlmostEqual(r["single_gpu_hours"], 3.0)
        self.assertEqual(sorted(r["machines"]), ["box", "other"])
        self.assertAlmostEqual(r["by_gpu"]["other GPU 3"], 1.0)

    def test_a_full_header_in_the_output_is_output(self):
        fake = header(resources="other, GPU 0-7 (A100)", start="2026-10-01 00:00:00 +04:00", run_id="ffffffffffff")
        fake += footer(end="2026-10-01 22:00:00 +04:00", run_id="ffffffffffff")
        self.write("a.log", header() + fake + "# ---------- end ----------\n" + footer())
        r = self.count()
        self.assertAlmostEqual(r["single_gpu_hours"], 4.0)
        self.assertEqual(list(r["machines"]), ["box"])

    def test_a_long_command_still_counts(self):
        self.write("a.log", header(command="python train.py " + "--flag x " * 600) + footer())
        self.assertAlmostEqual(self.count()["single_gpu_hours"], 4.0)

    def test_no_gpu_from_launch_run_is_trusted(self):
        self.write("a.log", header(resources="box, no GPU, Python env gpu2", command="pip install accelerate deepspeed") + footer())
        r = self.count()
        self.assertEqual((r["rc"], r["single_gpu_hours"], r["unknown_hours"]), (0, 0, 0))

    def test_bad_time_does_not_crash(self):
        self.write("a.log", header(start="2026-10-08 12:00:60 +04:00") + footer())
        self.assertEqual(self.count()["rc"], 3)


if __name__ == "__main__":
    unittest.main()
