# Fast Litmus Test for RISC-V

This fast-litmus-riscv repository contains fast litmus tests for the
RISC-V concurrency architecture, as used by members of the RISC-V
Memory Model Task Group during the architecture development.

All of the litmus tests are collected from litmus-tests-riscv, RISC-V 
ISA manual and herd paper.


Contributors
======

- Xuezheng (xuezhengxu@126.com)
- Jintao (jintaohu912@126.com)



Links
=====
* The [litmus-tests-riscv](https://github.com/litmus-tests/litmus-tests-riscv) - most tests are automatically generated using the diy.

* The [RISC-V Instruction Set Manual](https://github.com/riscv/riscv-isa-manual/) - see especially Sections 14 *RVWMO Memory Consistency Model*,
A *RVWMO Explanatory Material*, and
B *Formal Memory Model Specifications*, which contain text versions of axiomatic and operational models. 

* [The diy tool suite (including diy, litmus, and herd)](http://diy.inria.fr/)

* [The herd RISC-V model](http://diy.inria.fr/cats7/riscv/cat.tar)

* [The herd paper](https://arxiv.org/abs/1308.6810)


Files
=====

* LICENCE - Licence

* Makefile - For running hardware tests and comparing results (see below)

* riscv.cfg - A litmus configuration file (used by Makefile)

* README.md - This file

* README-old.md - The readme file from litmus-tests-riscv.

* model-results - Results from axiomatic ("Herd", in herd) models on the tests (see Makefile).

* tests - Each test is in a separate .litmus file. 



Quick Start
=============================

To generate the C program and build it, do

```bash
make hw-tests CORES=<n> [GCC=<gcc>] [-j <m>]`
```

For example, if your hardware platform has 4 cores and your toolchain is riscv64-linux-gcc:

```bash
make hw-tests CORES=4 GCC=riscv64-linux-gcc -j8
```

To run it on qemu, do

```bash
qemu-riscv64 hw-tests/run.exe
```

To run it natively on hardware, do

```bash
hw-tests/run.sh
```

To clean all generated files, do

```bash
make clean
```

See README-old.md for more details.


Simulating on Herd
=================================

Simulating litmus tests on Herd, do

```bash
herd7 -model ./model/riscv.cat -I ./model/<DIR_TO_MODEL>/ ./tests/<PATH_TO_LITMUS>
```

For example:

```bash
herd7 -model ./model/riscv.cat -I ./model/rvwmo/ ./tests/origin/allow/PPO122.litmus
```

Litmus Verification
==================================

To verify the correctness of the fast litmus tests, do

```bash
make verify-<Type: allow|forbidden>-<name>
```

For example:

```bash
make verify-allow-SB
make verify-forbidden-PPO13
```
