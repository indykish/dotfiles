const std = @import("std");
pub const Widget = struct {
    items: []u32,
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator) !Widget {
        const items = try alloc.alloc(u32, 8);
        return .{ .items = items, .alloc = alloc };
    }
    pub fn deinit(self: *Widget) void {
        self.alloc.free(self.items);
    }
};
