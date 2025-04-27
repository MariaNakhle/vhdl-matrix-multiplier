# VHDL Matrix Multiplier - Final Project 🖩⚡

This repository contains my final project for the *Programmable Logic Devices* course at [Braude College]. The project demonstrates a fully functional **4×4 matrix multiplier** designed in VHDL, simulated in ModelSim, synthesized with Quartus Prime, and deployed on an Altera Cyclone V FPGA board.

---

## 📚 Project Overview

The system multiplies two signed 4×4 matrices and displays the resulting matrix on 7-segment displays. The design uses modular components, state machines, and efficient resource allocation.

---

## 🚦 Workflow

### 1. **Input Phase**
- Two 4×4 matrices are provided using a data generator.
- A `START` signal initiates the input process, storing both matrices in memory.

### 2. **Computation Phase**
- The matrix multiplier module performs the multiplication.
- The resulting matrix is saved for output.

### 3. **Output Phase**
- The result is shown on 7-segment displays.
- Additional LEDs indicate values that exceed the display range.

### 4. **Reset/Restart Phase**
- Pressing the `START` button resets the system for a new operation.

---

## 🎮 Features

### 1. Modes of Operation

- **Idle Mode:** System initializes and waits for input.
- **Input Mode:** Sequentially captures matrix elements.
- **Compute Mode:** Executes the multiplication efficiently.
- **Display Mode:** Presents each result element with navigation controls.

### 2. Control Signals

- `START`: Triggers input, computation, or resets the system.
- `DISPLAY`: Steps through the result one element at a time.

---

## 📜 Documentation

- **Project Requirements:** System requirements, design goals, and implementation plan. *(docs/Project_Requirements.pdf)*
- **Final Project Report:** Detailed explanation of design, simulation, synthesis, and conclusions. *(docs/Final_Report.pdf)*

---

## 🖼️ Visuals

### 1. System Block Diagram

A high-level overview showing the Data Generator, Matrix Multiplier, and Main Controller modules.

*Insert "Block Diagram" image here*

### 2. State Machine Diagram

- Main Controller FSM: Manages operation modes.
- Multiplier FSM: Handles multiplication steps.

*Insert "Main State Machine" and "Multiply State Machine" images here*

### 3. Simulation Results

- Example simulation waveform showing matrix multiplication outputs.

*Insert "Simulation Waveform" image here*

### 4. FPGA Hardware Setup

- Photo or schematic of the project on the Altera Cyclone V FPGA board.

*Insert "Hardware Setup" image here*

---

## 🎥 Demonstration Video

Check out a demo of the project in action:

- [Watch Matrices Multiply Video]([link-to-video](https://www.youtube.com/embed/o8P8AF92zM4?feature=oembed))
  
---

## 📂 Repository Structure

```
.
├── README.md
├── LICENSE
├── docs/
│   ├── Project_Requirements.pdf
│   └── Final_Report.pdf
├── src/                  # VHDL source files
├── tb/                   # Testbenches
├── assets/               # Block diagrams, waveforms, photos
└── reports/              # Simulation and synthesis results
```

---

## 👨‍💻 Author

- [Maria]

---

## 🔭 Future Improvements

- [ ] Support for larger matrices
- [ ] Pipelined or parallelized architecture
- [ ] Enhanced user interface and display modes
