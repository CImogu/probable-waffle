-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2023.1 (lin64) Build 3865809 Sun May  7 15:04:56 MDT 2023
-- Date        : Thu Dec 14 14:22:59 2023
-- Host        : eecs-digital-34 running 64-bit Ubuntu 22.04.3 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/ccimogu/Downloads/fp/ip/adder_many/ip/adder_many/adder_many_stub.vhdl
-- Design      : adder_many
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7s50csga324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity adder_many is
  Port ( 
    aclk : in STD_LOGIC;
    s_axis_a_tvalid : in STD_LOGIC;
    s_axis_a_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_a_tuser : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_a_tlast : in STD_LOGIC;
    s_axis_b_tvalid : in STD_LOGIC;
    s_axis_b_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    m_axis_result_tvalid : out STD_LOGIC;
    m_axis_result_tdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    m_axis_result_tuser : out STD_LOGIC_VECTOR ( 31 downto 0 );
    m_axis_result_tlast : out STD_LOGIC
  );

end adder_many;

architecture stub of adder_many is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "aclk,s_axis_a_tvalid,s_axis_a_tdata[31:0],s_axis_a_tuser[31:0],s_axis_a_tlast,s_axis_b_tvalid,s_axis_b_tdata[31:0],m_axis_result_tvalid,m_axis_result_tdata[31:0],m_axis_result_tuser[31:0],m_axis_result_tlast";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "floating_point_v7_1_15,Vivado 2023.1";
begin
end;
