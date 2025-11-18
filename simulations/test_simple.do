# Clean
if {[file exists work]} {
    vdel -all
}
vlib work

# Compile stubs
vlog stub_modules.v

# Compile design
vlog ../src/GuitarTunerFPGA.v

# Compile simple test
vlog simple_test.v

# Load
vsim -voptargs="+acc" work.simple_test

# Add key waves
add wave -divider "Clocks"
add wave /simple_test/CLOCK_50
add wave /simple_test/audio_clk

add wave -divider "Control"
add wave /simple_test/KEY
add wave /simple_test/audio_in_available

add wave -divider "Write FSM"
add wave -color cyan /simple_test/dut/write_state
add wave /simple_test/wrreq
add wave /simple_test/wrfull
add wave -unsigned /simple_test/wrusedw

add wave -divider "Read FSM"
add wave -color cyan /simple_test/dut/read_state  
add wave /simple_test/rdreq
add wave /simple_test/rdfull
add wave /simple_test/rdempty
add wave -unsigned /simple_test/rdusedw

add wave -divider "FFT Signals"
add wave /simple_test/sink_valid
add wave -color orange /simple_test/sink_sop
add wave -color orange /simple_test/sink_eop

# Run
run 500us
wave zoom full