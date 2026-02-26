// Simple raytracer in Zig, using CanvaZ for window management and pixel manipulation.
// Based on https://github.com/tiehuis/zig-raytrace?tab=readme-ov-file

const std = @import("std");
const CanvaZ = @import("CanvaZ");

const width = 1024;
const height = 768;
const fov: f32 = std.math.pi / 3.0;
const max_bounce_depth = 4;
const lines_per_frame = 8;
const frame_sleep_ms = 1;

fn vec3(x: f32, y: f32, z: f32) Vec3f {
    return Vec3f{ .x = x, .y = y, .z = z };
}

const Vec3f = Vec3(f32);

fn Vec3(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        fn mul(u: Self, v: Self) T {
            return u.x * v.x + u.y * v.y + u.z * v.z;
        }

        fn mulScalar(u: Self, k: T) Self {
            return vec3(u.x * k, u.y * k, u.z * k);
        }

        fn add(u: Self, v: Self) Self {
            return vec3(u.x + v.x, u.y + v.y, u.z + v.z);
        }

        fn sub(u: Self, v: Self) Self {
            return vec3(u.x - v.x, u.y - v.y, u.z - v.z);
        }

        fn negate(u: Self) Self {
            return vec3(-u.x, -u.y, -u.z);
        }

        fn norm(u: Self) T {
            return std.math.sqrt(u.x * u.x + u.y * u.y + u.z * u.z);
        }

        fn normalize(u: Self) Self {
            return u.mulScalar(1 / u.norm());
        }

    };
}

const Light = struct {
    position: Vec3f,
    intensity: f32,
};

const Material = struct {
    refractive_index: f32,
    albedo: [4]f32,
    diffuse_color: Vec3f,
    specular_exponent: f32,

    pub fn default() Material {
        return Material{
            .refractive_index = 1,
            .albedo = [_]f32{ 1, 0, 0, 0 },
            .diffuse_color = vec3(0, 0, 0),
            .specular_exponent = 0,
        };
    }
};

const Sphere = struct {
    center: Vec3f,
    radius: f32,
    material: Material,

    fn rayIntersect(self: Sphere, origin: Vec3f, direction: Vec3f, t0: *f32) bool {
        const l = self.center.sub(origin);
        const tca = l.mul(direction);
        const d2 = l.mul(l) - tca * tca;

        if (d2 > self.radius * self.radius) {
            return false;
        }

        const thc = std.math.sqrt(self.radius * self.radius - d2);
        t0.* = tca - thc;
        const t1 = tca + thc;
        if (t0.* < 0) t0.* = t1;
        return t0.* >= 0;
    }
};

fn reflect(i: Vec3f, normal: Vec3f) Vec3f {
    return i.sub(normal.mulScalar(2).mulScalar(i.mul(normal)));
}

fn refract(i: Vec3f, normal: Vec3f, refractive_index: f32) Vec3f {
    var cosi = -@max(-1, @min(1, i.mul(normal)));
    var etai: f32 = 1;
    var etat = refractive_index;

    var n = normal;
    if (cosi < 0) {
        cosi = -cosi;
        std.mem.swap(f32, &etai, &etat);
        n = normal.negate();
    }

    const eta = etai / etat;
    const k = 1 - eta * eta * (1 - cosi * cosi);
    return if (k < 0) vec3(0, 0, 0) else i.mulScalar(eta).add(n.mulScalar(eta * cosi - std.math.sqrt(k)));
}

fn sceneIntersect(origin: Vec3f, direction: Vec3f, spheres: []const Sphere, hit: *Vec3f, normal: *Vec3f, material: *Material) bool {
    var spheres_dist: f32 = std.math.inf(f32);
    for (spheres) |s| {
        var dist_i: f32 = undefined;
        if (s.rayIntersect(origin, direction, &dist_i) and dist_i < spheres_dist) {
            spheres_dist = dist_i;
            hit.* = origin.add(direction.mulScalar(dist_i));
            normal.* = hit.sub(s.center).normalize();
            material.* = s.material;
        }
    }

    // Floor plane
    var checkerboard_dist: f32 = std.math.inf(f32);
    if (@abs(direction.y) > 1e-3) {
        const d = -(origin.y + 4) / direction.y;
        const pt = origin.add(direction.mulScalar(d));
        if (d > 0 and @abs(pt.x) < 10 and pt.z < -10 and pt.z > -30 and d < spheres_dist) {
            checkerboard_dist = d;
            hit.* = pt;
            normal.* = vec3(0, 1, 0);

            const diffuse = @as(i32, @intFromFloat(0.5 * hit.x + 1000)) + @as(i32, @intFromFloat(0.5 * hit.z));
            const diffuse_color = if (@mod(diffuse, 2) == 1) vec3(1, 1, 1) else vec3(1, 0.7, 0.3);
            material.diffuse_color = diffuse_color.mulScalar(0.3);
        }
    }

    return @min(spheres_dist, checkerboard_dist) < 1000;
}

fn castRay(origin: Vec3f, direction: Vec3f, spheres: []const Sphere, lights: []const Light, depth: i32) Vec3f {
    var point: Vec3f = undefined;
    var normal: Vec3f = undefined;
    var material = Material.default();

    if (depth > max_bounce_depth or !sceneIntersect(origin, direction, spheres, &point, &normal, &material)) {
        return vec3(0.2, 0.7, 0.8); // Background color
    }

    const reflect_dir = reflect(direction, normal).normalize();
    const refract_dir = refract(direction, normal, material.refractive_index).normalize();

    const nn = normal.mulScalar(1e-3);
    const reflect_origin = if (reflect_dir.mul(normal) < 0) point.sub(nn) else point.add(nn);
    const refract_origin = if (refract_dir.mul(normal) < 0) point.sub(nn) else point.add(nn);

    const reflect_color = castRay(reflect_origin, reflect_dir, spheres, lights, depth + 1);
    const refract_color = castRay(refract_origin, refract_dir, spheres, lights, depth + 1);

    var diffuse_light_intensity: f32 = 0;
    var specular_light_intensity: f32 = 0;

    for (lights) |l| {
        const light_dir = l.position.sub(point).normalize();
        const light_distance = l.position.sub(point).norm();

        const shadow_origin = if (light_dir.mul(normal) < 0) point.sub(nn) else point.add(nn);

        var shadow_pt: Vec3f = undefined;
        var shadow_n: Vec3f = undefined;
        var _unused: Material = undefined;
        if (sceneIntersect(shadow_origin, light_dir, spheres, &shadow_pt, &shadow_n, &_unused) and shadow_pt.sub(shadow_origin).norm() < light_distance) {
            continue;
        }

        diffuse_light_intensity += l.intensity * @max(0, light_dir.mul(normal));
        specular_light_intensity += std.math.pow(f32, @max(0, -reflect(light_dir.negate(), normal).mul(direction)), material.specular_exponent) * l.intensity;
    }

    const p1 = material.diffuse_color.mulScalar(diffuse_light_intensity * material.albedo[0]);
    const p2 = vec3(1, 1, 1).mulScalar(specular_light_intensity).mulScalar(material.albedo[1]);
    const p3 = reflect_color.mulScalar(material.albedo[2]);
    const p4 = refract_color.mulScalar(material.albedo[3]);
    return p1.add(p2.add(p3.add(p4)));
}

fn renderLine(canvas: *CanvaZ, j: usize, spheres: []const Sphere, lights: []const Light) !void {
    var i: usize = 0;
    while (i < width) : (i += 1) {
        const x = (2 * (@as(f32, @floatFromInt(i)) + 0.5) / @as(f32, @floatFromInt(width)) - 1) * std.math.tan(fov / 2.0) * @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
        const y = -(2 * (@as(f32, @floatFromInt(j)) + 0.5) / @as(f32, @floatFromInt(height)) - 1) * std.math.tan(fov / 2.0);

        const direction = vec3(x, y, -1).normalize();
        var c = castRay(vec3(0, 0, 0), direction, spheres, lights, 0);

        const max = @max(c.x, @max(c.y, c.z));
        if (max > 1) c = c.mulScalar(1 / max);

        const r = @as(u8, @intFromFloat(255 * @max(0, @min(1, c.x))));
        const g = @as(u8, @intFromFloat(255 * @max(0, @min(1, c.y))));
        const b = @as(u8, @intFromFloat(255 * @max(0, @min(1, c.z))));
        canvas.setPixel(i, j, CanvaZ.from_rgba(r, g, b, 0xFF));
    }
}

pub fn main() !void {
    const ivory = Material{
        .refractive_index = 1.0,
        .albedo = [_]f32{ 0.6, 0.3, 0.1, 0.0 },
        .diffuse_color = vec3(0.4, 0.4, 0.3),
        .specular_exponent = 50,
    };

    const glass = Material{
        .refractive_index = 1.5,
        .albedo = [_]f32{ 0.0, 0.5, 0.1, 0.8 },
        .diffuse_color = vec3(0.6, 0.7, 0.8),
        .specular_exponent = 125,
    };

    const red_rubber = Material{
        .refractive_index = 1.0,
        .albedo = [_]f32{ 0.9, 0.1, 0.0, 0.0 },
        .diffuse_color = vec3(0.3, 0.1, 0.1),
        .specular_exponent = 10,
    };

    const mirror = Material{
        .refractive_index = 1.0,
        .albedo = [_]f32{ 0.0, 10.0, 0.8, 0.0 },
        .diffuse_color = vec3(1.0, 1.0, 1.0),
        .specular_exponent = 1425,
    };

    const spheres = [_]Sphere{
        Sphere{
            .center = vec3(-3, 0, -16),
            .radius = 1.3,
            .material = ivory,
        },
        Sphere{
            .center = vec3(3, -1.5, -12),
            .radius = 2,
            .material = glass,
        },
        Sphere{
            .center = vec3(1.5, -0.5, -18),
            .radius = 3,
            .material = red_rubber,
        },
        Sphere{
            .center = vec3(9, 5, -18),
            .radius = 3.7,
            .material = mirror,
        },
    };

    const lights = [_]Light{
        Light{
            .position = vec3(-10, 23, 20),
            .intensity = 1.1,
        },
        Light{
            .position = vec3(17, 50, -25),
            .intensity = 1.8,
        },
        Light{
            .position = vec3(30, 20, 30),
            .intensity = 1.7,
        },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var canvas = try CanvaZ.init(allocator);
    defer canvas.deinit();

    try canvas.createWindow("CanvaZ RayTrace Demo", width, height);
    defer canvas.destroyWindow();

    var j: usize = 0;

    while (canvas.update() == 0) {
        if (j < height) {
            for (0..lines_per_frame) |_| {
                if (j >= height) break;
                try renderLine(&canvas, j, spheres[0..], lights[0..]);
                j += 1;
            }
        }
        CanvaZ.sleep(frame_sleep_ms);
    }
}
