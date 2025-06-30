# Minimal C Runtime Plan for patlang-native Evaluator

## Overview

The minimal C runtime for the `patlang-native` evaluator is designed to provide a robust, efficient, and portable foundation for executing Patlang code natively. Its primary purpose is to expose essential system primitives to the evaluator, enabling safe and controlled interaction with the host environment. The design emphasizes minimalism, security, and extensibility, ensuring only necessary features are included and that the runtime can evolve as requirements change.

### Design Goals

- **Minimal Surface Area:** Only essential primitives are included to reduce attack surface and complexity.
- **Portability:** Target POSIX-compliant systems, with clear abstraction layers for platform-specific code.
- **Security:** Restrict operations to the minimum required, with explicit boundaries for system access.
- **Extensibility:** Allow for future expansion as new use cases arise, without breaking existing contracts.
- **Performance:** Favor direct, efficient system calls and avoid unnecessary abstraction.

---

## Portability and Platform Requirements

- **Portability:** The C runtime must build and run without additional requirements on both Windows and Linux (including WSL). All primitives and features must be implemented in a way that ensures full compatibility across these platforms.
- **Build Requirements:** The runtime must not depend on non-standard libraries or platform-specific extensions. Only standard C (C99 or later) and platform APIs (POSIX for Linux/WSL, Win32 for Windows) may be used.
- **Platform-Specific Considerations:** Where primitives require platform-specific handling (e.g., file I/O, message queues, dynamic loading), provide clear abstraction layers and document any differences in behavior or limitations.
- **Testing:** All features must be validated on both Windows and Linux (including WSL) to guarantee consistent behavior.

**Primitives Platform Notes:**
- **File I/O & Directory Operations:** Use standard C functions (`fopen`, `fread`, etc.) where possible. For advanced features (e.g., file locking), use POSIX APIs on Linux/WSL and Win32 APIs on Windows, with clear abstraction.
- **Module Loading:** Use `dlopen`/`dlsym` on POSIX, `LoadLibrary`/`GetProcAddress` on Windows. Abstract differences and document any limitations.
- **Message Queues:** Prefer standard C or POSIX message queues on Linux/WSL; use Windows equivalents (e.g., named pipes, mailslots) as needed. Document any behavioral differences.
- **System Operations:** Use only APIs available on both platforms or provide fallback implementations.
- **General Recommendation:** Avoid platform-specific extensions unless absolutely necessary, and always provide a portable fallback.

---

## Required Primitives

### 1. Memory Management

- **Purpose:** Allocate, free, and manage memory for evaluator operations.
- **Functions:** Allocation (`malloc`/`calloc`), deallocation (`free`), and possibly memory-mapped files for large data.

### 2. File I/O

- **Purpose:** Read from and write to files, supporting sequential and random access.
- **Functions:** Open, close, read, write, seek, stat, and delete files.

### 3. Directory Operations

- **Purpose:** Enumerate, create, and remove directories.
- **Functions:** List directory contents, create/remove directories, check existence.

### 4. Module Loading

- **Purpose:** Dynamically load evaluator modules or plugins.
- **Functions:** Load shared libraries, resolve symbols, unload modules.

### 5. System Operations

- **Purpose:** Provide access to system-level information and utilities.
- **Functions:** Get environment variables, process ID, time, and basic process control (spawn, wait).

### 6. Event/Callback System

- **Purpose:** Enable asynchronous event handling and interoperation with host events.
- **Functions:** Register/unregister callbacks, dispatch events, event loop integration.

### 7. Message Queue Support (First-Class Primitive)

- **Purpose:** Facilitate message-based concurrency and communication between evaluator components.
- **Functions:** Create/destroy queues, send/receive messages, non-blocking and blocking operations, queue introspection.

---

## Rationale for Omitting JSON Support

JSON parsing and serialization are omitted from the minimal runtime. This decision is based on the absence of a concrete use case within the current evaluator scope. If a future requirement emerges that necessitates JSON support, it can be added as an optional, modular extension rather than a core primitive.

---

## Prioritized Implementation Order & Migration Strategy

1. **Memory Management:** Foundation for all other primitives.
2. **File I/O:** Enables persistent storage and basic evaluator functionality.
3. **Directory Operations:** Required for file management and module discovery.
4. **System Operations:** Needed for environment awareness and process control.
5. **Module Loading:** Supports dynamic extension and plugin architecture.
6. **Message Queue Support:** Establishes concurrency and communication model.
7. **Event/Callback System:** Integrates asynchronous and reactive patterns.

**Migration Strategy:**
- Implement primitives incrementally, validating each with targeted tests.
- Replace existing ad-hoc or host-dependent mechanisms with runtime primitives as they become available.
- Maintain backward compatibility during migration by providing shims or adapters where necessary.
- Document each migration phase and update integration points in the evaluator.

---

## Component Relationships (Mermaid Diagram)

```mermaid
graph TD
    A[Memory Management]
    B[File I/O]
    C[Directory Operations]
    D[Module Loading]
    E[System Operations]
    F[Event/Callback System]
    G[Message Queue]

    subgraph Core Primitives
        A
        B
        C
        D
        E
    end

    G -- uses --> A
    G -- uses --> F
    F -- uses --> E
    D -- uses --> B
    D -- uses --> C
    B -- uses --> A
    C -- uses --> A
    E -- uses --> A