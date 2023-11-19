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

fn parseSVGDataFromFile(comptime filename: []const u8) TessellatedSVG {
    const svg_file = @embedFile(filename);

    // TODO comptime allocation on vertices and indices arrays
    var width: f32 = undefined;
    var height: f32 = undefined;
    var view_box: Rect = undefined;
    var vertices_len: u32 = undefined;
    var vertices: [4096]Vertex = undefined;
    var indices_len: u32 = undefined;
    var indices: [4096]u32 = undefined;

    var offset = 0;

    const bytesAsValue = std.mem.bytesAsValue;

    {
        width = bytesAsValue(f32, svg_file[offset..][0..4]).*;
        height = bytesAsValue(f32, svg_file[offset..][4..8]).*;
        offset += 8;

        view_box.l = bytesAsValue(f32, svg_file[offset..][0..4]).*;
        view_box.t = bytesAsValue(f32, svg_file[offset..][4..8]).*;
        view_box.r = bytesAsValue(f32, svg_file[offset..][8..12]).*;
        view_box.b = bytesAsValue(f32, svg_file[offset..][12..16]).*;
        offset += 16;
    }

    {
        vertices_len = bytesAsValue(u32, svg_file[offset..][0..4]).*;
        offset += 4;

        var i: usize = 0;
        while (i < vertices_len) {
            vertices[i].x = bytesAsValue(f32, svg_file[offset..][0..4]).*;
            vertices[i].y = bytesAsValue(f32, svg_file[offset..][4..8]).*;

            vertices[i].r = bytesAsValue(f32, svg_file[offset..][8..12]).*;
            vertices[i].g = bytesAsValue(f32, svg_file[offset..][12..16]).*;
            vertices[i].b = bytesAsValue(f32, svg_file[offset..][16..20]).*;

            offset += 24;
            i += 1;
        }
    }

    {
        indices_len = bytesAsValue(u32, svg_file[offset..][0..4]).*;
        offset += 4;

        var i: usize = 0;
        while (i < indices_len) {
            indices[i] = bytesAsValue(u32, svg_file[offset..][0..4]).*;

            offset += 4;
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
    @setEvalBranchQuota(50000);

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
        "square_wrong_flag",
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
