-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi_fifo;
use axi_fifo.axi_fifo.all;
use axi_fifo.axi_fifo_tb_utils.all;

entity axi_fifo_packet_equiv_tb is
end axi_fifo_packet_equiv_tb;

architecture bhv of axi_fifo_packet_equiv_tb is

    constant c_width          : natural := 32;
    constant c_depth          : natural := 10;
    constant c_input_latency  : natural := 1;
    constant c_output_latency : natural := 2;
    constant c_num_cycles     : natural := 100000;

    -- DUT signals
    signal clk           : std_logic;
    signal rst           : std_logic;
    signal input_data    : std_logic_vector(c_width - 1 downto 0);
    signal input_valid   : std_logic;
    signal input_ready0  : std_logic;
    signal input_ready1  : std_logic;
    signal input_ready2  : std_logic;
    signal input_cancel  : std_logic;
    signal input_commit  : std_logic;
    signal output_data0  : std_logic_vector(c_width - 1 downto 0);
    signal output_data1  : std_logic_vector(c_width - 1 downto 0);
    signal output_data2  : std_logic_vector(c_width - 1 downto 0);
    signal output_valid0 : std_logic;
    signal output_valid1 : std_logic;
    signal output_valid2 : std_logic;
    signal output_ready  : std_logic;

    -- RAM signals
    signal write_enable  : std_logic;
    signal write_address : natural range 0 to c_depth - 1;
    signal write_data    : std_logic_vector(c_width - 1 downto 0);
    signal read_enable   : std_logic;
    signal read_address  : natural range 0 to c_depth - 1;
    signal read_data     : std_logic_vector(c_width - 1 downto 0);

    -- flag to stop clock
    signal run : boolean := true;

begin

    -- DUT
    inst_fifo0 : axi_fifo_packet_lut generic map (
        width => c_width,
        depth => c_depth
    ) port map (
        clk          => clk,
        rst          => rst,
        input_data   => input_data,
        input_valid  => input_valid,
        input_ready  => input_ready0,
        input_cancel => input_cancel,
        input_commit => input_commit,
        output_data  => output_data0,
        output_valid => output_valid0,
        output_ready => output_ready
    );

    inst_fifo1 : axi_fifo_packet_ram generic map (
        width => c_width,
        depth => c_depth
    ) port map (
        clk          => clk,
        rst          => rst,
        input_data   => input_data,
        input_valid  => input_valid,
        input_ready  => input_ready1,
        input_cancel => input_cancel,
        input_commit => input_commit,
        output_data  => output_data1,
        output_valid => output_valid1,
        output_ready => output_ready
    );

    inst_fifo2 : axi_fifo_packet_exram generic map (
        width       => c_width,
        depth       => c_depth,
        ram_latency => c_input_latency + c_output_latency + 1
    ) port map (
        clk           => clk,
        rst           => rst,
        input_data    => input_data,
        input_valid   => input_valid,
        input_ready   => input_ready2,
        input_cancel  => input_cancel,
        input_commit  => input_commit,
        output_data   => output_data2,
        output_valid  => output_valid2,
        output_ready  => output_ready,
        write_enable  => write_enable,
        write_address => write_address,
        write_data    => write_data,
        read_enable   => read_enable,
        read_address  => read_address,
        read_data     => read_data
    );

    inst_ram : ram_wrapper generic map (
        width          => c_width,
        depth          => c_depth,
        input_latency  => c_input_latency,
        output_latency => c_output_latency
    ) port map (
        clk           => clk,
        write_enable  => write_enable,
        write_address => write_address,
        write_data    => write_data,
        read_enable   => read_enable,
        read_address  => read_address,
        read_data     => read_data
    );

    -- clock process
    proc_clock: process
    begin
        while run loop
            clk <= '1';
            wait for 5 ns;
            clk <= '0';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    -- input process
    proc_input: process
        variable v_pcg32_state : unsigned(63 downto 0) := x"1829dd5c9ae30913";
        variable v_stutter : std_logic_vector(8 downto 0);
        variable v_data : std_logic_vector(c_width - 1 downto 0);
    begin
        wait until rising_edge(clk);
        rst <= '1';
        input_data <= (others => 'X');
        input_valid <= '0';
        wait until rising_edge(clk);
        rst <= '0';
        for i in 0 to c_num_cycles - 1 loop
            pcg32_random(v_pcg32_state, v_stutter);
            pcg32_random(v_pcg32_state, v_data);
            input_data <= v_data;
            input_valid <= v_stutter(0);
            input_cancel <= v_stutter(1) and v_stutter(2) and v_stutter(3);
            input_commit <= v_stutter(4) and v_stutter(5) and v_stutter(6);
            output_ready <= v_stutter(7) and v_stutter(8);
            wait until rising_edge(clk);
        end loop;
        wait;
    end process;

    -- output process
    proc_output: process
        variable v_num_passed : natural := 0;
    begin
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        for i in 0 to c_num_cycles - 1 loop
            wait until rising_edge(clk);
            if input_ready0 = input_ready1 then
                v_num_passed := v_num_passed + 1;
            else
                report "Mismatch between input_ready0 and input_ready1 for i=" & integer'image(i) severity warning;
            end if;
            if input_ready0 = input_ready2 then
                v_num_passed := v_num_passed + 1;
            else
                report "Mismatch between input_ready0 and input_ready2 for i=" & integer'image(i) severity warning;
            end if;
            if output_data0 = output_data1 or output_valid0 = '0' then
                v_num_passed := v_num_passed + 1;
            else
                report "Mismatch between output_data0 and output_data1 for i=" & integer'image(i) severity warning;
            end if;
            if output_data0 = output_data2 or output_valid0 = '0' then
                v_num_passed := v_num_passed + 1;
            else
                report "Mismatch between output_data0 and output_data2 for i=" & integer'image(i) severity warning;
            end if;
            if output_valid0 = output_valid1 then
                v_num_passed := v_num_passed + 1;
            else
                report "Mismatch between output_valid0 and output_valid1 for i=" & integer'image(i) severity warning;
            end if;
            if output_valid0 = output_valid2 then
                v_num_passed := v_num_passed + 1;
            else
                report "Mismatch between output_valid0 and output_valid2 for i=" & integer'image(i) severity warning;
            end if;
        end loop;
        report "axi_fifo_packet_equiv_tb result: " & integer'image(v_num_passed) &
            "/" & integer'image(6 * c_num_cycles) & " passed" severity note;
        run <= false;
        wait;
    end process;

end bhv;
