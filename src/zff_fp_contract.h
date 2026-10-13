/* Allow fused multiply-add contraction across statements in the ducc0 code
 * that follows (design §12.3). Include first, before any ducc0 header, in
 * each instantiation unit.
 *
 * GCC already contracts under R's -std=gnu++17 (its default outside ISO
 * mode is -ffp-contract=fast); clang's default contracts only within one
 * statement. The flag cannot go in Makevars, where R CMD check warns about
 * every -f flag, so clang gets the equivalent pragma. It is not a
 * diagnostic pragma. */
#ifndef ZFF_FP_CONTRACT_H
#define ZFF_FP_CONTRACT_H
#if defined(__clang__)
#pragma clang fp contract(fast)
#endif
#endif
