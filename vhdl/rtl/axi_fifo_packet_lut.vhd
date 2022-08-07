-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;

entity axi_fifo_packet_lut is
    generic(
        width : natural := 8;
        depth : natural := 64
    );
    port(

        -- clock and synchronous reset
        clk          : in std_logic;
        rst          : in std_logic;

        -- input (push) side
        input_data   : in  std_logic_vector(width - 1 downto 0);
        input_valid  : in  std_logic;
        input_ready  : out std_logic;
        input_cancel : in  std_logic;
        input_commit : in  std_logic;

        -- output (pop) side
        output_data  : out std_logic_vector(width - 1 downto 0);
        output_valid : out std_logic;
        output_ready : in  std_logic

    );
end axi_fifo_packet_lut;

architecture rtl of axi_fifo_packet_lut is

    -- memory that holds the data
    type memory_t is array(0 to depth - 1) of std_logic_vector(width - 1 downto 0);
    signal r_memory : memory_t;

    -- read and write positions
    signal r_read_pos       : natural range 0 to depth - 1;
    signal r_write_pos      : natural range 0 to depth - 1;
    signal r_commit_pos     : natural range 0 to depth - 1;
    signal r_write_wrapped  : std_logic;
    signal r_commit_wrapped : std_logic;

    -- full and empty flags
    signal s_full  : std_logic;
    signal s_empty : std_logic;

begin

    -- generate full and empty flags (combinatorially)
    s_full <= '1' when r_read_pos = r_write_pos and r_write_wrapped = '1' else '0';
    s_empty <= '1' when r_read_pos = r_commit_pos and r_commit_wrapped = '0' else '0';

    -- generate outputs based on flags
    input_ready <= not s_full;
    output_data <= r_memory(r_read_pos);
    output_valid <= not s_empty;

    process(clk)
        variable v_write_pos     : natural range 0 to depth - 1;
        variable v_write_wrapped : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then

                -- reset control registers
                r_read_pos <= 0;
                r_write_pos <= 0;
                r_commit_pos <= 0;
                r_write_wrapped <= '0';
                r_commit_wrapped <= '0';

            else

                v_write_pos := r_write_pos;
                v_write_wrapped := r_write_wrapped;

                -- push
                if input_cancel = '1' then
                    v_write_pos := r_commit_pos;
                    v_write_wrapped := r_commit_wrapped;
                end if;
                if input_valid = '1' and s_full = '0' then
                    r_memory(v_write_pos) <= input_data;
                    if v_write_pos = depth - 1 then
                        v_write_pos := 0;
                        v_write_wrapped := '1';
                    else
                        v_write_pos := v_write_pos + 1;
                    end if;
                end if;
                if input_commit = '1' then
                    r_commit_pos <= v_write_pos;
                    r_commit_wrapped <= v_write_wrapped;
                end if;

                -- pop
                if output_ready = '1' and s_empty = '0' then
                    if r_read_pos = depth - 1 then
                        r_read_pos <= 0;
                        v_write_wrapped := '0';
                        r_commit_wrapped <= '0';
                    else
                        r_read_pos <= r_read_pos + 1;
                    end if;
                end if;

                r_write_pos <= v_write_pos;
                r_write_wrapped <= v_write_wrapped;

            end if;
        end if;
    end process;

end rtl;
