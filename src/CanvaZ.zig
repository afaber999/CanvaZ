const std = @import("std");

const c = @cImport({
    @cInclude("windows.h");
});


const Self = @This();

hwnd: c.HWND = null,
mouse_x : i16 = 0,
mouse_y : i16 = 0,


pub fn canvasWndProc(hwnd: c.HWND, msg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) c.LRESULT {

    const selfAddress = @as(usize, @intCast( c.GetWindowLongPtrA(hwnd, c.GWLP_USERDATA )));
    const self = @as(?*Self, @ptrFromInt(selfAddress));

    return switch (msg) {
        c.WM_PAINT => {
            // var ps: c.PAINTSTRUCT = undefined;
            // const hdc = c.BeginPaint(hwnd, &ps);
            // c.FillRect(hdc, &ps.rcPaint, c.GetSysColorBrush(c.COLOR_WINDOW));
            // c.EndPaint(hwnd, &ps);
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

pub fn init() Self {
    return Self{ .hwnd = null };
}

pub fn createWindow(self: *Self, name : [:0]const u8, width : i32, height :i32) !void {
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
    const window_rect = c.RECT {
        .left = 0,
        .top = 0,
        .right = width,
        .bottom = height,
    };
    //_ = c.AdjustWindowRectEx(&window_rect, dwStyle, c.FALSE, 0);


    const hwnd = c.CreateWindowExA(
            c.WS_EX_CLIENTEDGE, name, name,
                            dwStyle, c.CW_USEDEFAULT, c.CW_USEDEFAULT,
                            window_rect.right - window_rect.left + 4,
                            window_rect.bottom - window_rect.top + 4,
                            null, null, instance, null);

    if (hwnd == null) {
    const error_code = c.GetLastError();
    var buffer: [256]u8 = undefined;
    const message_length = c.FormatMessageA(
        c.FORMAT_MESSAGE_FROM_SYSTEM | c.FORMAT_MESSAGE_IGNORE_INSERTS,
        c.NULL,
        error_code,
        0,
        &buffer[0],
        @as(u32, @intCast( buffer.len)),
        null,
    );
    if (message_length > 0) {
        std.debug.print("\n\nCreateWindowExA failed with error: {s}\n", .{buffer[0..message_length]});
    } else {
        std.debug.print("\n\nCreateWindowExA failed with error code: {d}\n", .{error_code});
    }

        return error.HandleInvalid;
        //return error.WindowsError{.code = c.GetLastError()};
        //return c.GetLastError();
    }

    self.hwnd = hwnd;

    std.debug.print("\n SET SELF PTR SELF:  {any}", .{self});
    _ = c.SetWindowLongPtrA(hwnd, c.GWLP_USERDATA, @intCast(@intFromPtr( self )) );
    _ = c.ShowWindow(hwnd, c.SW_NORMAL);
    _ = c.UpdateWindow(hwnd);
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

