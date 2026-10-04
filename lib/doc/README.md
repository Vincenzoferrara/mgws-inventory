# Project Documentation

Current technical and user documentation for mgws_inventory.

## Purpose

- describe the real current state of the code
- explain how the app works today
- help contributors and AI agents navigate the repository
- avoid using the personal wiki as the source of truth for current behavior

## Quick path

- [Global README](../../README.md) - public downloads, stores, screenshots plan and release links
- [User guide](user-guide.md) - day-to-day usage for shop operators
- [Modules map](modules-map.md) - compact map of available app areas
- [Developer guide](developer-guide.md) - architecture, integrations and contribution rules
- [Installation](installation.md) - setup, requirements and first run
- [Configuration](configuration.md) - main app settings
- [FAQ](faq.md) - quick answers to common questions
- [Troubleshooting](troubleshooting.md) - typical problems and remedies
- [Architecture](architecture.md) - technical module overview
- [Integrations](integrations.md) - backend, login and external services
- [Security](security.md) - credentials and safety rules
- [Glossary](glossary.md) - recurring project terms
- [Operational flows](operational-flows.md) - short workflows for common tasks

## Key rules

- `lib/doc` describes current behavior, not backlog or historical changes
- [Architecture](architecture.md) explains modules, settings, login and integration boundaries
- [Developer Guide](developer-guide.md) explains practical development and file-separation rules
- [Configuration](configuration.md) explains where settings live and how global/module settings are split

## Summary

- Flutter app for clothing store management
- Login through JWT, WooCommerce API, WordPress Admin flow or smartcard-supported paths
- POS checkout through MGWS and WooCommerce order creation
- MGWS handles quick load, stock reconciliation, stock moves, movement ledger, physical inventory, loyalty and custom integrations
- Public downloads and store links are in the [global README](../../README.md)
