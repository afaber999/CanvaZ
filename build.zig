const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const canvaz_source_file = b.path("src/CanvaZ.zig");
    const canvazModule = b.createModule(.{ .root_source_file = canvaz_source_file  });

    const ExampleDir = "examples/";
    const Examples = [_][]const u8{ "gradient", "starfield" };

    inline for (Examples) |exampleName| {
        const nm = ExampleDir ++ exampleName ++ "/main.zig";

        const example = b.addExecutable(.{
            .name = exampleName,
            .root_source_file = b.path(nm),
            .target = target,
            .optimize = optimize,
        });

        example.root_module.addImport("CanvaZ", canvazModule);

        switch (target.result.os.tag) {
            .macos => example.linkFramework("Cocoa"),
            .windows => example.linkSystemLibrary("gdi32"),
            .linux => example.linkSystemLibrary("X11"),
            else => {},
        }
        example.linkLibC();

        b.installArtifact(example);

        const run_cmd = b.addRunArtifact(example);
        run_cmd.step.dependOn(b.getInstallStep());
        
        if (b.args) |args| {
           run_cmd.addArgs(args);
        }

        const run_step = b.step("example_" ++ exampleName, "Run the app");
        run_step.dependOn(&run_cmd.step);

    }

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    //test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
