SYNC=_sync
OBJ_DIR=obj_dir
VERILATOR_DIR=/usr/share/verilator/include
HDL_FILES = \
	../rtl/video${SYNC}/autoanim.v \
	../rtl/video/autoanim.v \
	../rtl/video${SYNC}/fast_cycle.v \
	../rtl/video/fast_cycle.v \
	../rtl/video${SYNC}/slow_cycle.v \
	../rtl/video/slow_cycle.v \
	../rtl/video${SYNC}/hshrink.v \
	../rtl/video/hshrink.v \
	../rtl/video${SYNC}/irq.v \
	../rtl/video/irq.v \
	../rtl/video${SYNC}/neo_b1.v \
	../rtl/video${SYNC}/linebuffer.v \
	../rtl/video${SYNC}/lspc2_a2.v \
	../rtl/video/lspc2_a2.v \
	../rtl/video${SYNC}/lspc2_clk.v \
	../rtl/video/lspc2_clk.v \
	../rtl/video${SYNC}/lspc_regs.v \
	../rtl/video/lspc_regs.v \
	../rtl/video${SYNC}/lspc_timer.v \
	../rtl/video/lspc_timer.v \
	../rtl/video${SYNC}/neo_273.v \
	../rtl/video${SYNC}/neo_cmc.v \
	../rtl/video${SYNC}/neo_zmc2.v \
	../rtl/video${SYNC}/videosync.v \
	../rtl/video/videosync.v \
	../rtl/video${SYNC}/zmc2_dot.v \
	../rtl/cells/bd3.v \
	../rtl/cells/C43.v \
	../rtl/cells/fd2.v \
	../rtl/cells/fd3.v \
	../rtl/cells/fd4.v \
	../rtl/cells/fdm.v \
	../rtl/cells/fdp.v \
	../rtl/cells/fdr.v \
	../rtl/cells/fds16bit.v \
	../rtl/cells/fds.v \
	../rtl/cells/fjd.v \
	../rtl/cells/fs1.v \
	../rtl/cells/fs2.v \
	../rtl/cells/fs3.v \
	../rtl/cells/lt4.v \
	../rtl/io${SYNC}/register.v \
	../rtl/io/clocks.v \
	../rtl/io${SYNC}/clocks.v \
	../rtl/io${SYNC}/resetp.v \
	../rtl/io/resetp.v \
	../rtl/io${SYNC}/watchdog.v\
	spram.v


default: run

Vlspc_tb.cpp: ${OBJ_DIR}/Vlspc_tb.cpp


${OBJ_DIR}/Vlspc_tb.cpp: lspc_tb.v ${HDL_FILES}
	verilator -cc --exe -MMD --trace --top-module lspc_tb lspc_tb.cpp lspc_tb.v ${HDL_FILES}

lspc_tb: ${OBJ_DIR}/Vlspc_tb.cpp lspc_tb.cpp
	$(MAKE) -j 4 -C obj_dir -f ../Makefile_obj

run: lspc_tb
	obj_dir/Vlspc_tb

video: video.png

video.png: video.rgb
	rm -f video.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt argb -s 768x264 -i video.rgb -f image2 -vcodec png video.png
	display video.png
