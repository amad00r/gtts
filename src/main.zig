const std = @import("std");
const GTTSClient = @import("GTTSClient.zig");
const GTTSAudio = @import("GTTSAudio.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var msg = std.ArrayList(u8).init(gpa.allocator());
    defer msg.deinit();
    const stdin = std.io.getStdIn().reader();
    try stdin.readAllArrayList(&msg, 4096);

    var client = GTTSClient.init(gpa.allocator());
    defer client.deinit();

    var voice = GTTSAudio.init(gpa.allocator());
    defer voice.deinit();
    try voice.fetch(&client, msg.items, .default);

    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(voice.buffer.items);
}
