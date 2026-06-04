const std = @import("std");
pub const Widget = struct {
    items: []u32,
    pub fn init(alloc: std.mem.Allocator) !Widget {
        const items = try alloc.alloc(u32, 8);
        return .{ .items = items };
    }
};
