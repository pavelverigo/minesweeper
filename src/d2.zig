const std = @import("std");

const Vertex = extern struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
};

pub const Rect = struct {
    l: f32,
    t: f32,
    r: f32,
    b: f32,

    pub fn fromXYWH(x: f32, y: f32, w: f32, h: f32) Rect {
        return .{ .l = x, .t = y, .r = x + w, .b = y + h };
    }

    pub fn width(rect: Rect) f32 {
        return rect.r - rect.l;
    }

    pub fn height(rect: Rect) f32 {
        return rect.r - rect.l;
    }
};

const TessellatedSVG = struct {
    width: f32,
    height: f32,
    view_box: Rect,

    vertices: []const Vertex,
    indices: []const u32,
};

// https://github.com/ziglang/zig/issues/17662
fn TODOcos(s: []const u8) []const u8 {
    if (s.len > 6) {
        return s[0..6];
    }
    return s;
}

fn parseSVGDataFromFile(comptime filename: []const u8) TessellatedSVG {
    const svg_file = @embedFile(filename);

    // TODO comptime allocation on vertices and indices arrays
    var width: f32 = undefined;
    var height: f32 = undefined;
    var view_box: Rect = undefined;
    var vertices_len: usize = undefined;
    var vertices: [4096]Vertex = undefined;
    var indices_len: usize = undefined;
    var indices: [4096]u32 = undefined;

    var it = std.mem.tokenizeAny(u8, svg_file, " \n");

    {
        width = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
        height = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;

        view_box.l = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
        view_box.t = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
        view_box.r = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
        view_box.b = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
    }

    {
        vertices_len = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;

        var i: usize = 0;
        while (i < vertices_len) {
            vertices[i].x = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
            vertices[i].y = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;

            vertices[i].r = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
            vertices[i].g = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;
            vertices[i].b = std.fmt.parseFloat(f32, TODOcos(it.next().?)) catch unreachable;

            i += 1;
        }
    }

    {
        indices_len = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;

        var i: usize = 0;
        while (i < indices_len) {
            indices[i] = std.fmt.parseInt(u32, it.next().?, 10) catch unreachable;

            i += 1;
        }
    }

    return .{
        .width = width,
        .height = height,
        .view_box = view_box,
        .vertices = vertices[0..vertices_len],
        .indices = indices[0..indices_len],
    };
}

const generated_svg_data_tuple = blk: {
    @setEvalBranchQuota(1000000);

    const tess_filenames = .{
        "square_mine_nonhighlight",
        "square_mine_highlight",
        "square_unopened",
        "square_0",
        "square_1",
        "square_2",
        "square_3",
        "square_4",
        "square_5",
        "square_6",
        "square_7",
        "square_8",
        "square_flag",
    };

    var fields: [128]std.builtin.Type.EnumField = undefined;

    for (tess_filenames, 0..) |filename, i| {
        fields[i] = .{
            .name = filename,
            .value = i,
        };
    }

    const SVGEnum = @Type(.{
        .Enum = .{
            .tag_type = u32,
            .fields = fields[0..tess_filenames.len],
            .decls = &.{},
            .is_exhaustive = true,
        },
    });

    var svg_data_tmp = std.EnumArray(SVGEnum, TessellatedSVG).initUndefined();
    for (tess_filenames, 0..) |filename, i| {
        svg_data_tmp.set(@enumFromInt(i), parseSVGDataFromFile("tessdata/" ++ filename ++ ".svg.tess"));
    }

    break :blk .{
        SVGEnum,
        svg_data_tmp,
    };
};

pub const SVG = generated_svg_data_tuple[0];
const svg_data = generated_svg_data_tuple[1];

var indices_buffer = std.BoundedArray(u32, 16384).init(0) catch unreachable;
var vertices_buffer = std.BoundedArray(Vertex, 16384).init(0) catch unreachable;

extern fn drawWASM([*]Vertex, usize, [*]u32, usize) void;

pub fn startFrame() void {
    vertices_buffer.resize(0) catch unreachable;
    indices_buffer.resize(0) catch unreachable;
}

pub fn endFrame() void {
    drawWASM(&vertices_buffer.buffer, vertices_buffer.len, &indices_buffer.buffer, indices_buffer.len);
}

pub fn drawSVG(svg_name: SVG, rect: Rect) void {
    const svg = svg_data.get(svg_name);
    const scale_x = rect.width() / svg.width;
    const scale_y = rect.height() / svg.height;

    var index_offset: usize = vertices_buffer.len;
    for (svg.indices) |i| {
        indices_buffer.append(index_offset + i) catch unreachable;
    }
    for (svg.vertices) |v| {
        var v_tmp = v;
        v_tmp.x = v_tmp.x * scale_x + rect.l;
        v_tmp.y = v_tmp.y * scale_y + rect.t;
        vertices_buffer.append(v_tmp) catch unreachable;
    }
}
