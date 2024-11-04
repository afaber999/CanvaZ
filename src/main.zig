const std = @import("std");
const CanvaZ = @import("CanvaZ.zig");


pub fn main() !void {
 
    var canvas = CanvaZ.init();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    try canvas.createWindow("CanvaZ Demo", 800,600);

    while (canvas.update() == 0) {
    }
}
