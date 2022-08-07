#!/bin/bash

set -e
cd "$( dirname "${BASH_SOURCE[0]}" )"

rm -rf build-tb
mkdir -p build-tb
cd build-tb

WORK="axi_fifo"
RTLFILES=(
    "axi_fifo_pck"
    "axi_fifo_basic_lut"
    "axi_fifo_basic_sr"
    "axi_fifo_basic_ram"
    "axi_fifo_packet_lut"
    "axi_fifo_packet_ram"
)
TBFILES=(
    "axi_fifo_tb_utils_pck"
)
TESTBENCHES=(
    "axi_fifo_basic_lut_tb"
    "axi_fifo_basic_sr_tb"
    "axi_fifo_basic_ram_tb"
    "axi_fifo_packet_lut_tb"
    "axi_fifo_packet_ram_tb"
)

echo "Processing RTL files ..."

for FILE in "${RTLFILES[@]}"; do

    echo "- Compiling ${FILE} ..."
    ghdl -a --work=${WORK} ../rtl/${FILE}.vhd

done

echo "Processing TB files ..."

for FILE in "${TBFILES[@]}"; do

    echo "- Compiling ${FILE} ..."
    ghdl -a --work=${WORK} ../tb/${FILE}.vhd

done

echo "Processing testbenches ..."

for FILE in "${TESTBENCHES[@]}"; do

    echo "- Compiling ${FILE} ..."
    ghdl -a --work=${WORK} ../tb/${FILE}.vhd
    ghdl -e --work=${WORK} ${FILE}

    echo "- Running ${FILE} ..."
    ./${FILE} --wave=${FILE}.ghw

done
