# Indroduction
Simple ZIG based drawing canvas for Windows/Linux and Mac, it is similar but less feature rich than minifb (in C or Rust)

# CanvaZ
**CanvaZ** is a lightweight, cross-platform graphics library written in **Zig**. It provides an easy-to-use window (canvas) for rendering 2D graphics on **Windows**, **macOS**, and **Linux**. Whether you're building a custom drawing tool, a game, or experimenting with graphics, CanvaZ offers a streamlined way to render and interact with a cross-platform canvas in Zig.

## Features
Provide basic window with drawing canvas, see exampled


## Getting Started
TODO: how to include in project, check out how to deal with modules
zig build run example_gradient


1. Clone the repo
   ```bash
   git clone https://github.com/yourusername/CanvaZ.git



## Run the examples:

zig build example_gradient
zig build example_starfield


## Include CanvaZ in your own zig project:

Create directory for new project, e.g. CanvaZDemo
Create default Zig project (zig init)
Copy a demo file, e.g. gradient/main.zig to (overwrite) src/main.zig
Add CanvaZ module depedency

zig fetch --save https://github.com/afaber999/CanvaZ/archive/refs/heads/main.tar.gz

then compile and run

zig build run




