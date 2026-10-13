#!/usr/bin/env python3
"""Generate SciPy reference fixtures for zufft's tests (design §10).

    python3 -I tools/make-scipy-reference.py [OUTDIR]

Writes OUTDIR/cases.tsv (one row per case) and OUTDIR/data.bin
(little-endian doubles: each case's input, then its expected output), plus
OUTDIR/MANIFEST with the SciPy and NumPy versions and the platform. OUTDIR
defaults to tests/testthat/fixtures/scipy. Arrays are stored in R's
column-major order; complex values as (re, im) pairs. Axes in cases.tsv are
1-based, as zufft takes them. A case whose `error` column is 1 must fail.

Run it in a clean virtual environment with SciPy installed; the tests
compare within design §10's tolerance, so any recent SciPy whose fft backend
is ducc0 serves. The MANIFEST records which one produced the files.
"""
import itertools
import os
import platform
import sys

import numpy as np
import scipy
import scipy.fft as sf

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    "tests", "testthat", "fixtures", "scipy")
os.makedirs(out_dir, exist_ok=True)
rng = np.random.default_rng(20261013)

rows = []
blob = []
offset = 0  # in doubles


def put(arr):
    """Append arr (column-major) to the blob; return (dims, cplx, offset)."""
    global offset
    a = np.asarray(arr)
    cplx = np.iscomplexobj(a)
    flat = a.reshape(-1, order="F")
    if cplx:
        d = np.empty(2 * flat.size)
        d[0::2] = flat.real
        d[1::2] = flat.imag
    else:
        d = flat.astype(np.float64)
    start = offset
    blob.append(d.astype("<f8"))
    offset += d.size
    return ";".join(str(s) for s in a.shape), int(cplx), start


def rand(shape, cplx):
    x = rng.standard_normal(shape)
    if cplx:
        x = x + 1j * rng.standard_normal(shape)
    return np.asfortranarray(x)


def case(fn, x, *, type_=None, s=None, axes=None, norm=None, orth=None,
         inverse=False):
    """Run one SciPy call and record it; an exception records an error."""
    kw = {}
    if s is not None:
        kw["s"] = list(s)
    if axes is not None:
        kw["axes"] = list(axes)
    if norm is not None:
        kw["norm"] = norm
    if orth is not None:
        kw["orthogonalize"] = orth
    name = fn
    sp = {
        "c2c": sf.ifftn if inverse else sf.fftn,
        "r2c": sf.rfftn,
        "c2r": sf.irfftn,
        "dct": sf.idctn if inverse else sf.dctn,
        "dst": sf.idstn if inverse else sf.dstn,
    }[fn]
    args = (x,) if type_ is None else (x, type_)
    try:
        y = sp(*args, **kw)
        err = 0
    except (ValueError, TypeError, IndexError, RuntimeError):
        y = None
        err = 1
    ind, icp, ioff = put(x)
    if err:
        odims, ocp, ooff = "", 0, -1
    else:
        odims, ocp, ooff = put(y)
    rows.append([
        str(len(rows) + 1), name, str(int(inverse)),
        "" if type_ is None else str(type_),
        "" if s is None else ";".join(str(v) for v in s),
        "" if axes is None else ";".join(str(a + 1) for a in axes),
        "" if norm is None else norm,
        "" if orth is None else ("TRUE" if orth else "FALSE"),
        ind, str(icp), str(ioff), odims, str(ocp), str(ooff), str(err),
    ])


norms = ["backward", "ortho", "forward"]

# 1-D: every length 1-64 with every transform (all three norms up to 16,
# inverse DCT/DST up to 24), and a lighter set for some larger lengths. The
# set is sized to keep the fixtures near design §10's 1 MB budget.
for n in range(1, 65):
    for norm in (norms if n <= 16 else [norms[n % 3]]):
        case("c2c", rand(n, True), norm=norm, axes=[0])
        case("c2c", rand(n, False), norm=norm, axes=[0])
        case("c2c", rand(n, True), norm=norm, axes=[0], inverse=True)
        case("r2c", rand(n, False), norm=norm, axes=[0])
        case("c2r", rand(n // 2 + 1, True), s=[n], norm=norm, axes=[0])
        for t in (1, 2, 3, 4):
            if t == 1 and n < 2:
                continue
            case("dct", rand(n, False), type_=t, norm=norm, axes=[0])
            case("dst", rand(n, False), type_=t, norm=norm, axes=[0])
            if n <= 24:
                case("dct", rand(n, False), type_=t, norm=norm, axes=[0], inverse=True)
                case("dst", rand(n, False), type_=t, norm=norm, axes=[0], inverse=True)
for n in (97, 128, 210, 1009):
    norm = norms[n % 3]
    case("c2c", rand(n, True), norm=norm, axes=[0])
    case("c2c", rand(n, False), norm=norm, axes=[0])
    case("r2c", rand(n, False), norm=norm, axes=[0])
    case("c2r", rand(n // 2 + 1, True), s=[n], norm=norm, axes=[0])
    case("dct", rand(n, False), type_=2, norm=norm, axes=[0])
    case("dst", rand(n, False), type_=4, norm=norm, axes=[0])

# orthogonalize, for real and complex input (SciPy ignores an explicit value
# for complex input: design §6.1).
for n in (5, 8, 13):
    for t in (1, 2, 3, 4):
        for norm in ("ortho", "backward"):
            for orth in (True, False):
                for cplx in (False, True):
                    case("dct", rand(n, cplx), type_=t, norm=norm, orth=orth, axes=[0])
                    case("dst", rand(n, cplx), type_=t, norm=norm, orth=orth, axes=[0])

# 2-d and 3-d arrays over every ordered subset of axes.
for shape in ((5, 4), (3, 4, 5)):
    nd = len(shape)
    for k in range(1, nd + 1):
        for ax in itertools.permutations(range(nd), k):
            norm = norms[(len(rows)) % 3]
            case("c2c", rand(shape, True), axes=ax, norm=norm)
            case("c2c", rand(shape, False), axes=ax, norm=norm)
            case("r2c", rand(shape, False), axes=ax, norm=norm)
            half = list(shape)
            half[ax[-1]] = shape[ax[-1]] // 2 + 1
            case("c2r", rand(tuple(half), True), axes=ax,
                 s=[shape[a] for a in ax], norm=norm)
            case("dct", rand(shape, False), type_=2, axes=ax, norm=norm)
            case("dst", rand(shape, False), type_=3, axes=ax, norm=norm)

# crop and zero-pad.
for s in ((3, 7), (8, 2), (5, 4), (1, 9)):
    case("c2c", rand((5, 4), True), s=s, axes=[0, 1])
    case("r2c", rand((5, 4), False), s=s, axes=[0, 1])
    case("dct", rand((5, 4), False), type_=2, s=s, axes=[0, 1])
case("c2c", rand((3, 4, 5), True), s=(6, 2), axes=[2, 0])

# odd and even c2r output lengths.
for n in (5, 6, 7, 8, 9):
    case("c2r", rand(4, True), s=[n], axes=[0])
    case("c2r", rand((3, 4), True), s=[3, n], axes=[0, 1])

# validation failures.
case("c2c", rand(4, True), s=[0], axes=[0])
case("dct", rand(1, False), type_=1, axes=[0])
case("dct", rand(4, False), type_=5, axes=[0])

cols = ["id", "fn", "inverse", "type", "n", "axes", "norm", "orth",
        "in_dims", "in_cplx", "in_off", "out_dims", "out_cplx", "out_off",
        "error"]
with open(os.path.join(out_dir, "cases.tsv"), "w") as f:
    f.write("\t".join(cols) + "\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
np.concatenate(blob).astype("<f8").tofile(os.path.join(out_dir, "data.bin"))
with open(os.path.join(out_dir, "MANIFEST"), "w") as f:
    f.write(f"scipy\t{scipy.__version__}\n")
    f.write(f"numpy\t{np.__version__}\n")
    f.write(f"python\t{platform.python_version()}\n")
    f.write(f"platform\t{platform.platform()}\n")
    f.write(f"machine\t{platform.machine()}\n")
    f.write(f"cases\t{len(rows)}\n")
    f.write(f"doubles\t{offset}\n")
print(f"{len(rows)} cases, {offset * 8 / 1e6:.2f} MB in {out_dir}")
