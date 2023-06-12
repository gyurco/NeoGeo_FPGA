## Testbench for Neo-Geo LSPC2 (and some support) chip

Put:

- 000-lo.lo
- crom_even.bin
- crom_odd.bin
- sfix.sfix
- palram.bin
- vram.bin

files to mems/ directory (or unzip one of the examples in the repo), and run the testbench (via Verilator) with 'make' command.
It'll run the chipset for one frame, and dump the waveforms to **lspc.vcd**, and the video output to **video.rgb**.

'make video' will generate a png file from the **video.rgb** dump.

**lspc.vcd** can be examined with gtkwave for example.
