# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Azure VM Run Command management toolkit that provides scripts to execute commands on Azure VMs asynchronously with logging and output capture to Azure Blob Storage.

## Core Architecture

The system consists of three main components:

1. **start.sh** - Main script that orchestrates the entire process:
   - Creates SAS tokens for Azure Blob Storage
   - Executes VM run commands with proper logging
   - Captures stdout and stderr to separate blob files
   - Provides comprehensive error handling and validation

2. **show.sh** - Utility to view run command results and status
3. **init.sh** - Example configuration showing how to call start.sh with parameters

## Key Workflows

### Creating and Running Commands
```bash
./start.sh \
  --vm-resource-group "testvm_group" \
  --vm-name "testvm" \
  --run-command-name "MyRunCommand" \
  --log-folder "/home/azureuser/log" \
  --script-name "/home/azureuser/script.sh" \
  --storage-account "mystorageaccount" \
  --storage-account-resource-group "mystoragegroup" \
  --container "run-command-test" \
  --run-as-user "azureuser"
```

### Viewing Command Results
```bash
./show.sh  # Shows output from hardcoded run command
```

## Important Implementation Details

- **SAS Token Management**: The system generates temporary SAS tokens (30-minute expiry) for secure blob access
- **Async Execution**: All run commands use `--async-execution true` for non-blocking operation
- **Timestamped Outputs**: All files use timestamp format `YYYYMMDD-HHMMSS`
- **Error Handling**: Comprehensive validation of required parameters and Azure CLI responses
- **Temporary Files**: Uses `mktemp` for safe temporary file handling with cleanup traps

## Required Tools

- Azure CLI (`az`) - must be authenticated
- `jq` - for JSON parsing
- Standard Unix tools: `bash`, `date`, `tee`

## File Structure

- `start.sh` - Main orchestration script (handles all VM run command lifecycle)
- `show.sh` - Result viewing utility
- `init.sh` - Example invocation
- `test.sh` - Test script utilities
- `*.json` - Output files from previous runs (examples/logs)