project(libmmd)

set(MMD_SRC
   ccip_mmd.cpp
   ccip_mmd_device.cpp
   dma_work_thread.cpp
   fpgaconf.c
   fpga_dma.c
   kernel_interrupt.cpp
   mmd_dma.cpp
   test_perm.cpp
   zlib_inflate.c
)

add_library(intel_opae_mmd SHARED ${MMD_SRC})

target_link_libraries(intel_opae_mmd
   -lrt
   -lpkg_editor
   -lz
   -lelf
   -lopae-c
   -luuid
   safestr
)

install(TARGETS intel_opae_mmd
   LIBRARY DESTINATION lib
   COMPONENT libmmd 
)
