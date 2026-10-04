use serde::{Deserialize, Serialize};

/// Lifecycle state for one independently managed business subsystem.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ModuleRuntimeStatus {
    Disabled,
    PayloadMissing,
    Installed,
    Starting,
    Ready,
    Degraded,
    Failed,
    Stopping,
    Stopped,
}

impl ModuleRuntimeStatus {
    pub fn is_available(self) -> bool {
        // A degraded module has lost its configured HTTPS listener. Keep its
        // origin private until the listener is reachable again.
        self == Self::Ready
    }
}
