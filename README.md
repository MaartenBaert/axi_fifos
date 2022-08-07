AXI FIFOs
=========

This repository contains a collection of FIFOs with an AXI handshake as input and output. This makes them convenient for use in AXI-style pipelines. Functionally these FIFOs are equivalent to standard first-word-fallthrough (FWFT) FIFOs that tolerate overflow/underflow (meaning push commands are ignored if the FIFO is already full, and pop commands are ignored if the FIFO is already empty).

The FIFOs are all implemented in standard VHDL, but written in such a way that Xilinx tools are able to infer efficient memory primitives, such as LUT-based RAMs, shift registers and block RAMs.

FIFOs
-----

| Module name         | Memory type              | Extra features |
| ------------------- | ------------------------ | -------------- |
| axi_fifo_basic_lut  | LUT-based RAM            | -              |
| axi_fifo_basic_sr   | LUT-based shift register | -              |
| axi_fifo_basic_ram  | Block RAM                | -              |
| axi_fifo_packet_lut | LUT-based RAM            | commit/cancel  |
| axi_fifo_packet_ram | Block RAM                | commit/cancel  |

Commit/cancel (packet FIFOs)
----------------------------

In addition to basic FIFOs, this repository also contains packet FIFOs which provide the ability to commit or cancel incoming packets that have been (partially or completely) pushed into the FIFO. This functionality is convenient for handling things like checksum errors, which can often only be detected after the whole packet has been processed, and require that the invalid packet is discarded. Data can't be popped from the FIFO until it has been committed.

The commit and cancel commands are processed independently of the input valid and ready flags which control the push functionality. A commit or cancel can be triggered either in a separate cycle when no data is provided, or they can be provided in parallel with data. When several commands are issued in the same cycle, they are processed in the following order: cancel, push, commit. I.e. it is possible to cancel a previous packet, push the first word of the next packet, and then commit this new packet, all in a single cycle. This order provides maximum flexibility to the user, and is compatible with the practice of using first/last flags to mark the start and end of packets respectively: the first flag can be tied to the cancel input, and the last flag to the commit input.

License
-------

The code in this repository is available under the MIT License (see `LICENSE.txt`). This is a permissive licenses which permits commercial use.
