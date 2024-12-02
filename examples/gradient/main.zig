const std = @import("std");
const CanvaZ = @import("CanvaZ");

pub fn main() !void {
 
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var canvas = try CanvaZ.init(allocator);
    defer canvas.deinit();

    const width = 800;
    const height = 600;

    try canvas.createWindow("CanvaZ Gradient Demo", width,height);

    var ofs : u8 = 0;
    const fw = @as(f32,@floatFromInt(width)); 
    const fh = @as(f32,@floatFromInt(height));

    while (canvas.update() == 0) {

        for (0..height) |y| {
            for (0..width) |x| {

                const dx = (fw/2.0 - @as(f32,@floatFromInt(x)) ) / fw;
                const dy = (fh/2.0 - @as(f32,@floatFromInt(y)) ) / fh;
                const d = @sqrt(dx*dx + dy*dy);
                const t = std.math.atan2(dy,dx);

                const r = @as(u8, @intFromFloat( std.math.sin(d*std.math.tau * 2.0 + t + 4.0) * 127.0 + 128.0)) +% ofs;
                const g = @as(u8, @intFromFloat( std.math.sin(d*std.math.tau + t + 3.0) * 127.0 + 128.0));
                const b = @as(u8, @intFromFloat( std.math.sin(d*std.math.tau + t + 2.0) * 127.0 + 128.0));

                canvas.setPixel(x, y, CanvaZ.from_rgba(r, g, b, 0xFF));
            }
        }
        CanvaZ.sleep(16);
        ofs +%= 2;
    }
}
