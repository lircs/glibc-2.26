/* Determine floating-point rounding mode within libc.  AArch64 version.

   Copyright (C) 2012-2017 Free Software Foundation, Inc.

   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#ifndef _AARCH64_GET_ROUNDING_MODE_H
#define _AARCH64_GET_ROUNDING_MODE_H	1

#include <fenv.h>
#include <fpu_control.h>

/* Return the floating-point rounding mode.  */

static inline int
get_rounding_mode (void)
{
  fpu_control_t fpcr;

  _FPU_GETCW (fpcr);
  return fpcr & _FPU_FPCR_RM_MASK;
}

#endif /* get-rounding-mode.h */
