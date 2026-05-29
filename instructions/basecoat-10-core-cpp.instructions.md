---
description: "Use when AI generates or modifies C++ or native code. Covers memory safety, concurrency, undefined behavior, and mandatory validation with sanitizers."
applyTo: "**/*.{cpp,cc,cxx,c,h,hpp,hxx}"
---

# C++ and Native Code Standards

Use this instruction for any AI-assisted change to C, C++, or native code where memory safety, concurrency, and undefined behavior are concerns.

## Memory Safety

- Preserve RAII semantics: every resource acquisition must have a corresponding release tied to scope.
- Prefer smart pointers (unique_ptr, shared_ptr) over raw pointers for ownership. Raw pointers are acceptable only for non-owning observation.
- Never return references or pointers to stack-local variables.
- Never use `delete` on memory managed by a smart pointer.
- When modifying constructors or destructors, verify the class's copy/move semantics are still correct (Rule of Zero/Three/Five).
- Check for use-after-free: if an object is moved from, do not access it afterward.

## Concurrency

- Document which mutex protects which data. Never access shared mutable state without holding the appropriate lock.
- Acquire locks in a consistent, documented order to prevent deadlocks.
- Prefer scoped lock guards (lock_guard, unique_lock) over manual lock/unlock.
- Use atomics only for simple flags or counters. Complex invariants require a mutex.
- Never hold a lock while calling user-provided callbacks or virtual functions — this invites deadlock.
- Mark single-threaded code explicitly if it must not be called from multiple threads.

## Undefined Behavior Checklist

Before accepting any AI-generated C++ change, verify:

- No signed integer overflow (use unsigned or check bounds).
- No null pointer dereference (validate pointers before use).
- No out-of-bounds array or container access.
- No strict aliasing violations (casting between unrelated pointer types).
- No data races on shared mutable state.
- No use of uninitialized variables.
- No dangling references after container reallocation or object destruction.

## Templates and Macros

- AI-generated template code is high-risk: verify it compiles with at least two distinct type instantiations.
- Avoid macro-heavy solutions. Prefer constexpr, inline functions, or templates.
- When modifying template code, check that SFINAE and concept constraints still hold.

## Build System Awareness

- Header modifications trigger recompilation cascades. Minimize changes to widely-included headers.
- One Definition Rule (ODR) violations are silent and catastrophic. Never define non-inline functions in headers.
- Forward-declare types when a full include is not needed.

## Validation Requirements

AI-generated C++ changes must pass the following before merge:

1. **Compilation** with warnings as errors (-Wall -Werror or /W4 /WX).
2. **AddressSanitizer (ASan)** — detects buffer overflows, use-after-free, memory leaks.
3. **ThreadSanitizer (TSan)** — detects data races (for concurrent code paths).
4. **UndefinedBehaviorSanitizer (UBSan)** — detects signed overflow, null deref, alignment issues.

If sanitizers are not available in CI, document the gap and recommend local validation.

## Common AI Failure Patterns in C++

Watch for these in AI-generated code:

- Inventing standard library functions that do not exist.
- Using C++20/23 features in a C++17 codebase.
- Ignoring platform differences (POSIX vs Windows APIs).
- Generating exception-unsafe code in exception-heavy codebases (or vice versa).
- Assuming containers never reallocate during iteration.
- Missing virtual destructors on base classes used polymorphically.
