//! Source preprocessor for Stage 0: expands `include "relative/path.patlang"`
//! lines by splicing the referenced file's contents in place. This is the
//! minimal module mechanism for self-hosted PatLang sources until the language
//! grows a real one.

use std::path::Path;

const MAX_DEPTH: usize = 16;

/// Expand `include "path"` lines in `src`, resolving paths relative to `base`.
pub fn expand_includes(src: &str, base: &Path) -> Result<String, String> {
    expand(src, base, 0)
}

fn expand(src: &str, base: &Path, depth: usize) -> Result<String, String> {
    if depth > MAX_DEPTH {
        return Err(format!("include: nesting deeper than {} levels (cycle?)", MAX_DEPTH));
    }
    let mut out = String::with_capacity(src.len());
    for line in src.lines() {
        let t = line.trim();
        let included = t
            .strip_prefix("include ")
            .map(|rest| rest.trim().trim_matches('"').to_string())
            .filter(|p| !p.is_empty() && !t.starts_with('#'));
        if let Some(rel) = included {
            let path = base.join(&rel);
            let inner = std::fs::read_to_string(&path)
                .map_err(|e| format!("include {}: {}", path.display(), e))?;
            let inner_base = path.parent().map(|p| p.to_path_buf()).unwrap_or_else(|| base.to_path_buf());
            out.push_str(&expand(&inner, &inner_base, depth + 1)?);
            out.push('\n');
        } else {
            out.push_str(line);
            out.push('\n');
        }
    }
    Ok(out)
}
