//! SQLMOD pass fixture — a normal Zig source file with no inline SQL.
//! Trips no deterministic dispatch code; write_zig --staged must exit 0.

const std = @import("std");

pub const MAX_RETRIES: u8 = 3;

pub fn add(a: u32, b: u32) u32 {
    return a + b;
}
