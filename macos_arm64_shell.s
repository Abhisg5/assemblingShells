.section __TEXT,__text,regular,pure_instructions
.global _start

_start:
    // Initialize environment
    bl init_environment

loop:
    // Display shell prompt with current directory
    bl display_prompt

    // Initialize buffer to zeros
    adrp x0, buffer@PAGE
    add x0, x0, buffer@PAGEOFF
    mov x1, #0                      // Value to store (0)
    mov x2, #0                      // Index
init_buffer_loop:
    cmp x2, #256
    bge init_buffer_done
    strb w1, [x0, x2]              // Store 0 in buffer
    add x2, x2, #1
    b init_buffer_loop
init_buffer_done:

    // Read user input
    mov x0, #0                      // stdin
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x2, #256                    // Max buffer size

    // Save all registers for syscall
    mov x20, x0                      // Save stdin
    mov x21, x1                      // Save buffer address
    mov x22, x2                      // Save buffer length

    // Debug: Print buffer address and length before read syscall
    mov x0, #1                      // stdout
    adrp x1, debug_before_read@PAGE
    add x1, x1, debug_before_read@PAGEOFF
    mov x2, #33                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print buffer address
    mov x0, x21                      // buffer address
    bl print_hex
    // Print buffer length
    mov x0, x22                      // buffer length
    bl print_hex

    // Restore all registers for syscall
    mov x0, x20                      // Restore stdin
    mov x1, x21                      // Restore buffer address
    mov x2, x22                      // Restore buffer length
    movz x16, #0x2000, lsl #16       // Syscall: read
    movk x16, #0x0003
    svc #0
    mov x19, x0                     // Save return value (bytes read)

    // Debug: Print return value of read syscall
    mov x0, x19
    bl print_hex

    // Print as decimal (simple, only for small values)
    mov x0, #1                      // stdout
    adrp x1, debug_bytes_read@PAGE
    add x1, x1, debug_bytes_read@PAGEOFF
    mov x2, #14                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, x19
    bl print_dec

    // If x19 <= 0, print error and exit
    cmp x19, #0
    bgt continue_shell
    mov x0, #1                      // stdout
    adrp x1, debug_read_error@PAGE
    add x1, x1, debug_read_error@PAGEOFF
    mov x2, #23                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // Exit code 1
    movz x16, #0x2000, lsl #16      // Syscall: exit
    movk x16, #0x0001
    svc #0

continue_shell:
    // Check for EOF (Ctrl+D)
    cmp x19, #0
    beq do_exit

    // Debug: Print raw input buffer
    mov x0, #1                      // stdout
    adrp x1, debug_raw_input@PAGE
    add x1, x1, debug_raw_input@PAGEOFF
    mov x2, #12                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Debug: Print buffer pointer after input read
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x0, x1
    bl print_hex

    // Debug: Print first 32 bytes of buffer as hex, byte-by-byte, after input read
    mov x0, #1                      // stdout
    adrp x1, debug_buffer_hex_after_input@PAGE
    add x1, x1, debug_buffer_hex_after_input@PAGEOFF
    mov x2, #36                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print buffer contents as hex
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x2, #0                      // Index
print_buffer_hex_after_input_loop:
    cmp x2, x19                     // Only print up to bytes read
    bge print_buffer_hex_after_input_done
    ldrb w3, [x1, x2]              // Load byte
    // Convert to hex
    lsr w4, w3, #4                 // High nibble
    and w5, w3, #0xF               // Low nibble
    // Convert to ASCII
    cmp w4, #10
    bge high_letter
    add w4, w4, #'0'
    b high_done
high_letter:
    add w4, w4, #'A' - 10
high_done:
    cmp w5, #10
    bge low_letter
    add w5, w5, #'0'
    b low_done
low_letter:
    add w5, w5, #'A' - 10
low_done:
    // Print high nibble
    mov x0, #1
    adrp x6, hex_digit@PAGE
    add x6, x6, hex_digit@PAGEOFF
    strb w4, [x6]
    mov x1, x6
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    // Print low nibble
    mov x0, #1
    strb w5, [x6]
    mov x1, x6
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    // Print space
    mov x0, #1
    adrp x6, space@PAGE
    add x6, x6, space@PAGEOFF
    mov x1, x6
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    add x2, x2, #1
    b print_buffer_hex_after_input_loop
print_buffer_hex_after_input_done:

    // Print newline after hex dump
    mov x0, #1                      // stdout
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0

    // Initialize argv array to NULL
    adrp x0, argv@PAGE
    add x0, x0, argv@PAGEOFF
    mov x1, #0                      // NULL value
    mov x2, #0                      // Index
init_argv_array_loop:
    cmp x2, #16                     // Max 16 arguments
    bge init_argv_array_done
    str x1, [x0, x2, lsl #3]        // Store NULL in argv[i]
    add x2, x2, #1
    b init_argv_array_loop
init_argv_array_done:

    // Parse command and arguments
    bl parse_command

    // Debug: Print argv array after parsing
    mov x0, #1                      // stdout
    adrp x1, debug_parsed_argv@PAGE
    add x1, x1, debug_parsed_argv@PAGEOFF
    mov x2, #14                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print argv array
    adrp x6, argv@PAGE
    add x6, x6, argv@PAGEOFF
    mov x7, #0                      // Index
print_parsed_argv_loop:
    cmp x7, #16                     // Max 16 arguments
    bge print_parsed_argv_done
    ldr x8, [x6, x7, lsl #3]        // Load argv[i]
    cbz x8, print_parsed_argv_done  // If NULL, done
    // Print pointer as hex
    mov x0, x8
    bl print_hex
    // Only print string if pointer is within buffer range
    adrp x9, buffer@PAGE
    add x9, x9, buffer@PAGEOFF
    mov x10, x9
    add x10, x10, #256
    cmp x8, x9
    blt skip_print_argv_str
    cmp x8, x10
    bge skip_print_argv_str
    // Print string at pointer
    mov x0, #1
    mov x1, x8
    mov x2, #64
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
skip_print_argv_str:
    // Print newline
    mov x0, #1
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    add x7, x7, #1
    b print_parsed_argv_loop
print_parsed_argv_done:

    // Debug: Print command pointer after parsing
    adrp x0, cmd@PAGE
    add x0, x0, cmd@PAGEOFF
    ldr x1, [x0]                    // Command pointer
    mov x0, x1
    bl print_hex

    // Debug: About to call check_builtins
    mov x0, #1                      // stdout
    adrp x1, debug_before_check_builtins@PAGE
    add x1, x1, debug_before_check_builtins@PAGEOFF
    mov x2, #33                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Check for built-in commands
    bl check_builtins
    cbnz x0, loop                   // If a built-in command was executed, loop

    // Debug: About to call execute_command
    mov x0, #1                      // stdout
    adrp x1, debug_before_exec_cmd@PAGE
    add x1, x1, debug_before_exec_cmd@PAGEOFF
    mov x2, #32                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Execute external command
    bl execute_command
    b loop                          // Restart shell

init_environment:
    // Save program name for argv[0]
    adrp x0, program_name@PAGE
    add x0, x0, program_name@PAGEOFF
    adrp x1, argv@PAGE
    add x1, x1, argv@PAGEOFF
    str x0, [x1]
    ret

display_prompt:
    // Get current working directory
    adrp x0, cwd_buffer@PAGE
    add x0, x0, cwd_buffer@PAGEOFF
    mov x1, #256
    movz x16, #0x2000, lsl #16      // Syscall: getcwd
    movk x16, #0x00C7
    svc #0

    // Display prompt with directory
    mov x0, #1                      // stdout
    adrp x1, prompt@PAGE
    add x1, x1, prompt@PAGEOFF
    mov x2, #2                      // Length of prompt
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    ret

parse_command:
    // Initialize command structure and argv array
    adrp x0, cmd@PAGE
    add x0, x0, cmd@PAGEOFF
    mov x1, #0
    str x1, [x0]                    // Clear command pointer
    str x1, [x0, #8]                // Clear argument count

    // Initialize argv array to NULL
    adrp x2, argv@PAGE
    add x2, x2, argv@PAGEOFF
    mov x3, #0                      // Index
init_argv_loop:
    cmp x3, #17                     // 16 args + NULL terminator
    bge init_argv_done
    str xzr, [x2, x3, lsl #3]       // Set argv[i] to NULL
    add x3, x3, #1
    b init_argv_loop
init_argv_done:

    // Parse input into command and arguments
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    adrp x2, argv@PAGE
    add x2, x2, argv@PAGEOFF
    mov x3, #0                      // arg index
    mov x4, #0                      // buffer index

parse_arg_loop:
    cmp x3, #16                     // Limit to 16 arguments
    bge parse_arg_done
    ldrb w5, [x1, x4]
    cbz w5, parse_arg_done          // End of input
    cmp w5, #'\n'
    beq parse_arg_done
    // Skip leading spaces
    cmp w5, #' '
    bne parse_arg_start
    add x4, x4, #1
    b parse_arg_loop

parse_arg_start:
    // Set argv[x3] to current buffer position
    add x6, x1, x4
    str x6, [x2, x3, lsl #3]
    add x3, x3, #1

parse_arg_copy:
    ldrb w5, [x1, x4]
    cbz w5, parse_arg_next
    cmp w5, #'\n'
    beq parse_arg_next
    cmp w5, #' '
    beq parse_arg_next
    add x4, x4, #1
    b parse_arg_copy

parse_arg_next:
    // Null-terminate this argument
    mov w5, #0
    strb w5, [x1, x4]
    add x4, x4, #1
    b parse_arg_loop

parse_arg_done:
    // Null-terminate argv
    adrp x2, argv@PAGE
    add x2, x2, argv@PAGEOFF
    str xzr, [x2, x3, lsl #3]       // argv[argc] = NULL

    // Save command pointer (argv[0])
    adrp x2, argv@PAGE
    add x2, x2, argv@PAGEOFF
    ldr x1, [x2]
    adrp x0, cmd@PAGE
    add x0, x0, cmd@PAGEOFF
    str x1, [x0]
    str x3, [x0, #8]                // Save argc

    // Debug: Print argc
    mov x0, #1                      // stdout
    adrp x1, debug_parsed_argv@PAGE
    add x1, x1, debug_parsed_argv@PAGEOFF
    mov x2, #14                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, x3                      // argc
    bl print_hex

    ret

execute_command:
    // Debug: Entered execute_command
    mov x0, #1                      // stdout
    adrp x1, debug_enter_exec@PAGE
    add x1, x1, debug_enter_exec@PAGEOFF
    mov x2, #20                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Debug: About to load command pointer
    mov x0, #1                      // stdout
    adrp x1, debug_before_cmd_ptr@PAGE
    add x1, x1, debug_before_cmd_ptr@PAGEOFF
    mov x2, #28                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print the value of the command pointer (address)
    adrp x2, cmd@PAGE
    add x2, x2, cmd@PAGEOFF
    mov x0, x2
    bl print_hex

    // Now load the command pointer
    adrp x0, cmd@PAGE
    add x0, x0, cmd@PAGEOFF
    ldr x1, [x0]                    // Command pointer

    // Debug: After loading command pointer
    mov x0, #1                      // stdout
    adrp x2, debug_after_cmd_ptr@PAGE
    add x2, x2, debug_after_cmd_ptr@PAGEOFF
    mov x1, x2
    mov x2, #27                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print the value of the loaded command pointer (address)
    mov x0, x1
    bl print_hex

    // Debug: Print executing command
    mov x0, #1                      // stdout
    adrp x1, debug_exec@PAGE
    add x1, x1, debug_exec@PAGEOFF
    mov x2, #17                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print the command being executed
    mov x0, #1                      // stdout
    adrp x1, cmd@PAGE
    add x1, x1, cmd@PAGEOFF
    ldr x1, [x1]                    // Load command pointer
    mov x2, #256                    // Max length
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print newline
    mov x0, #1                      // stdout
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1                      // Length of newline
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Debug: Print bin_path
    mov x0, #1                      // stdout
    adrp x1, debug_binpath@PAGE
    add x1, x1, debug_binpath@PAGEOFF
    mov x2, #10                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // stdout
    adrp x1, bin_path@PAGE
    add x1, x1, bin_path@PAGEOFF
    mov x2, #256
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // stdout
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0

    // Construct full path to command
    adrp x0, full_path@PAGE
    add x0, x0, full_path@PAGEOFF   // Destination buffer
    adrp x1, bin_path@PAGE
    add x1, x1, bin_path@PAGEOFF    // "/bin/"
    bl strcpy                       // Copy "/bin/" to full_path

    // Debug: Print after strcpy
    mov x0, #1                      // stdout
    adrp x1, debug_after_strcpy@PAGE
    add x1, x1, debug_after_strcpy@PAGEOFF
    mov x2, #14                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // stdout
    adrp x1, full_path@PAGE
    add x1, x1, full_path@PAGEOFF
    mov x2, #256
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // stdout
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0

    // Append command name to full path
    adrp x0, full_path@PAGE
    add x0, x0, full_path@PAGEOFF
    adrp x1, cmd@PAGE
    add x1, x1, cmd@PAGEOFF
    ldr x1, [x1]                    // Command pointer
    bl strcat                       // Append command to full_path

    // Debug: Print after strcat
    mov x0, #1                      // stdout
    adrp x1, debug_after_strcat@PAGE
    add x1, x1, debug_after_strcat@PAGEOFF
    mov x2, #14                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // stdout
    adrp x1, full_path@PAGE
    add x1, x1, full_path@PAGEOFF
    mov x2, #256
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    mov x0, #1                      // stdout
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0

    // Prepare argv array (null-terminated)
    adrp x0, cmd@PAGE
    add x0, x0, cmd@PAGEOFF
    ldr x1, [x0]                    // Command pointer
    ldr x2, [x0, #8]                // Argument count
    adrp x3, argv@PAGE
    add x3, x3, argv@PAGEOFF
    str x1, [x3]                    // argv[0] = command
    add x4, x3, #8                  // argv[1]
    mov x5, #0
    str x5, [x4, x2, lsl #3]        // argv[argc] = 0 (null-terminate)

    // Debug: Print argv array
    mov x0, #1                      // stdout
    adrp x1, debug_argv_array@PAGE
    add x1, x1, debug_argv_array@PAGEOFF
    mov x2, #11                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    adrp x6, argv@PAGE
    add x6, x6, argv@PAGEOFF
    mov x7, #0
print_argv_loop:
    ldr x8, [x6, x7, lsl #3]
    cbz x8, print_argv_done
    mov x0, #1
    adrp x1, debug_argv@PAGE
    add x1, x1, debug_argv@PAGEOFF
    mov x2, #6
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    mov x0, #1
    mov x1, x8
    mov x2, #256
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    mov x0, #1
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    mov x2, #1
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    add x7, x7, #1
    b print_argv_loop
print_argv_done:

    // Fork process
    movz x16, #0x2000, lsl #16      // Syscall: fork
    movk x16, #0x0002
    svc #0
    mov x19, x0                     // Save return value

    cmp x19, #0
    bgt parent_process              // Parent process
    blt fork_error                  // Error

    // Child process: execute command with full path
    adrp x0, full_path@PAGE
    add x0, x0, full_path@PAGEOFF   // Full path to command
    adrp x1, argv@PAGE
    add x1, x1, argv@PAGEOFF        // argv
    adrp x2, envp@PAGE
    add x2, x2, envp@PAGEOFF        // envp
    movz x16, #0x2000, lsl #16      // Syscall: execve
    movk x16, #0x003B
    svc #0

    // If execve fails, print error and exit
    adrp x1, exec_error@PAGE
    add x1, x1, exec_error@PAGEOFF
    mov x0, #2                      // stderr
    mov x2, #15                     // Error message length
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    b do_exit

parent_process:
    // Wait for child to complete
    mov x0, x19                     // Child PID
    adrp x1, child_status@PAGE
    add x1, x1, child_status@PAGEOFF
    movz x16, #0x2000, lsl #16      // Syscall: wait4
    movk x16, #0x0007
    svc #0
    ret

fork_error:
    adrp x1, fork_error_msg@PAGE
    add x1, x1, fork_error_msg@PAGEOFF
    mov x0, #2                      // stderr
    mov x2, #14                     // Error message length
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0
    ret

parse_input:
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    adrp x2, cmd@PAGE
    add x2, x2, cmd@PAGEOFF
    bl copy_cmd
    cbz x0, return_empty            // If empty command, return
    ret
return_empty:
    mov x0, #0
    ret

copy_cmd:
    mov x3, #0
    mov x0, #0                      // Default: empty command
copy_cmd_loop:
    ldrb w4, [x1, x3]
    cmp w4, #'\n'                   // End of input
    beq copy_cmd_done
    cmp w4, #0                      // Null character
    beq copy_cmd_done
    strb w4, [x2, x3]
    mov x0, #1                      // Mark as non-empty command
    add x3, x3, #1
    b copy_cmd_loop
copy_cmd_done:
    mov w4, #0                      // Null-terminate command
    strb w4, [x2, x3]
    ret

check_builtins:
    // Debug: Entered check_builtins
    mov x0, #1                      // stdout
    adrp x1, debug_enter_check_builtins@PAGE
    add x1, x1, debug_enter_check_builtins@PAGEOFF
    mov x2, #27                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Debug: About to load argv pointer
    mov x0, #1                      // stdout
    adrp x1, debug_before_argv_ptr@PAGE
    add x1, x1, debug_before_argv_ptr@PAGEOFF
    mov x2, #27                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print argv pointer as hex
    adrp x1, argv@PAGE
    add x1, x1, argv@PAGEOFF
    mov x0, x1
    bl print_hex

    // Debug: About to load argv[0]
    mov x0, #1                      // stdout
    adrp x1, debug_before_argv0@PAGE
    add x1, x1, debug_before_argv0@PAGEOFF
    mov x2, #25                     // Length of debug message
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Print argv[0] pointer as hex
    adrp x1, argv@PAGE
    add x1, x1, argv@PAGEOFF
    ldr x2, [x1]                    // argv[0]
    mov x0, x2
    bl print_hex

    // Debug: Print first 16 bytes at argv[0] as string
    mov x0, #1                      // stdout
    mov x1, x2                      // argv[0] pointer
    mov x2, #16                     // Print up to 16 bytes
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Now use argv[0] as before
    mov x1, x2
    // Simplified built-in check: if argv[0] is "exit", exit
    adrp x2, exit_cmd@PAGE
    add x2, x2, exit_cmd@PAGEOFF
    bl strcmp
    cbz x0, do_exit
    mov x0, #0                      // Not a built-in
    ret

debug_do_exit:
    adrp x1, debug_exit_recognized@PAGE
    add x1, x1, debug_exit_recognized@PAGEOFF
    mov x0, #1                      // stdout
    mov x2, #22                     // Length of debug message
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    b do_exit

do_exit:
    // Debug: Print exit message
    adrp x1, debug_exit@PAGE
    add x1, x1, debug_exit@PAGEOFF
    mov x0, #1                      // stdout
    mov x2, #18                     // Length of debug message
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004               // Syscall: write
    svc #0

    mov x0, #0                      // Exit code: 0 (success)
    movz x16, #0x2000, lsl #16      // Syscall: exit
    movk x16, #0x0001
    svc #0                          // Terminate program

strcmp:
    mov x0, #0
strcmp_loop:
    ldrb w3, [x1], #1
    ldrb w4, [x2], #1
    cmp w3, w4
    bne not_equal
    cbz w3, equal
    b strcmp_loop
not_equal:
    mov x0, #1
equal:
    ret

strcpy:
    // x0: destination
    // x1: source
    mov x2, #0                      // Index
strcpy_loop:
    ldrb w3, [x1, x2]              // Load byte from source
    strb w3, [x0, x2]              // Store byte to destination
    cbz w3, strcpy_done            // If null terminator, done
    add x2, x2, #1                 // Increment index
    b strcpy_loop
strcpy_done:
    ret

strcat:
    // x0: destination
    // x1: source
    // Find end of destination
    mov x2, #0                      // Index
strcat_find_end:
    ldrb w3, [x0, x2]              // Load byte from destination
    cbz w3, strcat_copy            // If null terminator, start copying
    add x2, x2, #1                 // Increment index
    b strcat_find_end
strcat_copy:
    mov x3, #0                      // Source index
strcat_loop:
    ldrb w4, [x1, x3]              // Load byte from source
    strb w4, [x0, x2]              // Store byte to destination
    cbz w4, strcat_done            // If null terminator, done
    add x2, x2, #1                 // Increment destination index
    add x3, x3, #1                 // Increment source index
    b strcat_loop
strcat_done:
    ret

// Helper to print a 64-bit value in hex (x0 = value)
print_hex:
    // x0: value to print
    // Uses x1-x4
    sub sp, sp, #32
    mov x2, #15
    mov x3, sp
    mov x4, x0
print_hex_loop:
    and x1, x4, #0xF
    cmp x1, #10
    blt print_hex_digit_is_num
    // If >= 10, convert to 'A' + (x1 - 10)
    add x1, x1, #'A' - 10
    b print_hex_store_digit
print_hex_digit_is_num:
    add x1, x1, #'0'
print_hex_store_digit:
    strb w1, [x3, x2]
    lsr x4, x4, #4
    subs x2, x2, #1
    b.ge print_hex_loop
    mov x0, #1
    mov x1, sp
    mov x2, #16
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    add sp, sp, #32
    ret

// Helper to print a small decimal value in x0 (0-9999)
print_dec:
    // x0: value to print
    // Uses x1-x4
    sub sp, sp, #32
    mov x1, sp
    mov x2, #0
    mov x3, x0
    mov x4, #1000
print_dec_loop:
    mov x5, #0
print_dec_inner:
    cmp x3, x4
    blt print_dec_store
    sub x3, x3, x4
    add x5, x5, #1
    b print_dec_inner
print_dec_store:
    add x5, x5, #'0'
    strb w5, [x1, x2]
    add x2, x2, #1
    lsr x4, x4, #1
    cmp x4, #0
    bne print_dec_loop
    mov x0, #1
    mov x2, #4
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004
    svc #0
    add sp, sp, #32
    ret

.section __DATA,__data
.balign 8
prompt:     .asciz "$ "
.balign 8
buffer:     .space 256
.balign 8
cwd_buffer: .space 256
.balign 8
cmd:        .space 16               // Structure: {char* cmd, int argc}
.balign 8
argv:       .space 136               // 17 pointers (16 args + NULL)
.balign 8
envp:       .quad 0                 // Environment variables (NULL for now)
.balign 8
program_name: .asciz "shell"
.balign 8
child_status: .space 8
.balign 8
exec_error: .asciz "Command failed\n"
.balign 8
fork_error_msg: .asciz "Fork failed\n"
.balign 8
exit_cmd:   .asciz "exit\0"
.balign 8
debug_read_input: .asciz "Input buffer read:\n"
.balign 8
debug_parsed_cmd: .asciz "Parsed command:\n"
.balign 8
debug_comparing_exit: .asciz "Comparing cmd: exit\n"
.balign 8
debug_exit_recognized: .asciz "Recognized exit command\n"
.balign 8
debug_exit: .asciz "Exiting shell...\n"
.balign 8
debug_exec:     .asciz "Executing: "
.balign 8
debug_execve:   .asciz "Calling execve\n"
.balign 8
newline:        .asciz "\n"
.balign 8
bin_path:      .asciz "/bin/"
.balign 8
full_path:     .space 256           // Buffer for full command path
.balign 8
debug_fullpath: .asciz "Full path: "
.balign 8
debug_argv: .asciz "argv: "
.balign 8
debug_errno: .asciz "errno: "
.balign 8
debug_argv0: .asciz "argv[0]: "
.balign 8
debug_strcmp: .asciz "strcmp: "
.balign 8
debug_raw_input: .asciz "Raw input: "
.balign 8
debug_parsed_argv: .asciz "Parsed argv: "
.balign 8
debug_argv_array: .asciz "argv array: "
.balign 8
debug_binpath:    .asciz "bin_path: "
.balign 8
debug_after_strcpy: .asciz "after strcpy: "
.balign 8
debug_after_strcat: .asciz "after strcat: "
.balign 8
debug_enter_exec: .asciz "Entered execute_command\n"
.balign 8
debug_before_cmd_ptr: .asciz "Before loading command pointer\n"
.balign 8
debug_after_cmd_ptr: .asciz "After loading command pointer\n"
.balign 8
debug_before_exec_cmd: .asciz "About to call execute_command\n"
.balign 8
debug_before_check_builtins: .asciz "About to call check_builtins\n"
.balign 8
debug_enter_check_builtins: .asciz "Entered check_builtins\n"
.balign 8
debug_before_argv_ptr: .asciz "About to load argv pointer\n"
.balign 8
debug_before_argv0: .asciz "About to load argv[0]\n"
.balign 8
debug_buffer_hex: .asciz "Buffer contents (hex): "
.balign 8
hex_digit: .asciz "0123456789ABCDEF"
.balign 8
debug_buffer_hex_after_input: .asciz "Buffer after input (hex): "
.balign 8
debug_before_read: .asciz "Before read syscall (buf,len):\n"
.balign 8
debug_bytes_read: .asciz "Bytes read (dec): "
.balign 8
debug_read_error: .asciz "Read syscall failed or EOF\n"
.balign 8
space:      .ascii " "
.balign 8
debug_argv_index: .ascii "arg"