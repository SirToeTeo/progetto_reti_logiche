# Logic Circuits Project

[![VHDL](https://img.shields.io/badge/VHDL-93C572?style=for-the-badge&logo=vhdl&logoColor=black)](https://vhdl.com)
[![FPGA](https://img.shields.io/badge/FPGA-F7DF1E?style=for-the-badge&logo=xilinx&logoColor=black)](https://www.xilinx.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Hardware module implementing a configurable **FIR (Finite Impulse Response) filter** in VHDL. Reads 8-bit data from memory, applies either 3-tap or 5-tap differential filtering with runtime coefficients, and writes saturated results back to memory. Complete course project with specification and 14-page technical report (Italian).

## Documentation

[![Technical Report](https://img.shields.io/badge/Report-PDF-blue?style=for-the-badge&logo=adobeacrobat&logoColor=white)](https://github.com/SirToeTeo/progetto_reti_logiche/blob/main/Relazione%20Reti%20Logiche.pdf)
[![Specification](https://img.shields.io/badge/Spec-PDF-orange?style=for-the-badge&logo=adobeacrobat&logoColor=white)](https://github.com/SirToeTeo/progetto_reti_logiche/blob/main/PFRL_Specifica_24_25%2020250212%20v3.5.1.pdf)

**Technical report includes**:
- Mathematical formulation and normalization analysis
- Complete state machine diagrams with transitions
- Memory access pattern optimization
- Edge case handling (zero-padding, boundary conditions)
- Testbench verification strategy
- Synthesis results and resource utilization
- Timing diagrams and waveform screenshots
