const std = @import("std");

http_client: std.http.Client,
buff1:       std.ArrayListUnmanaged(u8),
buff2:       std.ArrayList(u8),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .http_client = .{ .allocator = allocator },
        .buff1 = .{},
        .buff2 = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.buff1.deinit(self.http_client.allocator);
    self.buff2.deinit();
    self.http_client.deinit();
}
