#set this env var
export AOCL_BOARD_PACKAGE_ROOT=/path/to/bsp

#build aocx with this command for atlas2
aoc raytracer.cl -o bin/raytracer.aocx --fp-relaxed --report

#build host code
make -f Makefile
