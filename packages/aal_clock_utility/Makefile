#  AES: This is SKX-P Beta release Makefile for Hello_ALI_NLB, with
#       1) Source file name changed to "aal_6.2.1_skx-p_user_clk."
#       2) Additional files.
#       3) Precompiled header method
#       4) Added DFLAGS
#       5) Added "-Wall" switch.
#       6) Turned off optimizer and turned on debug
#  NOTE: AAL 6.2.1 generates warnings with "pedantic" but these
#        warnings were not present in AAL 5.0.2.  The warngins
#        are emitted from the AAL libraries and not the User Clock
#        source code, so they require AAL library changes to fix.
#        One can:
#          1) Live with the warnings
#          2) Remove the "pedantic" flag
#          3) Debug, by starting with "aalsdk/CAALEvent.h"
#
## Copyright(c) 2005-2016, Intel Corporation
##
## Redistribution  and  use  in source  and  binary  forms,  with  or  without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of  source code  must retain the  above copyright notice,
##   this list of conditions and the following disclaimer.
## * Redistributions in binary form must reproduce the above copyright notice,
##   this list of conditions and the following disclaimer in the documentation
##   and/or other materials provided with the distribution.
## * Neither the name  of Intel Corporation  nor the names of its contributors
##   may be used to  endorse or promote  products derived  from this  software
##   without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED TO,  THE
## IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED.  IN NO EVENT  SHALL THE COPYRIGHT OWNER  OR CONTRIBUTORS BE
## LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
## CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT LIMITED  TO,  PROCUREMENT  OF
## SUBSTITUTE GOODS OR SERVICES;  LOSS OF USE,  DATA, OR PROFITS;  OR BUSINESS
## INTERRUPTION)  HOWEVER CAUSED  AND ON ANY THEORY  OF LIABILITY,  WHETHER IN
## CONTRACT,  STRICT LIABILITY,  OR TORT  (INCLUDING NEGLIGENCE  OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,  EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##****************************************************************************
##  Accelerator Abstraction Layer Library Software Developer Kit (SDK)
##
##  Content:
##     samples/Hello_ALI_NLB/Makefile
##  Author:
##     Tim Whisonant, Intel Corporation
##     Joseph Grecco, Intel Corporation
##  History:
##     06/09/2015    JG   Initial version based off of canonical sample makefile
##******************************************************************************
CPPFLAGS ?=
CXX      ?= g++
LDFLAGS  ?=
DFLAGS   ?= -D DEF_SKX_P

ifeq (,$(CFLAGS))
#AES:
#CFLAGS = -g -O2
CFLAGS = -g -O0 -Wall
#AES: -Wall creating warnings in 6.2.1, but no warnings in 5.0.2.
endif

ifneq (,$(ndebug))
else
CPPFLAGS += -DENABLE_DEBUG=1 -D ASE_DEBUG=1
endif
ifneq (,$(nassert))
else
CPPFLAGS += -DENABLE_ASSERT=1
endif

ifeq (,$(DESTDIR))
ifneq (,$(prefix))
CPPFLAGS += -I$(prefix)/include
LDFLAGS  += -L$(prefix)/lib -Wl,-rpath-link -Wl,$(prefix)/lib -Wl,-rpath -Wl,$(prefix)/lib \
            -L$(prefix)/lib64 -Wl,-rpath-link -Wl,$(prefix)/lib64 -Wl,-rpath -Wl,$(prefix)/lib64
endif
else
ifeq (,$(prefix))
prefix = /usr/local
endif
CPPFLAGS += -I$(DESTDIR)$(prefix)/include
LDFLAGS  += -L$(DESTDIR)$(prefix)/lib -Wl,-rpath-link -Wl,$(prefix)/lib -Wl,-rpath -Wl,$(DESTDIR)$(prefix)/lib \
            -L$(DESTDIR)$(prefix)/lib64 -Wl,-rpath-link -Wl,$(prefix)/lib64 -Wl,-rpath -Wl,$(DESTDIR)$(prefix)/lib64
endif

all: aal_6.2.1_skx-p_user_clk.bin

aal_6.2.1_skx-p_user_clk.bin: qph_user_clk_pgm_Uclock_aal.hpp.gch qph_user_clk_pgm_Uclock_aal.o aal_6.2.1_skx-p_user_clk.o
	$(CXX) $(DFLAGS) $(CFLAGS) -o aal_6.2.1_skx-p_user_clk.bin qph_user_clk_pgm_Uclock_aal.o aal_6.2.1_skx-p_user_clk.o $(LDFLAGS) -lOSAL -lAAS -laalrt

aal_6.2.1_skx-p_user_clk.o: qph_user_clk_pgm_Uclock_aal.hpp.gch aal_6.2.1_skx-p_user_clk.cpp
	$(CXX) $(DFLAGS) $(CPPFLAGS) -D__AAL_USER__=1  $(CFLAGS) -c aal_6.2.1_skx-p_user_clk.cpp

qph_user_clk_pgm_Uclock_aal.o: qph_user_clk_pgm_Uclock_aal.hpp.gch qph_user_clk_pgm_Uclock_aal.cpp
	$(CXX) $(DFLAGS) $(CPPFLAGS) -D__AAL_USER__=1  $(CFLAGS) -c qph_user_clk_pgm_Uclock_aal.cpp

qph_user_clk_pgm_Uclock_aal.hpp.gch: qph_user_clk_pgm_Uclock_aal.hpp
	$(CXX) $(DFLAGS) $(CPPFLAGS) -D__AAL_USER__=1  $(CFLAGS) -c qph_user_clk_pgm_Uclock_aal.hpp

clean:
	$(RM) aal_6.2.1_skx-p_user_clk.bin
	$(RM) qph_user_clk_pgm_Uclock_aal.hpp.gch
	$(RM) qph_user_clk_pgm_Uclock_aal.o
	$(RM) aal_6.2.1_skx-p_user_clk.o

.PHONY:all clean
