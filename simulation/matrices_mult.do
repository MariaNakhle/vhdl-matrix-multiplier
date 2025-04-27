# Turn on transcript to log all console output to a file
transcript on

# Check if the library 'rtl_work' exists and delete it if it does
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}

# Create a new library 'rtl_work' for the simulation
vlib rtl_work

# Map the logical library 'work' to the 'rtl_work' physical library
vmap work rtl_work

# Compile all the VHDL source files into the 'work' library
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/sync_diff.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/num_convert.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/my_multiplier.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/matrix_ram.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/matrices_mult.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/main_controller.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/data_generator_pack.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/bin2bcd_12bit_sync.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/bcd_to_7seg.vhd}
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/src/data_generator.vhd}

# Compile the testbench file
vcom -2008 -work work {C:/Users/aboud/VHDL2024B/FinalProject/par/../src/matrices_mult_tb.vhd}

# Simulate the testbench with specific libraries and options
vsim -t 1ps -L altera -L lpm -L sgate -L altera_mf -L altera_lnsim -L cyclonev -L rtl_work -L work -voptargs="+acc"  matrices_mult_tb

# Add all signals to the waveform view, grouped by their hierarchy
add wave -group matrices_mult_tb/* -- Add all top-level testbench signals
add wave -group matrices_mult matrices_mult_tb/dut/* -- Add all signals from the DUT

# Add signals from specific components in the design under test (DUT)
add wave -group data_generator matrices_mult_tb/dut/data_gen/*
add wave -group main_controller matrices_mult_tb/dut/main_ctrl/*
add wave -group matrix_ram_inst matrices_mult_tb/dut/main_ctrl/matrix_ram_inst/*
add wave -group mult1 matrices_mult_tb/dut/main_ctrl/mult1/*
add wave -group mult2 matrices_mult_tb/dut/main_ctrl/mult2/*
add wave -group mult3 matrices_mult_tb/dut/main_ctrl/mult3/*
add wave -group mult4 matrices_mult_tb/dut/main_ctrl/mult4/* 

add wave -group bin2bcd_12bit_sync matrices_mult_tb/dut/bin2bcd_inst/*
add wave -group num_convert matrices_mult_tb/dut/num_convert_inst/*

add wave -group bcd_to_7seg_inst0 matrices_mult_tb/dut/bcd_to_7seg_inst0/*
add wave -group bcd_to_7seg_inst1 matrices_mult_tb/dut/bcd_to_7seg_inst1/*
add wave -group bcd_to_7seg_inst2 matrices_mult_tb/dut/bcd_to_7seg_inst2/*
add wave -group bcd_to_7seg_inst3 matrices_mult_tb/dut/bcd_to_7seg_inst3/*

add wave -group sync_diff_START matrices_mult_tb/dut/sync_diff_START/*
add wave -group sync_diff_DISPLAY matrices_mult_tb/dut/sync_diff_DISPLAY/*

# Open the structure and signals views in the simulator GUI
view structure
view signals

# Run the simulation indefinitely or until manually stopped
run -all