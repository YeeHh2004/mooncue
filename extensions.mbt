// Explicit public trait-method exposure for MoonBit 0.10.14 and later.
// Keep method-call APIs stable as implicit trait promotion is phased out.

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend CueIndex with Eq::{equal, not_equal}

///|
pub extend Segment with Eq::{equal, not_equal}

///|
pub extend GapPolicy with Eq::{equal, not_equal}

///|
pub extend OmittedRange with Eq::{equal, not_equal}

///|
pub extend Diagnostic with ToJson::{to_json}

///|
pub extend CueIndex with ToJson::{to_json}

///|
pub extend Track with ToJson::{to_json}

///|
pub extend CueFile with ToJson::{to_json}

///|
pub extend Sheet with ToJson::{to_json}

///|
pub extend Report with ToJson::{to_json}

///|
pub extend Segment with ToJson::{to_json}

///|
pub extend OmittedRange with ToJson::{to_json}

///|
pub extend SourceCoverage with ToJson::{to_json}

///|
pub extend PlanAudit with ToJson::{to_json}

///|
pub extend TrackEntry with ToJson::{to_json}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}
