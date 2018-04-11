project(libmmd)

enable_language(C ASM)

set(ASM_OPTIONS "-x assembler-with-cpp")
set(CMAKE_ASM_FLAGS "${CFLAGS} ${ASM_OPTIONS}")

set(MMD_SRC
   ccip_mmd.cpp
   ccip_mmd_device.cpp
   dma_work_thread.cpp
   fpgaconf.c
   fpga_dma.c
   kernel_interrupt.cpp
   mmd_dma.cpp
   memcpy_s_fast.c
   test_perm.cpp
   zlib_inflate.c
   x86-sse2.S
)

add_library(intel_opae_mmd SHARED ${MMD_SRC})

target_link_libraries(intel_opae_mmd
   pkg_editor.a
   safestr
   libelf.so.0
   -lpthread
   -lz
   -lopae-c
   -luuid
)

install(TARGETS intel_opae_mmd
   LIBRARY DESTINATION lib
   COMPONENT libmmd 
)
