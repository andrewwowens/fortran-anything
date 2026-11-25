---
name: fortran-anything
description: Use when asked to rewrite, port or migrate a command-line program to Fortran. Records what the original does, then checks each piece of the Fortran port against that recording before moving on.
---

# fortran-anything

Port a CLI to Fortran without guessing whether it still behaves the same. The original is run once on a list of cases and its stdout and exit code are saved. Your Fortran is replayed on the same cases and has to match byte for byte.

You write the Fortran. The tool only tells you whether it matches.

## Setup

Build the tool once with `make` (needs `gfortran`). The binary lands at `build/fortran-anything`.

## The loop

1. Write `cases.txt`. One case per line, holding the arguments to append to the command. A line can carry a stdin redirect (`< input.txt`). For a run with no arguments use `< /dev/null`. Blank lines and `#` lines are skipped. Cover the normal paths, the error paths and the odd inputs: empty strings, leading zeros, values at and past each limit.
2. Record the original:
   `fortran-anything record --cases cases.txt -- python3 original.py`
3. Port one piece to Fortran and compile it.
4. Replay:
   `fortran-anything diff -- ./port`
   Every case prints `match` or `MISMATCH`. For a mismatch, compare the two files it names under `.fortran-anything/recording` and `.fortran-anything/replay`.
5. Fix the Fortran and run `diff` again. Don't edit the recording to make a case pass. If the recording is wrong, fix the cases and record again.
6. `fortran-anything gate` exits 0 only when the last diff matched every case. Don't call the port done before it does.

## Limits

- It only catches what the cases cover. A behavior with no case is unchecked.
- stdout and the exit code are compared. stderr is saved next to them but not compared.
- Each case line is handed to the shell as written, so quote arguments the way you would at a prompt.
- Output that changes between runs (timestamps, random values, temp paths) will never match. Pin it down in the original before recording.

## Fortran notes

- `write (*, '(A)')` and `'(I0)'` give output with no leading blank. List-directed `print *` adds one and will not match.
- Exit with `stop N, quiet=.true.` so nothing extra is printed.
- Use `character(len=:), allocatable` with `get_command_argument(i, length=n)` to read arguments of any length.
