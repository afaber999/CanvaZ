const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    switch (builtin.os.tag) {
        .linux => {
            @cDefine( "_DEFAULT_SOURCE", "1" );
            @cInclude("X11/XKBlib.h");
            @cInclude("X11/Xlib.h");
            //@cInclude("X11/keysim.h");
            @cInclude("time.h");
        },
        .windows => {
            @cInclude("windows.h");
        },
        else => @compileError("Unsupported OS"),
    }
});

const PlatformSpecific = if (builtin.os.tag == .windows) struct {
    hwnd: c.HWND = null,

    fn canvasWndProc(hwnd: c.HWND, msg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) c.LRESULT {

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

} else if (builtin.os.tag == .linux) struct {
    dpy : ?*c.Display = undefined,
    w   : c.Window = undefined,
    gc  : c.GC = undefined,
    img : *c.XImage = undefined,
} else struct {

};


const Self = @This();

allocator: std.mem.Allocator,
buffer:[]u32,
mouse_x : i16 = 0,
mouse_y : i16 = 0,
width : usize = 0,
height : usize = 0,
prev_time : i64 = 0,
platform : PlatformSpecific = .{},

pub inline fn from_rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    return (@as(u32, b) << 8 * 0) | (@as(u32, g) << 8 * 1) | (@as(u32, r) << 8 * 2) | (@as(u32, a) << 8 * 3);
}

pub fn init(allocator : std.mem.Allocator) Self {
    return Self{ 
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

pub fn createWindow(self: *Self, name : [:0]const u8, width :usize, height :usize) !void {

    self.buffer = try self.allocator.alloc(u32, width*height);  
    errdefer self.allocator.free(self.buffer);
    self.width = width;
    self.height = height;

    switch (builtin.os.tag) {
        .linux => {
            const a = c.XOpenDisplay(null);
            self.platform.dpy = a;
            //self.platform.dpy = c.XOpenDisplay(null);
            const screen = c.DefaultScreen(self.platform.dpy);
            self.platform.w = c.XCreateSimpleWindow(
                self.platform.dpy,
                c.RootWindow(   self.platform.dpy, screen), 0, 0, @intCast( self.width ) ,@intCast( self.height), 0,
                    c.BlackPixel(self.platform.dpy, screen),
                    c.WhitePixel(self.platform.dpy, screen));

            self.platform.gc = c.XCreateGC(self.platform.dpy, self.platform.w, 0, 0);
            _ = c.XSelectInput(self.platform.dpy, self.platform.w,
               c.ExposureMask | c.KeyPressMask | c.KeyReleaseMask | c.ButtonPressMask |
                   c.ButtonReleaseMask | c.PointerMotionMask);
            _ = c.XStoreName(self.platform.dpy, self.platform.w, name);
            _ = c.XMapWindow(self.platform.dpy, self.platform.w);
            _ = c.XSync(self.platform.dpy, @intCast( self.platform.w));
            self.platform.img = c.XCreateImage(self.platform.dpy, c.DefaultVisual(self.platform.dpy, 0), 24, c.ZPixmap, 0,
                        @ptrCast( self.buffer.ptr), @intCast(self.width), @intCast(self.height), 32, 0);
        },
        .windows => {
            const instance = c.GetModuleHandleA(null);
            std.debug.print("Hinstance {any}", .{instance});

            var wc = std.mem.zeroes(c.WNDCLASSEX);
            wc.cbSize = @sizeOf(c.WNDCLASSEX);
            wc.style = c.CS_VREDRAW | c.CS_HREDRAW;
            wc.lpfnWndProc = PlatformSpecific.canvasWndProc;
            wc.hInstance = instance;

            wc.lpszClassName = name;
            _ = c.RegisterClassExA(&wc);

            const dwStyle = c.WS_OVERLAPPEDWINDOW & ~c.WS_MAXIMIZEBOX & ~c.WS_MINIMIZEBOX | c.WS_VISIBLE;

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

            self.platform.hwnd = hwnd;
            _ = c.SetWindowLongPtrA(hwnd, c.GWLP_USERDATA, @intCast(@intFromPtr( self )) );
            _ = c.ShowWindow(hwnd, c.SW_NORMAL);
            _ = c.UpdateWindow(hwnd);
        },
        else => @compileError("Unsupported OS"),
    }
}

pub fn destroyWindow(self: *Self) void {
    self.allocator.free(self.buffer);
}

pub fn update(self : Self) i32 {

    switch (builtin.os.tag) {
        .linux => {
            //var ev : c.XEvent = undefined;
            if (self.platform.dpy) |dpy| {
                _ = c.XPutImage(dpy, self.platform.w, self.platform.gc, self.platform.img, 0, 0, 0, 0, @intCast(self.width), @intCast(self.height));
                _ = c.XFlush(dpy);
            }
            // while ( c.XPending(self.platform.dpy) != 0) {
            //     c.XNextEvent(self.platform.dpy, &ev);
            //     switch (ev.type) {
            //         c.ButtonPress => {},
            //         c.ButtonRelease => {},
            //         else => {},
            //         // case ButtonRelease:
            //         // f->mouse = (ev.type == ButtonPress);
            //         // break;
            //         // case MotionNotify:
            //         // f->x = ev.xmotion.x, f->y = ev.xmotion.y;
            //         // break;
            //         // case KeyPress:
            //         // case KeyRelease: {
            //         // int m = ev.xkey.state;
            //         // int k = XkbKeycodeToKeysym(self.platform.dpy, ev.xkey.keycode, 0, 0);
            //         // for (unsigned int i = 0; i < 124; i += 2) {
            //         // if (FENSTER_KEYCODES[i] == k) {
            //         // f->keys[FENSTER_KEYCODES[i + 1]] = (ev.type == KeyPress);
            //         // break;
            //         // }
            //         // }
            //         // f->mod = (!!(m & ControlMask)) | (!!(m & ShiftMask) << 1) |
            //         //     (!!(m & Mod1Mask) << 2) | (!!(m & Mod4Mask) << 3);
            //         // } break;
            //     }
            // }

        },
        .windows => {
            var msg: c.MSG = undefined;
            while (c.PeekMessageA(&msg, null, 0, 0, c.PM_REMOVE) != 0 ) {
                if (msg.message == c.WM_QUIT)
                return -1;
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageA(&msg);
            }

            _ = c.InvalidateRect(self.platform.hwnd, null, c.TRUE);
        },
        else => @compileError("Unsupported OS"),
    }
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
