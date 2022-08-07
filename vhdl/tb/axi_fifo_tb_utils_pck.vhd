library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi_fifo;
use axi_fifo.axi_fifo.all;

package axi_fifo_tb_utils is

    -- PCG32 RNG for randomization
    procedure pcg32_random(
        state : inout unsigned(63 downto 0);
        output : out std_logic_vector
    );
    procedure pcg32_random(
        state : inout unsigned(63 downto 0);
        output : out integer;
        low : in integer;
        high : in integer
    );

end axi_fifo_tb_utils;

package body axi_fifo_tb_utils is

    procedure pcg32_random(
        state : inout unsigned(63 downto 0);
        output : out std_logic_vector
    ) is
        variable xorshifted : unsigned(63 downto 0);
        variable rot : unsigned(4 downto 0);
        variable temp : std_logic_vector(31 downto 0);
    begin
        xorshifted := shift_right(shift_right(state, 18) xor state, 27);
        rot := state(63 downto 59);
        temp := std_logic_vector(rotate_right(xorshifted(31 downto 0),
            to_integer(rot)));
        output := temp(output'length - 1 downto 0);
        state := resize(state * unsigned'(x"5851f42d4c957f2d"), 64)
            + unsigned'(x"14057b7ef767814f");
    end pcg32_random;

    procedure pcg32_random(
        state : inout unsigned(63 downto 0);
        output : out integer;
        low : in integer;
        high : in integer
    ) is
        variable temp : std_logic_vector(31 downto 0);
    begin
        pcg32_random(state, temp);
        output := low + to_integer(resize(shift_right(unsigned(temp) *
            to_unsigned(high - low + 1, 32), 32), 32));
    end pcg32_random;

end axi_fifo_tb_utils;
