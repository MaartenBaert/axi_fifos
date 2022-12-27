-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;

entity ram_wrapper is
    generic(
        width          : natural := 8;
        depth          : natural := 64;
        input_latency  : natural := 0;
        output_latency : natural := 0
    );
    port(

        -- clock
        clk           : in std_logic;

        -- RAM interface
        write_enable  : in  std_logic;
        write_address : in  natural range 0 to depth - 1;
        write_data    : in  std_logic_vector(width - 1 downto 0);
        read_enable   : in  std_logic;
        read_address  : in  natural range 0 to depth - 1;
        read_data     : out std_logic_vector(width - 1 downto 0)

    );
end ram_wrapper;

architecture rtl of ram_wrapper is

    -- memory that holds the data
    type memory_t is array(0 to depth - 1) of std_logic_vector(width - 1 downto 0);
    signal r_memory : memory_t;
    attribute RAM_STYLE : string;
    attribute RAM_STYLE of r_memory : signal is "block";

    -- delay lines
    type enable_array_t is array(integer range <>) of std_logic;
    type address_array_t is array(integer range <>) of natural range 0 to depth - 1;
    type data_array_t is array(integer range <>) of std_logic_vector(width - 1 downto 0);
    signal r_write_enable_dl  : enable_array_t(0 to input_latency);
    signal r_write_address_dl : address_array_t(0 to input_latency);
    signal r_write_data_dl    : data_array_t(0 to input_latency);
    signal r_read_enable_dl   : enable_array_t(0 to input_latency);
    signal r_read_address_dl  : address_array_t(0 to input_latency);
    signal r_read_data_dl     : data_array_t(0 to output_latency);

begin

    -- start of input delay lines
    r_write_enable_dl(0)  <= write_enable;
    r_write_address_dl(0) <= write_address;
    r_write_data_dl(0)    <= write_data;
    r_read_enable_dl(0)  <= read_enable;
    r_read_address_dl(0) <= read_address;

    -- end of output delay line
    read_data <= r_read_data_dl(output_latency);

    process(clk)
    begin
        if rising_edge(clk) then

            -- input delay line
            r_write_enable_dl(1 to input_latency)  <= r_write_enable_dl(0 to input_latency - 1);
            r_write_address_dl(1 to input_latency) <= r_write_address_dl(0 to input_latency - 1);
            r_write_data_dl(1 to input_latency)    <= r_write_data_dl(0 to input_latency - 1);
            r_read_enable_dl(1 to input_latency)   <= r_read_enable_dl(0 to input_latency - 1);
            r_read_address_dl(1 to input_latency)  <= r_read_address_dl(0 to input_latency - 1);

            -- memory write
            if r_write_enable_dl(input_latency) = '1' then
                r_memory(r_write_address_dl(input_latency)) <= r_write_data_dl(input_latency);
            end if;

            -- memory read
            if r_read_enable_dl(input_latency) = '1' then
                r_read_data_dl(0) <= r_memory(r_read_address_dl(input_latency));
            end if;

            -- output delay line
            r_read_data_dl(1 to output_latency) <= r_read_data_dl(0 to output_latency - 1);

        end if;
    end process;

end rtl;
