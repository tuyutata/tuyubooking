//! Native orchestration core for the single TuyuBooking merchant application.
//!
//! Business behavior remains authoritative in the pinned subsystem forks. This
//! crate owns platform identity policy, module discovery, lifecycle contracts,
//! local integration, and the single PostgreSQL database boundary.

pub mod application;
pub mod core;
pub mod ffi;
pub mod public_api;
pub mod runtime;
pub mod storage;
pub mod subsystems;
