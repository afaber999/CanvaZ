const std = @import("std");

const canvazModuleName = "CanvaZ";


pub fn addLinkDependencies(
    compile_step: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget) void {

    switch (target.result.os.tag) {
        .macos => compile_step.linkFramework("Cocoa"),
        .windows => compile_step.linkSystemLibrary("gdi32"),
        .linux => compile_step.linkSystemLibrary("X11"),
        else => {},
    }
    compile_step.linkLibC();
}

// Function can be used by other modules to add CanvaZ as a dependency
// to their build, see readme for details
pub fn addCanvazDependencies( 
    compile_step: *std.Build.Step.Compile,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    comptime moduleName : []const  u8  ) void {

    const canvaz_dep = b.dependency(moduleName, .{
        .target = target,
        .optimize = optimize,
    });

    const canvaz = canvaz_dep.module(canvazModuleName);
    compile_step.root_module.addImport(canvazModuleName, canvaz);

    addLinkDependencies(compile_step, target);    
}

fn addCanvazModule(
    compile_step: *std.Build.Step.Compile,
    b: *std.Build,
    target: std.Build.ResolvedTarget) void {

    const canvaz_source_file = b.path("src/CanvaZ.zig");

    const canvazModule = b.addModule(
        canvazModuleName,
        .{ .root_source_file = canvaz_source_file  });

    compile_step.root_module.addImport(canvazModuleName, canvazModule);

    addLinkDependencies(compile_step, target);
}

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

        addCanvazModule(example, b, target);

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
