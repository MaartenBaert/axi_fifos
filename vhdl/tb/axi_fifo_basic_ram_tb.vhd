-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi_fifo;
use axi_fifo.axi_fifo.all;
use axi_fifo.axi_fifo_tb_utils.all;

entity axi_fifo_basic_ram_tb is
end axi_fifo_basic_ram_tb;

architecture bhv of axi_fifo_basic_ram_tb is

    constant c_width      : natural := 32;
    constant c_depth      : natural := 10;
    constant c_num_cycles : natural := 1000;

    -- DUT signals
    signal clk          : std_logic;
    signal rst          : std_logic;
    signal input_data   : std_logic_vector(c_width - 1 downto 0);
    signal input_valid  : std_logic;
    signal input_ready  : std_logic;
    signal output_data  : std_logic_vector(c_width - 1 downto 0);
    signal output_valid : std_logic;
    signal output_ready : std_logic;

    -- flag to stop clock
    signal run : boolean := true;

    -- randomly generated stutter control signal
    -- bit 0 = fifo input
    -- bit 1 = fifo output
    signal stutter : std_logic_vector(1 downto 0);

begin

    -- DUT
    inst_fifo : axi_fifo_basic_ram generic map (
        width => c_width,
        depth => c_depth
    ) port map (
        clk          => clk,
        rst          => rst,
        input_data   => input_data,
        input_valid  => input_valid,
        input_ready  => input_ready,
        output_data  => output_data,
        output_valid => output_valid,
        output_ready => output_ready
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

    -- stutter control signal process
    proc_stutter: process(clk)
        variable v_pcg32_state : unsigned(63 downto 0) := x"34caf41c91e66374";
        variable v_stutter : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            pcg32_random(v_pcg32_state, v_stutter);
            stutter <= v_stutter;
        end if;
    end process;

    -- input process
    proc_input: process
        variable v_pcg32_state : unsigned(63 downto 0) := x"25bba36c40fa404c";
        variable v_data : std_logic_vector(c_width - 1 downto 0);
    begin
        wait until rising_edge(clk);
        rst <= '1';
        input_data <= (others => 'X');
        input_valid <= '0';
        wait until rising_edge(clk);
        rst <= '0';
        for i in 0 to c_num_cycles - 1 loop
            while stutter(0) = '0' loop
                wait until rising_edge(clk);
            end loop;
            pcg32_random(v_pcg32_state, v_data);
            input_data <= v_data;
            input_valid <= '1';
            wait until rising_edge(clk);
            while input_ready = '0' loop
                wait until rising_edge(clk);
            end loop;
            input_data <= (others => 'X');
            input_valid <= '0';
        end loop;
        wait;
    end process;

    -- output process
    proc_output: process
        variable v_pcg32_state : unsigned(63 downto 0) := x"25bba36c40fa404c";
        variable v_data : std_logic_vector(c_width - 1 downto 0);
        variable v_num_passed : natural := 0;
    begin
        wait until rising_edge(clk);
        output_ready <= '0';
        wait until rising_edge(clk);
        for i in 0 to c_num_cycles - 1 loop
            while stutter(1) = '0' loop
                wait until rising_edge(clk);
            end loop;
            output_ready <= '1';
            wait until rising_edge(clk);
            while output_valid = '0' loop
                wait until rising_edge(clk);
            end loop;
            output_ready <= '0';
            pcg32_random(v_pcg32_state, v_data);
            if output_data = v_data then
                v_num_passed := v_num_passed + 1;
            else
                report "Incorrect data for i=" & integer'image(i) severity warning;
            end if;
        end loop;
        report "axi_fifo_basic_ram_tb result: " & integer'image(v_num_passed) &
            "/" & integer'image(c_num_cycles) & " passed" severity note;
        run <= false;
        wait;
    end process;

end bhv;
