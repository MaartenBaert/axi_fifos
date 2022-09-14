-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi_fifo;
use axi_fifo.axi_fifo.all;
use axi_fifo.axi_fifo_tb_utils.all;

entity axi_fifo_packet_exram_tb is
end axi_fifo_packet_exram_tb;

architecture bhv of axi_fifo_packet_exram_tb is

    constant c_width          : natural := 32;
    constant c_depth          : natural := 10;
    constant c_input_latency  : natural := 1;
    constant c_output_latency : natural := 2;
    constant c_num_packets    : natural := 5000;

    -- DUT signals
    signal clk          : std_logic;
    signal rst          : std_logic;
    signal input_data   : std_logic_vector(c_width - 1 downto 0);
    signal input_valid  : std_logic;
    signal input_ready  : std_logic;
    signal input_cancel : std_logic;
    signal input_commit : std_logic;
    signal output_data  : std_logic_vector(c_width - 1 downto 0);
    signal output_valid : std_logic;
    signal output_ready : std_logic;

    -- RAM signals
    signal write_enable  : std_logic;
    signal write_address : natural range 0 to c_depth - 1;
    signal write_data    : std_logic_vector(c_width - 1 downto 0);
    signal read_enable   : std_logic;
    signal read_address  : natural range 0 to c_depth - 1;
    signal read_data     : std_logic_vector(c_width - 1 downto 0);

    -- flag to stop clock
    signal run : boolean := true;

    -- randomly generated stutter control signal
    -- bit 0 = fifo input
    -- bit 1 = fifo output
    signal stutter : std_logic_vector(1 downto 0);

begin

    -- DUT
    inst_fifo : axi_fifo_packet_exram generic map (
        width       => c_width,
        depth       => c_depth,
        ram_latency => c_input_latency + c_output_latency + 1
    ) port map (
        clk           => clk,
        rst           => rst,
        input_data    => input_data,
        input_valid   => input_valid,
        input_ready   => input_ready,
        input_cancel  => input_cancel,
        input_commit  => input_commit,
        output_data   => output_data,
        output_valid  => output_valid,
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
        variable v_pcg32_state_real : unsigned(63 downto 0) := x"c4703c5c2114ac3a";
        variable v_pcg32_state_dummy : unsigned(63 downto 0) := x"5b13b1e7b2b0f84d";
        variable v_data : std_logic_vector(c_width - 1 downto 0);
        variable v_packet_size : natural range 0 to c_depth;
        variable v_select_packet : natural range 0 to 3;
        variable v_delayed_cancel : boolean;
        variable v_select_commit : natural range 0 to 1;
        variable v_select_cancel : natural range 0 to 1;
    begin
        wait until rising_edge(clk);
        rst <= '1';
        input_data <= (others => 'X');
        input_valid <= '0';
        input_cancel <= '0';
        input_commit <= '0';
        wait until rising_edge(clk);
        rst <= '0';
        v_delayed_cancel := false;
        for i in 0 to c_num_packets - 1 loop

            -- choose a random packet size, and whether it is a real or dummy packet
            pcg32_random(v_pcg32_state, v_packet_size, 0, c_depth);
            pcg32_random(v_pcg32_state, v_select_packet, 0, 3);

            --report "[IN] i=" & integer'image(i) & ", v_packet_size=" & integer'image(v_packet_size) & ", v_select_packet=" & integer'image(v_select_packet) severity note;

            if v_select_packet = 0 then
                v_select_commit := 0;
            else
                pcg32_random(v_pcg32_state_dummy, v_select_commit, 0, 1);
            end if;

            -- send the packet
            for j in 0 to v_packet_size - 1 loop
                while stutter(0) = '0' loop
                    wait until rising_edge(clk);
                end loop;
                if v_select_packet = 0 then
                    pcg32_random(v_pcg32_state_dummy, v_data);
                else
                    pcg32_random(v_pcg32_state_real, v_data);
                end if;
                --report "[IN] i=" & integer'image(i) & ", j=" & integer'image(j) & ", data=" & to_hex_string(v_data) severity note;
                input_data <= v_data;
                input_valid <= '1';
                if v_delayed_cancel and j = 0 then
                    input_cancel <= '1';
                    v_delayed_cancel := false;
                end if;
                if v_select_commit = 1 and j = v_packet_size - 1 then
                    input_commit <= '1';
                end if;
                wait until rising_edge(clk);
                while input_ready = '0' loop
                    wait until rising_edge(clk);
                end loop;
                input_data <= (others => 'X');
                input_valid <= '0';
                input_cancel <= '0';
                input_commit <= '0';
            end loop;

            if v_select_packet = 0 then

                -- cancel the packet
                pcg32_random(v_pcg32_state_dummy, v_select_cancel, 0, 1);
                if v_select_cancel = 0 then
                    input_cancel <= '1';
                    wait until rising_edge(clk);
                    input_cancel <= '0';
                else
                    v_delayed_cancel := true;
                end if;

            else

                -- commit the packet
                if v_select_commit = 0 then
                    if v_delayed_cancel then
                        input_cancel <= '1';
                        v_delayed_cancel := false;
                    end if;
                    input_commit <= '1';
                    wait until rising_edge(clk);
                    input_cancel <= '0';
                    input_commit <= '0';
                end if;

            end if;

        end loop;
        wait;
    end process;

    -- output process
    proc_output: process
        variable v_pcg32_state : unsigned(63 downto 0) := x"25bba36c40fa404c";
        variable v_pcg32_state_real : unsigned(63 downto 0) := x"c4703c5c2114ac3a";
        variable v_data : std_logic_vector(c_width - 1 downto 0);
        variable v_packet_size : natural range 0 to c_depth;
        variable v_select_packet : natural range 0 to 3;
        variable v_num_passed : natural := 0;
        variable v_num_total : natural := 0;
    begin
        wait until rising_edge(clk);
        output_ready <= '0';
        wait until rising_edge(clk);
        for i in 0 to c_num_packets - 1 loop

            -- choose a random packet size, and whether it is a real or dummy packet
            pcg32_random(v_pcg32_state, v_packet_size, 0, c_depth);
            pcg32_random(v_pcg32_state, v_select_packet, 0, 3);

            --report "[OUT] i=" & integer'image(i) & ", v_packet_size=" & integer'image(v_packet_size) & ", v_select_packet=" & integer'image(v_select_packet) severity note;

            -- receive the packet
            if v_select_packet /= 0 then
                for j in 0 to v_packet_size - 1 loop
                    while stutter(1) = '0' loop
                        wait until rising_edge(clk);
                    end loop;
                    output_ready <= '1';
                    wait until rising_edge(clk);
                    while output_valid = '0' loop
                        wait until rising_edge(clk);
                    end loop;
                    output_ready <= '0';
                    pcg32_random(v_pcg32_state_real, v_data);
                    --report "[OUT] i=" & integer'image(i) & ", j=" & integer'image(j) & ", data=" & to_hex_string(v_data) severity note;
                    if output_data = v_data then
                        v_num_passed := v_num_passed + 1;
                    else
                        report "Incorrect data for i=" & integer'image(i) & ", j=" & integer'image(j) severity warning;
                    end if;
                    v_num_total := v_num_total + 1;
                end loop;
            end if;

        end loop;
        report "axi_fifo_packet_exram_tb result: " & integer'image(v_num_passed) &
            "/" & integer'image(v_num_total) & " passed" severity note;
        run <= false;
        wait;
    end process;

end bhv;
