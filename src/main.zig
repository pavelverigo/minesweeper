const std = @import("std");

const Button = enum(u8) {
    main = 0,
    aux = 1,
    second = 2,
    _,
};

const ClickInfo = struct {
    x: f32,
    y: f32,
    button: Button,
};

var clicks = std.BoundedArray(ClickInfo, 128).init(0) catch unreachable;

export fn click(x: f32, y: f32, button: Button) void {
    clicks.append(.{ .x = x, .y = y, .button = button }) catch unreachable;
}

const Pos = extern struct {
    x: f32,
    y: f32,
};

const Color = extern struct {
    r: f32,
    g: f32,
    b: f32,

    pub const RED: Color = .{ .r = 1, .g = 0, .b = 0 };
    pub const GREEN: Color = .{ .r = 0, .g = 1, .b = 0 };
    pub const BLUE: Color = .{ .r = 0, .g = 0, .b = 1 };

    pub const WHITE: Color = .{ .r = 1, .g = 1, .b = 1 };
    pub const BLACK: Color = .{ .r = 0, .g = 0, .b = 0 };
};

const Vertex = extern struct {
    x: f32,
    y: f32,
    color: Color,
};

var vertices = std.BoundedArray(Vertex, 1024).init(0) catch unreachable;

extern fn draw([*]Vertex, usize) void;

export fn frame() void {
    vertices.resize(0) catch unreachable;

    const r2d = std.math.degreesToRadians;
    const triangle: [3]Pos = comptime .{
        .{ .x = @sin(r2d(f32, 0)), .y = @cos(r2d(f32, 0)) },
        .{ .x = @sin(r2d(f32, 120)), .y = @cos(r2d(f32, 120)) },
        .{ .x = @sin(r2d(f32, 240)), .y = @cos(r2d(f32, 240)) },
    };
    const triangle_size = 20;

    blk: for (clicks.slice()) |c| {
        const color = switch (c.button) {
            .main => Color.BLUE,
            .aux => Color.GREEN,
            .second => Color.RED,
            _ => continue :blk,
        };
        inline for (triangle) |tv| {
            vertices.append(.{ .x = c.x - tv.x * triangle_size, .y = c.y - tv.y * triangle_size, .color = color }) catch unreachable;
        }
    }
    draw(&vertices.buffer, vertices.len);
}
