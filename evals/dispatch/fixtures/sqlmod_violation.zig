//! SQLMOD fail fixture — defines a SQL statement inline instead of in a domain
//! sql.zig. Trips exactly SQLMOD; write_zig --staged must exit 1. (No `pub fn
//! init`, short, so DEINIT and FLL stay green and the exit is attributable to
//! SQLMOD alone.)

const std = @import("std");

pub const SELECT_ACTIVE_USERS = "SELECT id, name FROM users WHERE active = true";
