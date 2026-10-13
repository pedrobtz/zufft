# zufft: Fast Fourier, Cosine and Sine Transforms with a Bundled 'ducc0'

Computes discrete Fourier transforms (complex, real-to-complex and
complex-to-real) and discrete cosine and sine transforms of types one to
four over any axes of an array, with the 'FFT' code of 'ducc0'
(<https://github.com/mreineck/ducc>) bundled in the 'BSD'-licensed
subset that 'SciPy' uses, so that no system 'FFTW' library is needed.
Transforms of any length run in O(n log n) time, real input uses true
real transforms, and several threads can share one transform. The
interface follows the conventions of 'scipy.fft' and offers the
unnormalised inverse of 'fftwtools' and stats::fft().

## See also

Useful links:

- <https://github.com/pedrobtz/zufft>

- <https://pedrobtz.github.io/zufft/>

- Report bugs at <https://github.com/pedrobtz/zufft/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]
