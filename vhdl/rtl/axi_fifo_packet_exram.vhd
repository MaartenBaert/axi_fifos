-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;

entity axi_fifo_packet_exram is
    generic(
        width       : natural := 8;
        depth       : natural := 64;
        ram_latency : natural := 1
    );
    port(

        -- clock and synchronous reset
        clk           : in std_logic;
        rst           : in std_logic;

        -- input (push) side
        input_data    : in  std_logic_vector(width - 1 downto 0);
        input_valid   : in  std_logic;
        input_ready   : out std_logic;
        input_cancel : in  std_logic;
        input_commit : in  std_logic;

        -- output (pop) side
        output_data   : out std_logic_vector(width - 1 downto 0);
        output_valid  : out std_logic;
        output_ready  : in  std_logic;

        -- RAM interface
        write_enable  : out std_logic;
        write_address : out natural range 0 to depth - 1;
        write_data    : out std_logic_vector(width - 1 downto 0);
        read_enable   : out std_logic;
        read_address  : out natural range 0 to depth - 1;
        read_data     : in  std_logic_vector(width - 1 downto 0)

    );
end axi_fifo_packet_exram;

architecture rtl of axi_fifo_packet_exram is

    function bool_to_logic(x : boolean) return std_logic is
    begin
        if x then
            return '1';
        else
            return '0';
        end if;
    end bool_to_logic;

    constant c_bypass_depth : natural := ram_latency + 1;

    -- delay lines that match RAM latency
    signal r_fetch_enable_dl  : std_logic_vector(0 to ram_latency - 1);
    signal r_fetch_commit_dl   : std_logic_vector(0 to ram_latency - 1);
    signal r_fetch_write_dl : std_logic_vector(0 to ram_latency - 1);

    -- bypass memory that holds the output data
    type bypass_memory_t is array(0 to c_bypass_depth - 1) of std_logic_vector(width - 1 downto 0);
    signal r_bypass_memory : bypass_memory_t;
    attribute RAM_STYLE : string;
    attribute RAM_STYLE of r_bypass_memory : signal is "LUTRAM";

    -- bypass read and write positions
    signal r_bypass_write_pos  : natural range 0 to c_bypass_depth - 1;
    signal r_bypass_commit_pos : natural range 0 to c_bypass_depth - 1;
    signal r_bypass_fetch_pos  : natural range 0 to c_bypass_depth - 1;
    signal r_bypass_read_pos   : natural range 0 to c_bypass_depth - 1;

    -- main read and write positions
    signal r_read_pos       : natural range 0 to depth - 1;
    signal r_write_pos      : natural range 0 to depth - 1;
    signal r_commit_pos     : natural range 0 to depth - 1;
    signal r_write_wrapped  : std_logic;
    signal r_commit_wrapped : std_logic;

    -- write position with cancellation taken into accound
    signal s_write_pos_cancelled     : natural range 0 to depth - 1;
    signal s_write_wrapped_cancelled : std_logic;

    -- fetch position and fill level
    signal s_fetch_pos           : natural range 0 to depth - 1;
    --signal s_fill_level          : integer;--natural range 0 to depth;
    signal s_fill_level_write    : natural range 0 to depth;
    signal s_fill_level_commit   : natural range 0 to depth;
    signal s_fill_level          : natural range 0 to depth;

    -- full and empty flags
    signal s_full  : std_logic;
    signal s_empty : std_logic;

begin

    -- generate incremented positions (combinatorially)
    s_write_pos_cancelled <= r_commit_pos when input_cancel = '1' else r_write_pos;
    s_write_wrapped_cancelled <= r_commit_wrapped when input_cancel = '1' else r_write_wrapped;
    s_fetch_pos <= r_read_pos + c_bypass_depth - depth when r_read_pos + c_bypass_depth >= depth else r_read_pos + c_bypass_depth;
    --s_fill_level <= depth + s_write_pos_cancelled - r_read_pos when s_write_wrapped_cancelled = '1' else s_write_pos_cancelled - r_read_pos;
    s_fill_level_write <= depth + r_write_pos - r_read_pos when r_write_wrapped = '1' else r_write_pos - r_read_pos;
    s_fill_level_commit <= depth + r_commit_pos - r_read_pos when r_commit_wrapped = '1' else r_commit_pos - r_read_pos;
    s_fill_level <= s_fill_level_commit when input_cancel = '1' else s_fill_level_write;

    -- generate full and empty flags (combinatorially)
    s_full <= '1' when r_read_pos = r_write_pos and r_write_wrapped = '1' else '0';
    s_empty <= '1' when r_read_pos = r_commit_pos and r_commit_wrapped = '0' else '0';

    -- generate outputs based on flags
    input_ready <= not s_full;
    output_data <= r_bypass_memory(r_bypass_read_pos);
    output_valid <= not s_empty;

    -- RAM interface
    write_enable <= input_valid and not s_full;
    write_address <= s_write_pos_cancelled;
    write_data <= input_data;
    read_enable <= output_ready and not s_empty;
    read_address <= s_fetch_pos;

    -- start of fetch delay line
    -- r_fetch_enable_dl(0) <= output_ready and not s_empty;
    -- r_fetch_commit_dl(0) <= '1' when s_fill_level_commit > c_bypass_depth else '0';
    -- r_fetch_write_dl(0) <= '1' when s_fill_level_write > c_bypass_depth else '0';

    process(clk)
        variable v_fetch_enable_dl   : std_logic_vector(0 to ram_latency);
        variable v_fetch_commit_dl   : std_logic_vector(0 to ram_latency);
        variable v_fetch_write_dl    : std_logic_vector(0 to ram_latency);
        variable v_bypass_write_pos  : natural range 0 to c_bypass_depth - 1;
        variable v_bypass_commit_pos : natural range 0 to c_bypass_depth - 1;
        variable v_write_pos         : natural range 0 to depth - 1;
        variable v_commit_pos        : natural range 0 to depth - 1;
        variable v_write_wrapped     : std_logic;
        variable v_commit_wrapped    : std_logic;
        variable v_fill_level_adj    : integer;--natural range 0 to depth;
    begin
        if rising_edge(clk) then
            if rst = '1' then

                -- reset fetch delay line
                r_fetch_enable_dl <= (others => '0');
                r_fetch_commit_dl <= (others => '0');
                r_fetch_write_dl <= (others => '0');

                -- reset bypass control registers
                r_bypass_write_pos <= 0;
                r_bypass_fetch_pos <= 0;
                r_bypass_read_pos <= 0;

                -- reset main control registers
                r_read_pos <= 0;
                r_write_pos <= 0;
                r_commit_pos <= 0;
                r_write_wrapped <= '0';
                r_commit_wrapped <= '0';

            else

                -- copy registers into variables
                v_bypass_write_pos := r_bypass_write_pos;
                v_bypass_commit_pos := r_bypass_commit_pos;
                v_write_pos := r_write_pos;
                v_commit_pos := r_commit_pos;
                v_write_wrapped := r_write_wrapped;
                v_commit_wrapped := r_commit_wrapped;

                -- update fetch delay line
                v_fetch_enable_dl := (output_ready and not s_empty) & r_fetch_enable_dl;
                v_fetch_commit_dl := bool_to_logic(s_fill_level_commit > c_bypass_depth) & r_fetch_commit_dl;
                v_fetch_write_dl := bool_to_logic(s_fill_level_write > c_bypass_depth) & r_fetch_write_dl;

                -- push
                if input_cancel = '1' then
                    v_fetch_write_dl := v_fetch_commit_dl;
                    v_bypass_write_pos := v_bypass_commit_pos;
                    v_write_pos := v_commit_pos;
                    v_write_wrapped := v_commit_wrapped;
                end if;
                if input_valid = '1' and s_full = '0' then
                    if output_ready = '1' and s_empty = '0' then
                        v_fill_level_adj := s_fill_level - 1;
                    else
                        v_fill_level_adj := s_fill_level;
                    end if;
                    if v_fill_level_adj < c_bypass_depth then
                        r_bypass_memory(v_bypass_write_pos) <= input_data;
                    end if;
                    if v_bypass_write_pos = c_bypass_depth - 1 then
                        v_bypass_write_pos := 0;
                    else
                        v_bypass_write_pos := v_bypass_write_pos + 1;
                    end if;
                    if v_write_pos = depth - 1 then
                        v_write_pos := 0;
                        v_write_wrapped := '1';
                    else
                        v_write_pos := v_write_pos + 1;
                    end if;
                end if;
                if input_commit = '1' then
                    v_fetch_commit_dl := v_fetch_write_dl;
                    v_bypass_commit_pos := v_bypass_write_pos;
                    v_commit_pos := v_write_pos;
                    v_commit_wrapped := v_write_wrapped;
                end if;

                -- fetch
                if v_fetch_enable_dl(ram_latency) = '1' then
                    if v_fetch_write_dl(ram_latency) = '1' then
                        r_bypass_memory(r_bypass_fetch_pos) <= read_data;
                    end if;
                    if r_bypass_fetch_pos = c_bypass_depth - 1 then
                        r_bypass_fetch_pos <= 0;
                    else
                        r_bypass_fetch_pos <= r_bypass_fetch_pos + 1;
                    end if;
                end if;

                -- pop
                if output_ready = '1' and s_empty = '0' then
                    if r_bypass_read_pos = c_bypass_depth - 1 then
                        r_bypass_read_pos <= 0;
                    else
                        r_bypass_read_pos <= r_bypass_read_pos + 1;
                    end if;
                    if r_read_pos = depth - 1 then
                        r_read_pos <= 0;
                        v_write_wrapped := '0';
                        v_commit_wrapped := '0';
                    else
                        r_read_pos <= r_read_pos + 1;
                    end if;
                end if;

                -- copy variables back into registers
                r_fetch_enable_dl <= v_fetch_enable_dl(0 to ram_latency - 1);
                r_fetch_commit_dl <= v_fetch_commit_dl(0 to ram_latency - 1);
                r_fetch_write_dl <= v_fetch_write_dl(0 to ram_latency - 1);
                r_bypass_write_pos <= v_bypass_write_pos;
                r_bypass_commit_pos <= v_bypass_commit_pos;
                r_write_pos <= v_write_pos;
                r_commit_pos <= v_commit_pos;
                r_write_wrapped <= v_write_wrapped;
                r_commit_wrapped <= v_commit_wrapped;

            end if;
        end if;
    end process;

end rtl;
