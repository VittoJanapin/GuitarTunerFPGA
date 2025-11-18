# Set working library
vlib work
vmap work work

# Map to pre-compiled Altera libraries (adjust path for your installation)
vmap altera_mf C:/intelFPGA/18.1/modelsim_ase/altera/verilog/altera_mf
vmap altera_lnsim C:/intelFPGA/18.1/modelsim_ase/altera/verilog/altera_lnsim
vmap cyclonev C:/intelFPGA/18.1/modelsim_ase/altera/verilog/cyclonev

# If above don't exist, try these paths:
# vmap altera_mf C:/intelFPGA/18.1/quartus/eda/sim_lib/altera_mf
# vmap altera_lnsim C:/intelFPGA/18.1/quartus/eda/sim_lib/altera_lnsim
# vmap cyclonev C:/intelFPGA/18.1/quartus/eda/sim_lib/cyclonev

# Compile your IP cores directly (they reference the libraries)
vlog -work work DualClockFIFOBucket/DualClockFIFOBucket.v
vlog -work work TunerFFT/sim/TunerFFT.vo

# Compile your design files
vlog -work work Audio_Controller.v
vlog -work work avconf.v  
vlog -work work Project.v

# Compile testbench
vlog -work work tb_Project.v

# Start simulation with library references
vsim -L altera_mf -L altera_lnsim -L cyclonev -voptargs="+acc" work.tb_Project

# Add waves (same as before)
add wave -divider "Clock & Reset"
add wave /tb_Project/CLOCK_50
add wave /tb_Project/KEY

add wave -divider "FIFO Write FSM"
add wave -color cyan /tb_Project/dut/write_state
add wave /tb_Project/dut/wrreq
add wave /tb_Project/dut/wrfull
add wave /tb_Project/dut/wrempty
add wave -unsigned /tb_Project/dut/wrusedw

add wave -divider "FIFO Read FSM"
add wave -color cyan /tb_Project/dut/read_state
add wave /tb_Project/dut/rdreq
add wave /tb_Project/dut/rdfull
add wave /tb_Project/dut/rdempty
add wave -unsigned /tb_Project/dut/rdusedw

add wave -divider "FFT Sink"
add wave /tb_Project/dut/sink_valid
add wave /tb_Project/dut/sink_ready
add wave -color orange /tb_Project/dut/sink_sop
add wave -color orange /tb_Project/dut/sink_eop
add wave -hex /tb_Project/dut/audio_out

# Run
run 5ms
wave zoom full