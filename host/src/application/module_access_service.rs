use crate::application::{ApplicationContext, ApplicationError, ServiceAccess, Subsystem};

/// Access boundary for an upstream-owned business module.
///
/// Business state and rules remain inside the pinned upstream application;
/// the native core only verifies the current local administrator session.
#[derive(Clone)]
pub struct ModuleAccessService {
    context: ApplicationContext,
    subsystem: Subsystem,
}

impl ModuleAccessService {
    pub(crate) fn new(context: ApplicationContext, subsystem: Subsystem) -> Self {
        Self { context, subsystem }
    }

    pub fn access(&self) -> Result<ServiceAccess, ApplicationError> {
        self.context.service_access(self.subsystem)
    }
}
