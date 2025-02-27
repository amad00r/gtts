const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("gtts", .{ .root_source_file = b.path("src/gtts.zig") });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gtts",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_source_file = b.path("src/gtts.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_test = b.addRunArtifact(tests);
    run_test.step.dependOn(b.getInstallStep());
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_test.step);
}
