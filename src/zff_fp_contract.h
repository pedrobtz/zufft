/* Forbid fused multiply-add contraction in the ducc0 code that follows
 * (design §10, §12.3). Include first, before any ducc0 header, in each
 * instantiation unit.
 *
 * With contraction, ducc0's SIMD batches and its scalar tail round
 * differently, and the batch boundaries depend on how lines are split
 * between threads, so results could differ in the last bit between
 * `workers` values. Without it they are bit-identical whatever the thread
 * count, at a cost of 1-4% on hardware with FMA.
 *
 * clang contracts within a statement by default; this pragma turns it off.
 * GCC contracts by default outside ISO mode, and R's Makevars may not pass
 * -ffp-contract=off (R CMD check warns about every -f flag), so a GCC build
 * for a target with FMA (an opt-in -march=native, or arm64 Linux) still
 * contracts; zufft_info()$fp_contract reports it. CRAN's builds are all
 * "off": its macOS arm64 binaries use clang, and its x86-64 targets have no
 * FMA instructions. The pragma is not a diagnostic pragma. */
#ifndef ZFF_FP_CONTRACT_H
#define ZFF_FP_CONTRACT_H
#if defined(__clang__)
#pragma clang fp contract(off)
#endif
#endif
