const std = @import("std");
const GTTSClient = @import("GTTSClient.zig");

buffer:  std.ArrayList(u8),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{ .buffer = std.ArrayList(u8).init(allocator) };
}

pub fn deinit(self: *@This()) void {
    self.buffer.deinit();
}

pub fn save(self: @This(), filename: []const u8) !void {
    // TODO: check this `createFile` maybe i want something like open with certain opts
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(self.buffer.items);
}

pub fn fetch(self: *@This(), client: *GTTSClient, msg: []const u8, speed: enum { default, slow }) !void {
    const GTTS_MAX_CHARS = 100;
    const GTTS_HEADERS = &[_]std.http.Header{
        .{ .name = "Referer", .value = "http://translate.google.com/" },
        .{ .name = "User-Agent", .value = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36" },
        .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded;charset=utf-8" },
    };
    const GTTS_TTS_RPC = "jQ1olc";
    const GTTS_URL = "https://translate.google.com/_/TranslateWebserverUi/data/batchexecute";

    const ChunkIterator = struct {
        text: []const u8,

        fn next(itself: *@This()) ?[]const u8 {
            const start = for (itself.text, 0..) |c, i| {
                if (!std.ascii.isWhitespace(c))
                    break i;
            } else return null;

            const end = blk: {
                if (
                    itself.text.len - start <= GTTS_MAX_CHARS and
                    !std.ascii.isWhitespace(itself.text[itself.text.len - 1])) break :blk itself.text.len;

                var ret: ?usize = null;
                const upper_bound = @min(start + GTTS_MAX_CHARS, itself.text.len);
                for (itself.text[start + 1..upper_bound], start + 1..) |c, i| {
                    if (std.ascii.isWhitespace(c) and !std.ascii.isWhitespace(itself.text[i - 1]))
                        ret = i;
                }
                break :blk ret orelse upper_bound;
            };

            const chunk = itself.text[start..end];
            itself.text = itself.text[end..];
            return chunk;
        }
    };

    var chunk_it = ChunkIterator{ .text = msg };
    while (chunk_it.next()) |chunk| : ({
        client.buff1.clearRetainingCapacity();
        client.buff2.clearRetainingCapacity();
    }) {
        try switch (speed) {
            .default => std.json.stringify(&.{ chunk, "en", null, "null" }, .{}, client.buff1.writer(client.http_client.allocator)),
            .slow => std.json.stringify(&.{ chunk, "en", true, "null" }, .{}, client.buff1.writer(client.http_client.allocator)),
        };

        try std.json.stringify(&.{.{.{ GTTS_TTS_RPC, client.buff1.items, null, "generic"}}}, .{}, client.buff2.writer());

        client.buff1.clearRetainingCapacity();

        try client.buff1.writer(client.http_client.allocator).writeAll("f.req=");
        try std.Uri.Component.percentEncode(client.buff1.writer(client.http_client.allocator), client.buff2.items, struct {
            fn _(char: u8) bool {
                for (std.base64.url_safe_alphabet_chars) |c| {
                    if (char == c) return true;
                }
                return false;
            }
        }._);
        try client.buff1.writer(client.http_client.allocator).writeAll("&");

        client.buff2.clearRetainingCapacity();

        const response = try client.http_client.fetch(.{
            .method = .POST,
            .location = .{ .url = GTTS_URL },
            .extra_headers = GTTS_HEADERS,
            .response_storage = .{ .dynamic = &client.buff2 },
            .payload = client.buff1.items,
        });

        if (response.status != std.http.Status.ok)
            return error.StatusNotOk;

        var it = std.mem.splitScalar(u8, client.buff2.items, '"');
        while (!std.mem.eql(u8, it.next().?, "jQ1olc")) {}
        _ = it.next().?;
        _ = it.next().?;
        var audio_base64 = it.next().?;
        audio_base64 = audio_base64[0..audio_base64.len - 1];

        const audioSize = try std.base64.standard_no_pad.Decoder.calcSizeForSlice(audio_base64);
        try std.base64.standard_no_pad.Decoder.decode(
            try self.buffer.addManyAsSlice(audioSize), audio_base64);
    }
}
