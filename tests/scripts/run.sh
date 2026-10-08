#!/usr/bin/env bash
# Run every script test: bash tests/scripts/run.sh
cd "$(dirname "$0")" || exit 1
status=0
for f in *.test.sh; do
	echo "== $f"
	bash "$f" || status=1
done
echo "== test_gpu_hours.py"
python3 -m unittest -q test_gpu_hours || status=1
exit "$status"
