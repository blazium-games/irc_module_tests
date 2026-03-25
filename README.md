# Blazium Engine IRC Module Tests

Automated testing suite for the Blazium Engine's IRC client module. 

## Overview
This repository contains GUT-based tests that comprehensively validate the functionality of the integrated C++ IRC client within the Blazium Engine. It verifies connection handling, channel operations (join, part, topic, mode, kick), messaging capabilities (privmsg, notice, ctcp), and strict debug log suppression.

### Prerequisites
- Blazium Engine Editor binary
- GUT Framework (Godot Unit Test)

## Running the Tests
To execute the tests in a headless environment, use the following command structure against your local Blazium Editor executable:

```bash
blazium.windows.editor.x86_64.console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Authors
- Blazium Contributors

## License
MIT License
