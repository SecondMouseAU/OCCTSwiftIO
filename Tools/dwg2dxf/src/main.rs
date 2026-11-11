//! dwg2dxf: convert a DWG drawing to ASCII DXF.
//!
//! `dwg2dxf <input.dwg> <output.dxf>` writes a file. `dwg2dxf <input.dwg> -` writes the DXF to
//! standard output, which is how OCCTSwiftIO's `DWGLoader` calls it. `dwg2dxf --version` prints
//! this tool's version and the version of the acadrust library that does the reading, so a
//! conversion can record exactly what produced it.
//!
//! Exit status: 0 on success, 1 when the drawing could not be read or written, 2 on bad usage.

use acadrust::{DwgReader, DxfWriter};
use std::io::Write;
use std::process::ExitCode;

/// The acadrust version this tool is built against. Keep in step with Cargo.toml.
const ACADRUST_VERSION: &str = "0.6.8";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() == 1 && args[0] == "--version" {
        println!("dwg2dxf {} acadrust {}", env!("CARGO_PKG_VERSION"), ACADRUST_VERSION);
        return ExitCode::SUCCESS;
    }
    if args.len() != 2 {
        eprintln!("usage: dwg2dxf <input.dwg> <output.dxf | ->");
        eprintln!("       dwg2dxf --version");
        return ExitCode::from(2);
    }

    let document = match DwgReader::from_file(&args[0]).and_then(|mut reader| reader.read()) {
        Ok(document) => document,
        Err(error) => {
            eprintln!("dwg2dxf: cannot read {}: {error}", args[0]);
            return ExitCode::FAILURE;
        }
    };

    let writer = DxfWriter::new(&document);
    let written = if args[1] == "-" {
        // Build the whole DXF first, so a failure never leaves half a drawing on stdout.
        writer.write_to_vec().and_then(|bytes| {
            let mut out = std::io::stdout().lock();
            out.write_all(&bytes)?;
            out.flush()?;
            Ok(())
        })
    } else {
        writer.write_to_file(&args[1])
    };
    match written {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("dwg2dxf: cannot write DXF: {error}");
            ExitCode::FAILURE
        }
    }
}
