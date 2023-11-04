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
};

const Palette = struct {
    const RED: Color = .{ .r = 1, .g = 0, .b = 0 };
    const GREEN: Color = .{ .r = 0, .g = 1, .b = 0 };
    const BLUE: Color = .{ .r = 0, .g = 0, .b = 1 };

    const WHITE: Color = .{ .r = 1, .g = 1, .b = 1 };
    const LIGHT_GRAY: Color = .{ .r = 0.7, .g = 0.7, .b = 0.70 };
    const DARK_GRAY: Color = .{ .r = 0.4, .g = 0.4, .b = 0.4 };
    const BLACK: Color = .{ .r = 0, .g = 0, .b = 0 };

    const NUMBER_1 = .{ .r = 0, .g = 0, .b = 0.9 };
    const NUMBER_2 = .{ .r = 0, .g = 0.9, .b = 0 };
    const NUMBER_3 = .{ .r = 0.9, .g = 0, .b = 0 };
    const NUMBER_4 = .{ .r = 0.2, .g = 0, .b = 0.8 };
    const NUMBER_5 = .{ .r = 0.8, .g = 0.1, .b = 0.1 };
    const NUMBER_6 = .{ .r = 0, .g = 0.8, .b = 0.8 };
    const NUMBER_7 = .{ .r = 0.1, .g = 0.1, .b = 0.1 };
    const NUMBER_8 = .{ .r = 0.6, .g = 0.6, .b = 0.6 };
};

const Vertex = extern struct {
    x: f32,
    y: f32,
    color: Color,
};

var vertices_buffer = std.BoundedArray(Vertex, 4096).init(0) catch unreachable;

extern fn draw([*]Vertex, usize) void;

fn drawRectangle(x: f32, y: f32, w: f32, h: f32, color: Color) void {
    const triangle_strip = [_]Vertex{
        .{ .x = x, .y = y, .color = color },
        .{ .x = x + w, .y = y, .color = color },
        .{ .x = x, .y = y + h, .color = color },
        .{ .x = x + w, .y = y + h, .color = color },
    };

    drawStrip(triangle_strip[0..]);
}

fn drawStrip(triangle_strip: []const Vertex) void {
    const len = triangle_strip.len;
    var i: usize = 0;
    while (i + 2 < len) {
        vertices_buffer.append(triangle_strip[i]) catch unreachable;
        vertices_buffer.append(triangle_strip[i + 1]) catch unreachable;
        vertices_buffer.append(triangle_strip[i + 2]) catch unreachable;
        i += 1;
    }
}

fn verticesTransform(vertices: []Vertex, offset_x: f32, offset_y: f32, scale: f32) void {
    for (vertices) |*vertex| {
        vertex.x = scale * vertex.x + offset_x;
        vertex.y = scale * vertex.y + offset_y;
    }
}

fn drawTile(x: f32, y: f32, scale: f32) void {
    const offset = 0.1;
    const light = Palette.LIGHT_GRAY;
    const dark = Palette.DARK_GRAY;
    var triangle_strip = [_]Vertex{
        .{ .x = 0, .y = 0, .color = dark },
        .{ .x = offset, .y = offset, .color = light },
        .{ .x = 1, .y = 0, .color = dark },
        .{ .x = 1 - offset, .y = offset, .color = light },

        .{ .x = 1, .y = 1, .color = dark },
        .{ .x = 1 - offset, .y = 1 - offset, .color = light },

        .{ .x = 0, .y = 1, .color = dark },
        .{ .x = offset, .y = 1 - offset, .color = light },

        .{ .x = 0, .y = 0, .color = dark },
        .{ .x = offset, .y = offset, .color = light },
    };

    verticesTransform(triangle_strip[0..], x, y, scale);
    drawStrip(&triangle_strip);
    drawRectangle(x + offset * scale, y + offset * scale, (1 - 2 * offset) * scale, (1 - 2 * offset) * scale, light);
}

fn drawMine(x: f32, y: f32, scale: f32) void {
    const r2d = std.math.degreesToRadians;
    const triangle: [3]Pos = comptime .{
        .{ .x = @sin(r2d(f32, 0)), .y = @cos(r2d(f32, 0)) },
        .{ .x = @sin(r2d(f32, 120)), .y = @cos(r2d(f32, 120)) },
        .{ .x = @sin(r2d(f32, 240)), .y = @cos(r2d(f32, 240)) },
    };
    const triangle_size = scale * 0.4;
    inline for (triangle) |tv| {
        vertices_buffer.append(.{ .x = x + scale / 2 - tv.x * triangle_size, .y = y + scale / 2 - tv.y * triangle_size, .color = Palette.BLACK }) catch unreachable;
    }
    inline for (triangle) |tv| {
        vertices_buffer.append(.{ .x = x + scale / 2 + tv.x * triangle_size, .y = y + scale / 2 + tv.y * triangle_size, .color = Palette.BLACK }) catch unreachable;
    }
}

fn drawTriangleInBox(x: f32, y: f32, size: f32, color: Color) void {
    const d2r = std.math.degreesToRadians;
    const triangle: [3]Pos = comptime .{
        .{ .x = @sin(d2r(f32, 10)), .y = @cos(d2r(f32, 10)) },
        .{ .x = @sin(d2r(f32, 130)), .y = @cos(d2r(f32, 130)) },
        .{ .x = @sin(d2r(f32, 250)), .y = @cos(d2r(f32, 250)) },
    };
    const triangle_size = size * 0.4;
    inline for (triangle) |tv| {
        vertices_buffer.append(.{ .x = x + size / 2 - tv.x * triangle_size, .y = y + size / 2 - tv.y * triangle_size, .color = color }) catch unreachable;
    }
}

fn drawNumberSymbol(num: u8, x: f32, y: f32, scale: f32) void {
    const util = struct {
        fn drawBoxFromIndex(comptime i: comptime_int, comptime j: comptime_int, _x: f32, _y: f32, _scale: f32, _color: Color) void {
            const offset = 0.1;
            const shift = 0.8 * _scale / 3;
            drawTriangleInBox(_x + offset * _scale + i * shift, _y + offset * _scale + j * shift, shift, _color);
        }
    };
    switch (num) {
        1 => {
            const color = Palette.NUMBER_1;
            util.drawBoxFromIndex(1, 1, x, y, scale, color);
        },
        2 => {
            const color = Palette.NUMBER_2;
            util.drawBoxFromIndex(0, 1, x, y, scale, color);
            util.drawBoxFromIndex(2, 1, x, y, scale, color);
        },
        3 => {
            const color = Palette.NUMBER_3;
            util.drawBoxFromIndex(0, 1, x, y, scale, color);
            util.drawBoxFromIndex(1, 1, x, y, scale, color);
            util.drawBoxFromIndex(2, 1, x, y, scale, color);
        },
        4 => {
            const color = Palette.NUMBER_4;
            util.drawBoxFromIndex(0, 0, x, y, scale, color);
            util.drawBoxFromIndex(2, 2, x, y, scale, color);
            util.drawBoxFromIndex(2, 0, x, y, scale, color);
            util.drawBoxFromIndex(0, 2, x, y, scale, color);
        },
        5 => {
            const color = Palette.NUMBER_5;
            util.drawBoxFromIndex(0, 0, x, y, scale, color);
            util.drawBoxFromIndex(2, 2, x, y, scale, color);
            util.drawBoxFromIndex(2, 0, x, y, scale, color);
            util.drawBoxFromIndex(0, 2, x, y, scale, color);
            util.drawBoxFromIndex(1, 1, x, y, scale, color);
        },
        6 => {
            const color = Palette.NUMBER_6;
            util.drawBoxFromIndex(0, 0, x, y, scale, color);
            util.drawBoxFromIndex(2, 2, x, y, scale, color);
            util.drawBoxFromIndex(2, 0, x, y, scale, color);
            util.drawBoxFromIndex(0, 2, x, y, scale, color);
            util.drawBoxFromIndex(0, 1, x, y, scale, color);
            util.drawBoxFromIndex(2, 1, x, y, scale, color);
        },
        7 => {
            const color = Palette.NUMBER_7;
            util.drawBoxFromIndex(0, 0, x, y, scale, color);
            util.drawBoxFromIndex(2, 2, x, y, scale, color);
            util.drawBoxFromIndex(2, 0, x, y, scale, color);
            util.drawBoxFromIndex(0, 2, x, y, scale, color);
            util.drawBoxFromIndex(0, 1, x, y, scale, color);
            util.drawBoxFromIndex(2, 1, x, y, scale, color);
            util.drawBoxFromIndex(1, 1, x, y, scale, color);
        },
        8 => {
            const color = Palette.NUMBER_8;
            util.drawBoxFromIndex(0, 0, x, y, scale, color);
            util.drawBoxFromIndex(2, 2, x, y, scale, color);
            util.drawBoxFromIndex(2, 0, x, y, scale, color);
            util.drawBoxFromIndex(0, 2, x, y, scale, color);
            util.drawBoxFromIndex(0, 1, x, y, scale, color);
            util.drawBoxFromIndex(2, 1, x, y, scale, color);
            util.drawBoxFromIndex(1, 0, x, y, scale, color);
            util.drawBoxFromIndex(1, 2, x, y, scale, color);
        },
        else => unreachable,
    }
}

const CANVAS_SIZE = 800;

export fn frame() void {
    vertices_buffer.resize(0) catch unreachable;

    // const r2d = std.math.degreesToRadians;
    // const triangle: [3]Pos = comptime .{
    //     .{ .x = @sin(r2d(f32, 0)), .y = @cos(r2d(f32, 0)) },
    //     .{ .x = @sin(r2d(f32, 120)), .y = @cos(r2d(f32, 120)) },
    //     .{ .x = @sin(r2d(f32, 240)), .y = @cos(r2d(f32, 240)) },
    // };
    // const triangle_size = 20;

    drawRectangle(0, 0, CANVAS_SIZE, CANVAS_SIZE, Palette.LIGHT_GRAY);

    const rectangle_size = 20;
    const TILE_SIZE = CANVAS_SIZE / 10;

    inline for (0..10) |i| {
        inline for (0..10) |j| {
            drawTile(i * TILE_SIZE, j * TILE_SIZE, TILE_SIZE);
        }
    }

    drawMine(0, 0, TILE_SIZE);

    inline for (1..9) |c| {
        drawNumberSymbol(c, TILE_SIZE * c, 0, TILE_SIZE);
    }

    blk: for (clicks.slice()) |c| {
        const color = switch (c.button) {
            .main => Palette.BLUE,
            .aux => Palette.GREEN,
            .second => Palette.RED,
            _ => continue :blk,
        };
        const sz = rectangle_size;
        drawRectangle(c.x - sz / 2, c.y - sz / 2, sz, sz, color);
        // inline for (triangle) |tv| {
        //     vertices.append(.{ .x = c.x - tv.x * triangle_size, .y = c.y - tv.y * triangle_size, .color = color }) catch unreachable;
        // }
    }

    draw(&vertices_buffer.buffer, vertices_buffer.len);
}
