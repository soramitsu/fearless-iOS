#ifndef VERIFY_GUARD_H
#define VERIFY_GUARD_H

#if defined(__cplusplus)
extern "C" {
#endif

#define VERIFY_F(i) differentbits |= x[i] ^ y[i];

static inline int crypto_verify_16(const unsigned char *x,
                                   const unsigned char *y) {
  unsigned int differentbits = 0;
  VERIFY_F(0)
  VERIFY_F(1)
  VERIFY_F(2)
  VERIFY_F(3)
  VERIFY_F(4)
  VERIFY_F(5)
  VERIFY_F(6)
  VERIFY_F(7)
  VERIFY_F(8)
  VERIFY_F(9)
  VERIFY_F(10)
  VERIFY_F(11)
  VERIFY_F(12)
  VERIFY_F(13)
  VERIFY_F(14)
  VERIFY_F(15)
  return (1 & ((differentbits - 1) >> 8)) - 1;
}

static inline int crypto_verify_32(const unsigned char *x,
                                   const unsigned char *y) {
  unsigned int differentbits = 0;
  VERIFY_F(0)
  VERIFY_F(1)
  VERIFY_F(2)
  VERIFY_F(3)
  VERIFY_F(4)
  VERIFY_F(5)
  VERIFY_F(6)
  VERIFY_F(7)
  VERIFY_F(8)
  VERIFY_F(9)
  VERIFY_F(10)
  VERIFY_F(11)
  VERIFY_F(12)
  VERIFY_F(13)
  VERIFY_F(14)
  VERIFY_F(15)
  VERIFY_F(16)
  VERIFY_F(17)
  VERIFY_F(18)
  VERIFY_F(19)
  VERIFY_F(20)
  VERIFY_F(21)
  VERIFY_F(22)
  VERIFY_F(23)
  VERIFY_F(24)
  VERIFY_F(25)
  VERIFY_F(26)
  VERIFY_F(27)
  VERIFY_F(28)
  VERIFY_F(29)
  VERIFY_F(30)
  VERIFY_F(31)

  // differentbits == 0 ? 0 : -1 but without conditional branches
  return (1 & ((differentbits - 1) >> 8)) - 1;
}

#undef VERIFY_F

#if defined(__cplusplus)
}
#endif

#endif
