use serde::Serialize;

use super::{ModuleRuntimeSnapshot, ModuleRuntimeStatus};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct GatewayRoute {
    pub module: &'static str,
    pub https_origin: String,
}

pub fn routes_for_ready_modules(snapshots: &[ModuleRuntimeSnapshot]) -> Vec<GatewayRoute> {
    snapshots
        .iter()
        .filter(|snapshot| snapshot.status == ModuleRuntimeStatus::Ready)
        .filter_map(|snapshot| {
            snapshot
                .https_origin
                .clone()
                .map(|https_origin| GatewayRoute {
                    module: snapshot.id,
                    https_origin,
                })
        })
        .collect()
}
