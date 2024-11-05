const std = @import("std");
const CanvaZ = @import("CanvaZ");

const Star = struct {
    x: f32,
    y: f32,
    z: f32,
};


fn setPixel(buffer : []u32 ,width : usize, x : usize, y : usize, color: u32 ) void {
    const index = y * width + x;
    buffer[index] = color;
}

pub fn main() !void {
 
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var canvas = CanvaZ.init(allocator);
    const width = 800;
    const height = 600;

    try canvas.createWindow("CanvaZ Gradient Demo", width,height);

    const stars= try allocator.alloc(Star, 8000);

    const rand = std.crypto.random;
    const speed = 0.2;
    const spread = 0.8;

    for (stars) |*star| {
        star.x = spread * ( rand.float(f32) * 2.0 - 1.0);
        star.y = spread * (rand.float(f32) * 2.0 - 1.0);
        star.z = spread * (rand.float(f32) + 0.0001);
    }

    const fw = @as(f32,@floatFromInt(width)) / 2.0; 
    const fh = @as(f32,@floatFromInt(height)) / 2.0;

    while (canvas.update() == 0) {
        const delta = canvas.delta();

        const buffer = canvas.dataBuffer();
        const fillColor = CanvaZ.from_rgba(0x10, 0x10, 0x10, 0xFF);

        for (0..height) |y| {
            for (0..width) |x| {
                setPixel(buffer, width, x, y, fillColor );
            }
        }

        for (stars) |*star| {
            star.z -= delta * speed;
            if ( star.z <= 0.00001 ) {
                star.z = spread * (rand.float(f32) + 0.0001);
            }
            const x = @as(i32, @intFromFloat( star.x / star.z * fw + fw));
            const y = @as(i32, @intFromFloat( star.y / star.z * fh + fh));

            if ( x>=0 and x < @as(i32,@intCast( width)) and y>=0 and y < @as(i32,@intCast(height)) ) {
                setPixel(buffer, width, @intCast(x), @intCast(y), CanvaZ.from_rgba(0xFF, 0xFF, 0x00, 0xFF));
            }
        }

        CanvaZ.sleep(16);
    }
}
