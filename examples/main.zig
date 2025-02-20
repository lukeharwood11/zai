const std = @import("std");
const proxz = @import("proxz");

/// Reads the .env file and returns a map of key-value pairs.
/// The caller is in charge of freeing the memory allocated for the map.
/// Returns a pointer to the newly created / populated hash map.
fn readDotEnv(allocator: std.mem.Allocator) !*std.StringHashMap([]const u8) {
    var env_map = try allocator.create(std.StringHashMap([]const u8));
    env_map.* = std.StringHashMap([]const u8).init(allocator);
    const env = std.fs.cwd().openFile(".env", .{}) catch |err| {
        std.log.err("Error opening .env file: {any}", .{err});
        return env_map;
    };
    defer env.close();
    const reader = env.reader();
    const lines = try reader.readAllAlloc(allocator, 1024 * 4);
    defer allocator.free(lines);
    var lines_split = std.mem.split(u8, lines, "\n");
    while (lines_split.next()) |line| {
        var key_value = std.mem.split(u8, line, "=");
        const key = key_value.next().?;
        const value = key_value.next().?;
        const key_slice = try allocator.dupe(u8, key);
        const value_slice = try allocator.dupe(u8, value);
        env_map.put(key_slice, value_slice) catch |err| {
            std.log.err("Error putting key-value pair into map: {any}", .{err});
        };
    }
    return env_map;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var env_map = try readDotEnv(arena.allocator());
    defer env_map.deinit();

    const api_key = env_map.get("OPENAI_API_KEY") orelse {
        std.log.err("OPENAI_API_KEY not found in .env file", .{});
        return;
    };

    // const api_key = "my-test-api-key";

    var openai = try proxz.OpenAI.init(allocator, .{
        .api_key = api_key,
    });

    defer openai.deinit();

    var response = try openai.chat.completions.create(.{
        // gpt-4 is deprecated, use gpt-4o instead (which is valid)
        .model = "gpt-4o",
        .messages = &[_]proxz.completions.ChatMessage{
            .{
                .role = "user",
                .content = "Hello, world!",
            },
        },
    });
    defer response.deinit();
    std.log.debug("{s}", .{response.value.choices[0].message.content});
}
