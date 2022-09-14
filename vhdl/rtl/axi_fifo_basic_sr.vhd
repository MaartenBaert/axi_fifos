-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;

entity axi_fifo_basic_sr is
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

        -- output (pop) side
        output_data  : out std_logic_vector(width - 1 downto 0);
        output_valid : out std_logic;
        output_ready : in  std_logic

    );
end axi_fifo_basic_sr;

architecture rtl of axi_fifo_basic_sr is

    -- memory that holds the data
    type memory_t is array(0 to depth - 1) of std_logic_vector(width - 1 downto 0);
    signal r_memory : memory_t;

    -- read position
    signal r_read_pos : natural range 0 to depth;

    -- full and empty flags
    signal s_full  : std_logic;
    signal s_empty : std_logic;

begin

    -- generate full and empty flags (combinatorially)
    s_full <= '1' when r_read_pos = 0 else '0';
    s_empty <= '1' when r_read_pos = depth else '0';

    -- generate outputs based on flags
    input_ready <= not s_full;
    output_data <= r_memory(r_read_pos mod depth);
    output_valid <= not s_empty;

    process(clk)
        variable v_push : boolean;
        variable v_pop : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then

                -- reset control registers
                r_read_pos <= depth;

            else

                -- generate push and pop flags
                v_push := (input_valid = '1' and s_full = '0');
                v_pop := (output_ready = '1' and s_empty = '0');

                -- update read pos
                if v_push and not v_pop then
                    r_read_pos <= r_read_pos - 1;
                end if;
                if v_pop and not v_push then
                    r_read_pos <= r_read_pos + 1;
                end if;

                -- push to memory
                if v_push then
                    r_memory <= r_memory(1 to depth - 1) & input_data;
                end if;

            end if;
        end if;
    end process;

end rtl;
