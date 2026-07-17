# Patlang Self-Host Bootstrap & Integration Demo

This directory contains scaffolding for the Patlang stack bootstrap and integration demo (Milestone M6).

## Structure

- [`demo_entry.rb`](patlang-selfhost/demo/demo_entry.rb): Demo entry point for bootstrapping the Patlang interpreter under the Ruby host. Integration hooks are called here.
- [`integration_hooks.rb`](patlang-selfhost/demo/integration_hooks.rb): Defines integration points for initializing the interpreter and loading Patlang modules. All logic is placeholder.
- [`webserver_placeholder.rb`](patlang-selfhost/demo/webserver_placeholder.rb): Placeholder for a self-hosted webserver example. No actual webserver logic is implemented.

## Instructions

- Use `demo_entry.rb` as the starting point for integration demos.
- Implement interpreter and module loading logic in `integration_hooks.rb`.
- Add webserver integration logic in `webserver_placeholder.rb` as needed.

**Note:** This is scaffolding only. No full demo logic is implemented.