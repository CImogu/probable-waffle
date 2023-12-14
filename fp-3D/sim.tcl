create_project -force -part  xc7s50csga324-1 ip_tb ip_tb

read_verilog -sv [ glob ./hdl/*.sv ]
read_verilog  [ glob ./hdl/*.v ]
read_mem [ glob ./data/*.mem ]
read_verilog -sv [ glob ./sim/*.sv ]

read_ip ./ip/adder/adder.xci
read_ip ./ip/adder_many/adder_many.xci
read_ip ./ip/multiplier/multiplier.xci
read_ip ./ip/sqrt/sqrt.xci
read_ip ./ip/difference/difference.xci
read_ip ./ip/fixed2float/fixed2float.xci

# read_ip ./ip/divide_many/divide_many.xci
# read_ip ./ip/multiply_many/multiply_many.xci
# read_ip ./ip/float2fixed_many/float2fixed_many.xci
generate_target all [get_ips]
synth_ip [get_ips]

set_property top threegen_tb [get_fileset sim_1]
launch_simulation
restart
open_vcd
log_vcd *
run all
flush_vcd
close_vcd
