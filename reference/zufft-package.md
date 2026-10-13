# zufft: Fast Fourier, Cosine and Sine Transforms

Computes discrete Fourier transforms (complex, real-to-complex and
complex-to-real) and discrete cosine and sine transforms of types one to
four over any axes of an array, with the fast Fourier transform (FFT)
code of 'ducc0' (<https://github.com/mreineck/ducc>) bundled in the
BSD-licensed subset that 'SciPy' uses. Transforms of any length run in
O(n log n) time, real input uses true real transforms, and several
threads can share one transform.

## See also

Useful links:

- <https://github.com/pedrobtz/zufft>

- <https://pedrobtz.github.io/zufft/>

- Report bugs at <https://github.com/pedrobtz/zufft/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Martin Reinecke (ducc0, bundled in src/ducc0) \[contributor\]

- Peter Bell (ducc0, bundled in src/ducc0) \[contributor, copyright
  holder\]

- Max-Planck-Society (ducc0, bundled in src/ducc0) \[copyright holder\]

- Matteo Frigo (odd-sized DCT-IV in src/ducc0/fft/fft1d_impl.h)
  \[copyright holder\]

- Massachusetts Institute of Technology (odd-sized DCT-IV in
  src/ducc0/fft/fft1d_impl.h) \[copyright holder\]

- The TensorFlow Authors (helpers in src/ducc0/infra/threading.cc)
  \[copyright holder\]

- SciPy Developers (fast-length search in src/zff_lengths.cpp, from
  SciPy) \[copyright holder\]
