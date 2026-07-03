// File and path operations for patlang native runtime

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

pub fn create_temp_file(prefix: &str, ext: &str) -> io::Result<PathBuf> {
	let mut dir = std::env::temp_dir();
	dir.push("patlang_native");
	fs::create_dir_all(&dir)?;
	let file_name = format!("{}_{}.{}", prefix, uuid::Uuid::new_v4(), ext);
	let path = dir.join(file_name);
	fs::File::create(&path)?;
	Ok(path)
}

pub fn write_to_file(path: &Path, content: &str) -> io::Result<()> {
	fs::write(path, content)
}

pub fn move_or_copy(src: &Path, dest: &Path) -> io::Result<()> {
	if let Some(parent) = dest.parent() { fs::create_dir_all(parent)?; }
	match fs::rename(src, dest) {
		Ok(_) => Ok(()),
		Err(_) => fs::copy(src, dest).map(|_| ()),
	}
}

pub fn file_exists(path: &Path) -> bool {
	path.exists()
}

pub fn ensure_dir(path: &Path) -> io::Result<()> {
	fs::create_dir_all(path)
}
// File and path operations for patlang native runtime

// ...to be filled in from codegen.rs...
