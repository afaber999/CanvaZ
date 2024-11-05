const std = @import("std");

const c = @cImport({
    @cInclude("windows.h");
});

const Self = @This();

hwnd: c.HWND = null,
allocator: std.mem.Allocator,
buffer:[]u32,
mouse_x : i16 = 0,
mouse_y : i16 = 0,
width : usize = 0,
height : usize = 0,
prev_time : i64 = 0,

pub inline fn from_rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    return (@as(u32, b) << 8 * 0) | (@as(u32, g) << 8 * 1) | (@as(u32, r) << 8 * 2) | (@as(u32, a) << 8 * 3);
}

pub fn init(allocator : std.mem.Allocator) Self {
    return Self{ 
        .hwnd = null,
        .allocator = allocator,
        .buffer = &.{},
        .prev_time = std.time.milliTimestamp(),
    };
}

pub fn dataBuffer(self: *Self) []u32 {
    return self.buffer[0..];
}

pub const BINFO = extern struct {
    bmiHeader: c.BITMAPINFOHEADER = std.mem.zeroes(c.BITMAPINFOHEADER),
    bmiColors: [3]c.RGBQUAD = std.mem.zeroes([3]c.RGBQUAD),
};


pub fn canvasWndProc(hwnd: c.HWND, msg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) c.LRESULT {

    const selfAddress = @as(usize, @intCast( c.GetWindowLongPtrA(hwnd, c.GWLP_USERDATA )));
    const self = @as(?*Self, @ptrFromInt(selfAddress));

    return switch (msg) {
        c.WM_PAINT => {
            if (self) |s| {
                var ps: c.PAINTSTRUCT = undefined;
                const hdc = c.BeginPaint(hwnd, &ps);
                const memdc = c.CreateCompatibleDC(hdc);
                const hbmp = c.CreateCompatibleBitmap(hdc, @intCast(s.width), @intCast(s.height));
                const oldbmp = c.SelectObject(memdc, hbmp);
                var bi : BINFO = std.mem.zeroes(BINFO);
                bi.bmiHeader.biSize = @sizeOf(BINFO);
                bi.bmiHeader.biWidth = @as(c.LONG, @intCast(s.width));
                bi.bmiHeader.biHeight = -@as(c.LONG, @intCast(s.height));
                bi.bmiHeader.biPlanes = 1;
                bi.bmiHeader.biBitCount = 32;
                bi.bmiHeader.biCompression = c.BI_BITFIELDS;
                bi.bmiColors[0].rgbRed = 0xff;
                bi.bmiColors[1].rgbGreen = 0xff;
                bi.bmiColors[2].rgbBlue = 0xff;

                _ = c.SetDIBitsToDevice(memdc, 0, 0, @intCast(s.width), @intCast(s.height), 0, 0, 0, @intCast(s.height),
                    s.buffer.ptr, @ptrCast(&bi), c.DIB_RGB_COLORS);
                _ = c.BitBlt(hdc, 0, 0, @intCast(s.width), @intCast(s.height), memdc, 0, 0, c.SRCCOPY);
                _ = c.SelectObject(memdc, oldbmp);
                _ = c.DeleteObject(hbmp);
                _ = c.DeleteDC(memdc);
                _ = c.EndPaint(hwnd, &ps);            
            }            
            return 0;
        },
        c.WM_MOUSEMOVE => {
            if (self) |s| {
                const lp : i32 = @intCast(lParam);
                s.mouse_x = @truncate(lp);
                s.mouse_y = @truncate(lp >> 16);
            }
            return 0;
        },
        c.WM_CLOSE => c.DestroyWindow(hwnd),
        c.WM_DESTROY => {c.PostQuitMessage(0); return 0;},
        else => c.DefWindowProcA(hwnd, msg, wParam, lParam),    
    };
}



pub fn createWindow(self: *Self, name : [:0]const u8, width :usize, height :usize) !void {

    self.buffer = try self.allocator.alloc(u32, width*height);  
    errdefer self.allocator.free(self.buffer);

    self.width = width;
    self.height = height;

    const instance = c.GetModuleHandleA(null);
    std.debug.print("Hinstance {any}", .{instance});

    var wc = std.mem.zeroes(c.WNDCLASSEX);
    wc.cbSize = @sizeOf(c.WNDCLASSEX);
    wc.style = c.CS_VREDRAW | c.CS_HREDRAW;
    wc.lpfnWndProc = canvasWndProc;
    wc.hInstance = instance;

    wc.lpszClassName = name;
    _ = c.RegisterClassExA(&wc);

    const dwStyle = c.WS_OVERLAPPEDWINDOW & ~c.WS_MAXIMIZEBOX & ~c.WS_MINIMIZEBOX | c.WS_VISIBLE;

//   // Calculate the required size of the window rectangle based on desired client area size
    var window_rect = c.RECT {
        .left = 0,
        .top = 0,
        .right = @intCast(width),
        .bottom = @intCast(height),
    };
    _ = c.AdjustWindowRectEx(&window_rect, dwStyle, c.FALSE, 0);

    const hwnd = c.CreateWindowExA(
            c.WS_EX_CLIENTEDGE, name, name,
                            dwStyle, c.CW_USEDEFAULT, c.CW_USEDEFAULT,
                            window_rect.right - window_rect.left + 4,
                            window_rect.bottom - window_rect.top + 4,
                            null, null, instance, null);

    if (hwnd == null) {
        return error.HandleInvalid;
    }

    self.hwnd = hwnd;
    _ = c.SetWindowLongPtrA(hwnd, c.GWLP_USERDATA, @intCast(@intFromPtr( self )) );
    _ = c.ShowWindow(hwnd, c.SW_NORMAL);
    _ = c.UpdateWindow(hwnd);
}

pub fn destroyWindow(self: *Self) void {
    self.allocator.free(self.buffer);
}


pub fn update(self : Self) i32 {
  
  var msg: c.MSG = undefined;

  while (c.PeekMessageA(&msg, null, 0, 0, c.PM_REMOVE) != 0 ) {
    if (msg.message == c.WM_QUIT)
      return -1;
    _ = c.TranslateMessage(&msg);
    _ = c.DispatchMessageA(&msg);
  }

  _ = c.InvalidateRect(self.hwnd, null, c.TRUE);
  return 0;
}

pub fn sleep(ms : u64) void { 
    std.time.sleep(ms * 1000 * 1000);
}

pub fn delta(self : *Self) f32 {
    const new_time = std.time.milliTimestamp();
    const delta_secs = @as(f32, @floatFromInt( new_time - self.prev_time )) / std.time.ms_per_s;
    self.prev_time = new_time;    
    return delta_secs;
}
