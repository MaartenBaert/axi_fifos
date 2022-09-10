-- Copyright (c) 2022 Maarten Baert <info@maartenbaert.be>
-- Available under the MIT License - see LICENSE.txt for details.

library ieee;
use ieee.std_logic_1164.all;

package axi_fifo is

    component axi_fifo_basic_lut is
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
    end component;

    component axi_fifo_basic_sr is
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
    end component;

    component axi_fifo_basic_ram is
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
    end component;

    component axi_fifo_basic_exram is
        generic(
            width        : natural := 8;
            depth        : natural := 64;
            ram_latency  : natural := 1
        );
        port(

            -- clock and synchronous reset
            clk           : in std_logic;
            rst           : in std_logic;

            -- input (push) side
            input_data    : in  std_logic_vector(width - 1 downto 0);
            input_valid   : in  std_logic;
            input_ready   : out std_logic;

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
    end component;

    component axi_fifo_packet_lut is
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
    end component;

    component axi_fifo_packet_ram is
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
    end component;

    component ram_wrapper is
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
    end component;

end axi_fifo;
