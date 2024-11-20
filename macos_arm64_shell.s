.section __TEXT,__text,regular,pure_instructions
.global _start

_start:
loop:
    // Display the shell prompt
    adrp x1, prompt@PAGE
    add x1, x1, prompt@PAGEOFF
    mov x0, #1                      // File descriptor: stdout
    mov x2, #2                      // Length of prompt
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Read user input
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x0, #0                      // File descriptor: stdin
    mov x2, #256                    // Max buffer size
    movz x16, #0x2000, lsl #16      // Syscall: read
    movk x16, #0x0003
    svc #0

    // Debugging: Print the input buffer
    mov x0, #1                      // stdout
    adrp x1, buffer@PAGE
    add x1, x1, buffer@PAGEOFF
    mov x2, #256                    // Print buffer content
    movz x16, #0x2000, lsl #16      // Syscall: write
    movk x16, #0x0004
    svc #0

    // Parse and execute commands
    bl parse_input
    cbz x0, loop                    // If no command entered, loop

    bl check_builtins
    cbnz x0, loop                   // If a built-in command, loop

    bl execute_command
    b loop                          // Restart shell

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
    adrp x1, cmd@PAGE
    add x1, x1, cmd@PAGEOFF
    adrp x2, cd_cmd@PAGE
    add x2, x2, cd_cmd@PAGEOFF
    bl strcmp
    cbz x0, do_cd
    adrp x2, exit_cmd@PAGE
    add x2, x2, exit_cmd@PAGEOFF
    bl strcmp
    cbz x0, do_exit
    mov x0, #0                      // Not a built-in
    ret

do_cd:
    adrp x0, arg1@PAGE
    add x0, x0, arg1@PAGEOFF
    movz x16, #0x2000, lsl #16
    movk x16, #0x000c               // Syscall: chdir
    svc #0
    mov x0, #1                      // Built-in handled
    ret

do_exit:
    // Debug message before exiting
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
    svc #0                          // Exit the shell

execute_command:
    adrp x0, cmd@PAGE
    add x0, x0, cmd@PAGEOFF
    adrp x1, args@PAGE
    add x1, x1, args@PAGEOFF
    mov x2, #0                      // No environment variables
    movz x16, #0x2000, lsl #16
    movk x16, #0x003b               // Syscall: execve
    svc #0

    // Error handling: Command not found
    adrp x0, error_msg@PAGE
    add x0, x0, error_msg@PAGEOFF
    mov x2, #18                     // Length of error message
    mov x1, x0
    mov x0, #1                      // stdout
    movz x16, #0x2000, lsl #16
    movk x16, #0x0004               // Syscall: write
    svc #0
    ret

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

.section __DATA,__data
.balign 8
prompt:     .asciz "$ \0"
.balign 8
buffer:     .space 256
.balign 8
cmd:        .space 128
.balign 8
arg1:       .space 128
.balign 8
args:       .quad cmd, arg1, 0
.balign 8
error_msg:  .asciz "Command not found\n\0"
.balign 8
cd_cmd:     .asciz "cd\0"
.balign 8
exit_cmd:   .asciz "exit\0"
.balign 8
debug_exit: .asciz "Exiting shell...\n"