#!/usr/bin/env python3
"""The original: converts between integers and Roman numerals."""
import sys

VALUES = [
    (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
    (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
    (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
]


def to_roman(n):
    out = ""
    for value, symbol in VALUES:
        while n >= value:
            out += symbol
            n -= value
    return out


def from_roman(s):
    n = 0
    rest = s
    for value, symbol in VALUES:
        while rest.startswith(symbol):
            n += value
            rest = rest[len(symbol):]
    if rest or not 1 <= n <= 3999 or to_roman(n) != s:
        return None
    return n


def main():
    if len(sys.argv) != 2:
        print("usage: roman <number|numeral>", file=sys.stderr)
        return 1
    arg = sys.argv[1]
    if arg.isdigit():
        n = int(arg)
        if not 1 <= n <= 3999:
            print("out of range", file=sys.stderr)
            return 2
        print(to_roman(n))
        return 0
    n = from_roman(arg.upper())
    if n is None:
        print("not a numeral", file=sys.stderr)
        return 2
    print(n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
