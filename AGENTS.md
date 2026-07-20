# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is
This is the problem-solving repo for a HUD Verilog eval takehome (`takehome-mac-rne-sat`).
The "application" is a SystemVerilog module (`sources/mac_rne_sat.sv`, a signed 8x8
multiply-accumulate unit) that is exercised by a **cocotb** testbench running on
**Icarus Verilog**. Python deps are managed with **uv** (`pyproject.toml` / `uv.lock`);
the toolchain is `uv` + `iverilog` (`-g2012`) + `cocotb` + `pytest`.

The HUD/Docker evaluation framework described in the walkthrough (Sections 6+) lives in a
**separate repo** (`verilog-coding-template`) that is NOT part of this repository.

### Branch layout (important gotcha)
The hidden grading testbench (`tests/test_mac_rne_sat.py`) exists **only on the
`mac_rne_sat_test` branch**, not on `mac_rne_sat_baseline` (the default) or
`mac_rne_sat_golden`. To run tests without switching branches, materialize it locally:

```bash
mkdir -p tests
git show origin/mac_rne_sat_test:tests/test_mac_rne_sat.py > tests/test_mac_rne_sat.py
```

`tests/` and `sim_build/` are not tracked on baseline; leave them untracked (they are
regenerated). `sources/mac_rne_sat.sv` ships as an empty skeleton on all three branches.

### Running the testbench
From the repo root, after the test file is present:

```bash
cd tests
uv run pytest test_mac_rne_sat.py --log-cli-level=INFO
```

The pytest runner invokes `iverilog` to compile `sources/mac_rne_sat.sv`, then runs the two
cocotb tests (`directed_corners`, `randomized_lockstep`). The baseline skeleton **fails by
design** (its outputs are tied low); a correct implementation passes both tests.

When swapping the RTL under test, clear stale build artifacts first, or you may re-run an old
compile: `rm -rf sim_build __pycache__ tests/__pycache__`.

### Toolchain notes
- `iverilog`/`vvp` are installed system-wide (`/usr/bin`); `uv` is symlinked into
  `/usr/local/bin` so it is on PATH in non-interactive shells.
- cocotb 2.x is used; the test file already handles the `cocotb_tools.runner` vs
  `cocotb.runner` import difference across cocotb versions.
