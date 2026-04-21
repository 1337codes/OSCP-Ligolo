# Ligolo-NG Pivot Helper Wrapper

Interactive Bash wrapper for preparing a **Ligolo-NG** lab environment on Kali/Linux.  
It centralizes interface setup, proxy startup, agent selection, and quick-reference output for **authorized** internal testing and training environments.

> Use only on systems and networks you are explicitly authorized to administer or assess.

---

## Overview

This script is a convenience launcher for Ligolo-NG workflows. It helps you:

- choose the correct local interface or IP
- pick proxy and HTTP ports
- select Linux and Windows agent filenames
- prepare multiple TUN/TAP interfaces for separate sessions
- review current routes and interface state
- start the Ligolo proxy from a fixed working directory
- display copy/paste reference material for common lab operations

The goal is to keep all Ligolo-related files, config, and operator notes in one place.

---

## Features

- Interactive startup prompts
- Fixed working directory for Ligolo assets
- Quick agent-selection reference by OS and architecture
- Prebuilt interface naming scheme for up to 5 pivot sessions
- Route/reference overview for machine access vs. internal subnet routing
- Helper output for troubleshooting and cleanup
- Starts the Ligolo proxy with a self-signed certificate
- Includes helper functions for quick reference and listener templates

---

## Directory Layout

The script expects a Ligolo workspace like:

```text
/home/alien/Desktop/OSCP/LIGOLO/
├── proxy
├── ligolo-ng.yaml
└── tunnels.sh
