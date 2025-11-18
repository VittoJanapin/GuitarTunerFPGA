# Clean start
if {[file exists work]} {
    vdel -all
}
vlib work

# Compile stub modules
vlog stub_modules.v

# Compile your main design
vlog ../src/GuitarTunerFPGA.v

# Compile testbench
vlog FIFO_Sims/testbench.v

# Load simulation
vsim -voptargs="+acc" work.tb_Project

# Add waves for YOUR state machines
add wave -divider "Clocks"
add wave /tb_Project/CLOCK_50
add wave /tb_Project/dut/wrclk
add wave /tb_Project/dut/rdclk

add wave -divider "Reset"
add wave /tb_Project/KEY

add wave -divider "FIFO WRITE State Machine"
add wave -color cyan /tb_Project/dut/write_state
add wave /tb_Project/dut/next_write_state
add wave /tb_Project/dut/wrreq
add wave /tb_Project/dut/wrfull
add wave /tb_Project/dut/wrempty
add wave -unsigned /tb_Project/dut/wrusedw
add wave /tb_Project/dut/audio_in_available

add wave -divider "FIFO READ State Machine"
add wave -color cyan /tb_Project/dut/read_state
add wave /tb_Project/dut/next_read_state
add wave /tb_Project/dut/rdreq
add wave /tb_Project/dut/rdfull
add wave /tb_Project/dut/rdempty
add wave -unsigned /tb_Project/dut/rdusedw

add wave -divider "FFT Interface"
add wave /tb_Project/dut/sink_valid
add wave /tb_Project/dut/sink_ready
add wave -color orange /tb_Project/dut/sink_sop
add wave -color orange /tb_Project/dut/sink_eop
add wave -hex /tb_Project/dut/audio_out

# Run
run 10ms
wave zoom full