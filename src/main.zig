const std = @import("std");
const d2 = @import("d2.zig");

const Button = enum(u8) {
    main = 0,
    aux = 1,
    second = 2,
    _,
};

export fn init(seed: u32) void {
    game = Minesweeper.init(seed);
}

export fn click(x: f32, y: f32, button: Button) void {
    const i: u8 = @intFromFloat(@trunc(x / TILE_SIZE));
    const j: u8 = @intFromFloat(@trunc(y / TILE_SIZE));

    switch (button) {
        .main => game.open(i, j),
        .aux => game.quick_open(i, j),
        .second => game.mark(i, j),
        else => {},
    }
}

const CANVAS_SIZE = 800;
const TILE_SIZE = @as(f32, CANVAS_SIZE) / Minesweeper.SIZE;

var game: Minesweeper = undefined;

const Minesweeper = struct {
    map: [SQ_SIZE]bool, // true if bomb
    view: [SQ_SIZE]ViewState, // true if open

    lost: bool = false,
    won: bool = false,
    non_opened_count: u32 = SQ_SIZE,

    const ViewState = enum(u8) {
        closed,
        opened,
        marked,
    };

    const SIZE = 9;
    const SQ_SIZE = SIZE * SIZE;
    const MINES = 10;

    fn init(seed: u32) Minesweeper {
        var map_tmp: [SQ_SIZE]bool = undefined;
        var view_tmp: [SQ_SIZE]ViewState = undefined;
        for (0..SQ_SIZE) |i| {
            map_tmp[i] = false;
            view_tmp[i] = .closed;
        }
        for (0..MINES) |i| {
            map_tmp[i] = true;
        }

        var prng = std.rand.DefaultPrng.init(seed);
        var random = prng.random();
        random.shuffle(bool, &map_tmp);

        return .{
            .map = map_tmp,
            .view = view_tmp,
        };
    }

    fn open(m: *Minesweeper, i: u8, j: u8) void {
        if (m.won or m.lost) return;
        if (m.view[i + j * SIZE] == .closed) {
            if (m.map[i + j * SIZE]) {
                m.view[i + j * SIZE] = .opened;
                m.lost = true;
            } else {
                m.cascadeOpen(i, j);
                if (m.non_opened_count == MINES) {
                    m.won = true;
                }
            }
        }
    }

    fn quick_open(m: *Minesweeper, i: u8, j: u8) void {
        if (m.won or m.lost) return;
        if (m.view[i + j * SIZE] != .opened) return;
        const cnt = m.count(i, j);
        if (cnt == 0) return;

        const dn = .{
            .{ -1, -1 },
            .{ 0, -1 },
            .{ 1, -1 },
            .{ -1, 0 },
            .{ 1, 0 },
            .{ -1, 1 },
            .{ 0, 1 },
            .{ 1, 1 },
        };
        var marked_cnt: u32 = 0;
        inline for (dn) |d| {
            const ci = @as(i32, @intCast(i)) + d[0];
            const cj = @as(i32, @intCast(j)) + d[1];
            if (0 <= ci and 0 <= cj and ci < SIZE and cj < SIZE) {
                if (m.view[@intCast(ci + cj * SIZE)] == .marked) marked_cnt += 1;
            }
        }

        if (cnt != marked_cnt) return;

        inline for (dn) |d| {
            const ci = @as(i32, @intCast(i)) + d[0];
            const cj = @as(i32, @intCast(j)) + d[1];
            if (0 <= ci and 0 <= cj and ci < SIZE and cj < SIZE) {
                m.open(@intCast(ci), @intCast(cj));
            }
        }
    }

    fn cascadeOpen(m: *Minesweeper, i: u8, j: u8) void {
        if (m.map[i + j * SIZE]) return;
        if (m.view[i + j * SIZE] == .opened) return;
        m.view[i + j * SIZE] = .opened;
        m.non_opened_count -= 1;
        if (m.count(i, j) == 0) {
            const dn = .{
                .{ -1, -1 },
                .{ 0, -1 },
                .{ 1, -1 },
                .{ -1, 0 },
                .{ 1, 0 },
                .{ -1, 1 },
                .{ 0, 1 },
                .{ 1, 1 },
            };
            inline for (dn) |d| {
                const ci = @as(i32, @intCast(i)) + d[0];
                const cj = @as(i32, @intCast(j)) + d[1];
                if (0 <= ci and 0 <= cj and ci < SIZE and cj < SIZE) {
                    m.cascadeOpen(@intCast(ci), @intCast(cj));
                }
            }
        }
    }

    fn mark(m: *Minesweeper, i: u8, j: u8) void {
        if (m.won or m.lost) return;
        switch (m.view[i + j * SIZE]) {
            .marked => {
                m.view[i + j * SIZE] = .closed;
            },
            .closed => {
                m.view[i + j * SIZE] = .marked;
            },
            else => {},
        }
    }

    fn count(m: *Minesweeper, i: u8, j: u8) u32 {
        var res: u32 = 0;
        const dn = .{
            .{ -1, -1 },
            .{ 0, -1 },
            .{ 1, -1 },
            .{ -1, 0 },
            .{ 1, 0 },
            .{ -1, 1 },
            .{ 0, 1 },
            .{ 1, 1 },
        };
        inline for (dn) |d| {
            const ci = @as(i32, @intCast(i)) + d[0];
            const cj = @as(i32, @intCast(j)) + d[1];
            if (0 <= ci and 0 <= cj and ci < SIZE and cj < SIZE) {
                if (m.map[@intCast(ci + cj * SIZE)]) res += 1;
            }
        }
        return res;
    }
};

fn mineCountToSVG(cnt: u32) d2.SVG {
    inline for (0..9) |i| {
        const char: u8 = @as(u8, @intCast(i)) + '0';
        if (i == cnt) return std.enums.nameCast(d2.SVG, "square_" ++ [1]u8{char});
    }
    unreachable;
}

export fn frame() void {
    d2.startFrame();

    for (0..Minesweeper.SIZE) |i| {
        for (0..Minesweeper.SIZE) |j| {
            const v = i + j * Minesweeper.SIZE;
            const x = @as(f32, @floatFromInt(i)) * TILE_SIZE;
            const y = @as(f32, @floatFromInt(j)) * TILE_SIZE;
            const rect = d2.Rect.fromXYWH(x, y, TILE_SIZE, TILE_SIZE);
            switch (game.view[v]) {
                .opened => {
                    if (game.map[v]) {
                        d2.drawSVG(d2.SVG.square_mine_highlight, rect);
                    } else {
                        const cnt = game.count(@intCast(i), @intCast(j));
                        const svg = mineCountToSVG(cnt);
                        d2.drawSVG(svg, rect);
                    }
                },
                .closed => {
                    if (game.won) {
                        d2.drawSVG(d2.SVG.square_flag, rect);
                    } else if (game.lost and game.map[v]) {
                        d2.drawSVG(d2.SVG.square_mine_nonhighlight, rect);
                    } else {
                        d2.drawSVG(d2.SVG.square_unopened, rect);
                    }
                },
                .marked => {
                    if (game.lost and !game.map[v]) {
                        d2.drawSVG(d2.SVG.square_wrong_flag, rect);
                    } else {
                        d2.drawSVG(d2.SVG.square_flag, rect);
                    }
                },
            }
        }
    }

    d2.endFrame();
}
