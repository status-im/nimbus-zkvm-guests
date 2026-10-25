// nimbus-zkvm-guests
// Copyright (c) 2026 Status Research & Development GmbH
// Licensed and distributed under either of
//   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
//   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
// at your option. This file may not be copied, modified, or distributed except according to those terms.

//! Runs a guest ELF over one input and writes its public values out, the way
//! Ere's SP1 prover executes: the input as a single hint chunk, and a non-zero
//! exit code is a failure.

use std::{process::ExitCode, sync::Arc};

use sp1_core_executor::{MinimalExecutorEnum, Program};

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let [_, elf, input, output] = args.as_slice() else {
        eprintln!("usage: sp1-execute <guest.elf> <input.bin> <output.bin>");
        return ExitCode::from(2);
    };

    let read = |path: &str| std::fs::read(path).unwrap_or_else(|e| panic!("{path}: {e}"));
    let program = match Program::from(&read(elf)) {
        Ok(program) => Arc::new(program),
        Err(e) => {
            eprintln!("{elf}: not an SP1 program: {e}");
            return ExitCode::FAILURE;
        }
    };

    let mut executor = MinimalExecutorEnum::new(program, false, None);
    executor.with_input(&read(input));
    while !executor.is_done() {
        executor.execute_chunk();
    }

    let exit_code = executor.exit_code();
    eprintln!("exit_code={exit_code} cycles={}", executor.global_clk());
    if exit_code != 0 {
        return ExitCode::FAILURE;
    }

    std::fs::write(output, executor.public_values_stream())
        .unwrap_or_else(|e| panic!("{output}: {e}"));
    ExitCode::SUCCESS
}
