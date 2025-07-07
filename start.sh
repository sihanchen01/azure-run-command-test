#!/bin/bash

set -euo pipefail

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  --vm-resource-group, -r <resource_group>       Resource group of the VM (required)"
	echo "  --vm-name, -v <vm_name>                        Name of the VM (required)"
	echo "  --run-command-name, -n <run_command_name>      Name for the run command (required)"
	echo "  --log-folder, -l <log_folder>                  Folder to store logs (required)"
	echo "  --script-name, -s <script_name>                Name of the script to run (required)"
	echo "  --storage-account, -a <storage_account>        Storage account name (required)"
	echo "  --storage-account-resource-group, -g <rg>      Resource group of the storage account (required)"
	echo "  --container, -c <container_name>               Blob container name (required)"
	echo "  --run-as-user, -u <username>                   User to run the command as (required)"
	echo "  --timeout, -t <seconds>                        Command timeout in seconds (default: 3600)"
	echo "  --sas-expiry, -e <minutes>                     SAS token expiry in minutes (default: 60)"
	echo "  --verbose, -V                                  Enable verbose output (debug mode)"
	echo "  --no-wait                                      Don't wait for command completion"
	echo "  --help, -h                                     Show this help message"
}

# Default values
TIMEOUT_SECONDS=3600
SAS_EXPIRY_MINUTES=60
VERBOSE=false
NO_WAIT=false

if [[ $# -eq 0 ]]; then
	usage
	exit 1
fi

# ==========================[Helper Function]==========================
# Debug logging function
log_debug() {
	if [[ "$VERBOSE" == "true" ]]; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $*" >&2
	fi
}

# Info logging function
log_info() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >&2
}

# Error logging function
log_error() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: ❌ $*" >&2
}

# Success logging function
log_warning() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: ⚠️ $*" >&2
}

# Success logging function
log_success() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: ✅ $*" >&2
}

# Function to generate SAS token with retry
generate_sas_token() {
	local account_name="$1"
	local account_key="$2"
	local container_name="$3"
	local blob_name="$4"
	local expiry="$5"
	local max_retries=3
	local retry_count=0

	while ((retry_count < max_retries)); do
		local sas_token
		sas_token=$(az storage blob generate-sas \
			--account-name "$account_name" \
			--account-key "$account_key" \
			-c "$container_name" \
			-n "$blob_name" \
			--permissions rw \
			--expiry "$expiry" \
			--https-only \
			--output tsv 2>/dev/null)

		if [[ -n "$sas_token" ]]; then
			echo "$sas_token"
			return 0
		fi

		((retry_count++))
		log_info "SAS token generation failed, retrying ($retry_count/$max_retries)..."
		sleep $((retry_count * 2))
	done

	return 1
}

# Function to wait for run command completion
wait_for_completion() {
	local run_command_name="$1"
	local vm_resource_group="$2"
	local vm_name="$3"
	local max_wait_time="$4"
	local wait_interval=10
	local elapsed=0
	local attempt=1

	log_info "Waiting for command completion (timeout: ${max_wait_time}s)..."

	while ((elapsed < max_wait_time)); do
		local status

		az vm run-command show \
			--run-command-name "$run_command_name" \
			--resource-group "$vm_resource_group" \
			--vm-name "$vm_name" \
			--instance-view | tee "$TEMP_OUTPUT" >/dev/null

		status=$(cat "$TEMP_OUTPUT" | jq -r ".instanceView.executionState")

		# status=$(az vm run-command show \
		#     --run-command-name "$run_command_name" \
		#     --resource-group "$vm_resource_group" \
		#     --vm-name "$vm_name" \
		#     --instance-view \
		#     --query "instanceView.executionState" \
		#     --output tsv 2>/dev/null)

		log_info "=================[Get Running Output, Attempt-$attempt]================="
		log_info "(Attempt-$attempt) Current status: $status"

		if [[ "$status" == "Succeeded" ]]; then
			log_success "Command completed successfully"
			return 0
		elif [[ "$status" == "Failed" ]]; then
			log_error "Command failed"
			cat "$TEMP_OUTPUT" | jq -r ".instanceView.error"
			return 1
		elif [[ "$status" == "Running" ]]; then
			log_info "Command is still running... (${elapsed}s elapsed)"
			log_info "[Current Output]"
			cat "$TEMP_OUTPUT" | jq -r ".instanceView.output"
			log_info "[End of Current Output]"
		fi

		log_info "(Attempt-$attempt) 🕜 Waiting for ${wait_interval}s before next check..."
		sleep $wait_interval
		((elapsed += wait_interval))
		((attempt++))
	done

	log_error "Command timed out after ${max_wait_time}s"
	return 1
}

# Function to sanitize run command name
sanitize_run_command_name() {
	local name="$1"
	# Remove special characters and limit length
	name=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]//g' | cut -c1-64)
	if [[ -z "$name" ]]; then
		log_error "Run command name contains no valid characters"
		return 1
	fi
	echo "$name"
}

log_info "⭐ Starting Run Command Creation Pipeline..."

# ==========================[Parse Args]==========================
while [[ "$#" -gt 0 ]]; do
	case $1 in
	--vm-resource-group | -r)
		vm_resource_group="$2"
		shift 2
		;;
	--vm-name | -v)
		vm_name="$2"
		shift 2
		;;
	--run-command-name | -n)
		run_command_name="$2"
		shift 2
		;;
	--log-folder | -l)
		logfolder="$2"
		shift 2
		;;
	--script-name | -s)
		script_name="$2"
		shift 2
		;;
	--storage-account | -a)
		storage_account="$2"
		shift 2
		;;
	--storage-account-resource-group | -g)
		storage_account_resource_group="$2"
		shift 2
		;;
	--container | -c)
		container="$2"
		shift 2
		;;
	--run-as-user | -u)
		username="$2"
		shift 2
		;;
	--timeout | -t)
		TIMEOUT_SECONDS="$2"
		shift 2
		;;
	--sas-expiry | -e)
		SAS_EXPIRY_MINUTES="$2"
		shift 2
		;;
	--verbose | -V)
		VERBOSE=true
		shift 1
		;;
	--no-wait)
		NO_WAIT=true
		shift 1
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		if [[ "$1" == -* ]]; then
			log_error "Unknown parameter passed: $1"
		else
			log_error "Unexpected argument: $1"
		fi
		usage
		exit 1
		;;
	esac
done

# ==========================[Validation]==========================
# Validate required arguments
missing=()
[[ -z "${vm_resource_group:-}" ]] && missing+=("--vm-resource-group/-r")
[[ -z "${vm_name:-}" ]] && missing+=("--vm-name/-v")
[[ -z "${run_command_name:-}" ]] && missing+=("--run-command-name/-n")
[[ -z "${logfolder:-}" ]] && missing+=("--log-folder/-l")
[[ -z "${script_name:-}" ]] && missing+=("--script-name/-s")
[[ -z "${storage_account:-}" ]] && missing+=("--storage-account/-a")
[[ -z "${storage_account_resource_group:-}" ]] && missing+=("--storage-account-resource-group/-g")
[[ -z "${container:-}" ]] && missing+=("--container/-c")
[[ -z "${username:-}" ]] && missing+=("--run-as-user/-u")
if ((${#missing[@]})); then
	echo "Missing required arguments: ${missing[*]}"
	usage
	exit 1
fi

# Validate numeric parameters
if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || ((TIMEOUT_SECONDS < 1)); then
	log_error "Invalid timeout value: $TIMEOUT_SECONDS. Must be a positive integer."
	exit 1
fi

if ! [[ "$SAS_EXPIRY_MINUTES" =~ ^[0-9]+$ ]] || ((SAS_EXPIRY_MINUTES < 1)); then
	log_error "Invalid SAS expiry value: $SAS_EXPIRY_MINUTES. Must be a positive integer."
	exit 1
fi

# Validate SAS expiration time must not less than timeout
if ((SAS_EXPIRY_MINUTES * 60 < TIMEOUT_SECONDS)); then
	log_error "SAS expiry time must be greater or equal to command timeout!"
	log_error "Current SAS expiry: ${SAS_EXPIRY_MINUTES} minutes, Command timeout: ${TIMEOUT_SECONDS} seconds"
	exit 1
fi

# Validate Azure CLI authentication
log_info "Checking Azure CLI authentication..."
if ! az account show >/dev/null 2>&1; then
	log_error "Azure CLI is not authenticated. Please run 'az login' first."
	exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
log_info "Using subscription: $SUBSCRIPTION_ID"

# Validate VM exists
log_info "Validating VM exists..."
if ! az vm show --resource-group "$vm_resource_group" --name "$vm_name" >/dev/null 2>&1; then
	log_error "VM '$vm_name' not found in resource group '$vm_resource_group'"
	exit 1
fi

# Validate storage account exists
log_info "Validating storage account exists..."
if ! az storage account show --resource-group "$storage_account_resource_group" --name "$storage_account" >/dev/null 2>&1; then
	log_error "Storage account '$storage_account' not found in resource group '$storage_account_resource_group'"
	exit 1
fi

# Validate container exists
log_info "Validating container exists..."
if ! az storage container show --name "$container" --account-name "$storage_account" >/dev/null 2>&1; then
	log_error "Container '$container' not found in storage account '$storage_account'"
	exit 1
fi

# Sanitize run command name
original_run_command_name="$run_command_name"
run_command_name=$(sanitize_run_command_name "$run_command_name")
if [[ "$original_run_command_name" != "$run_command_name" ]]; then
	log_info "Sanitized run command name: '$original_run_command_name' -> '$run_command_name'"
fi

# ==========================[Run Command Variables]==========================
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

BLOB_URI_BASE="https://${storage_account}.blob.core.windows.net/${container}"

OUTPUT_FILE="${run_command_name}-stdout-${TIMESTAMP}.txt"
ERROR_FILE="${run_command_name}-stderr-${TIMESTAMP}.txt"

# Use mktemp for temp file
TEMP_OUTPUT=$(mktemp)
FINAL_RESULT=$(mktemp)
trap 'rm -f "$TEMP_OUTPUT" "$FINAL_RESULT"' EXIT

# ==========================[0. Get Storage Account Key]==========================
log_info "Retrieving storage account key..."
storage_account_key=$(az storage account keys list \
	--resource-group "${storage_account_resource_group}" \
	--account-name "${storage_account}" \
	--query '[0].value' \
	--output tsv)

if [[ -z "$storage_account_key" ]]; then
	log_error "Failed to retrieve storage account key"
	exit 1
fi

# ==========================[1. Generate SAS Token]==========================
end=$(date -u -d "$SAS_EXPIRY_MINUTES minutes" '+%Y-%m-%dT%H:%MZ')
log_info "Generated SAS token expiry: $end"

log_info "Generating SAS token for output file..."
output_sas=$(generate_sas_token "$storage_account" "$storage_account_key" "$container" "$OUTPUT_FILE" "$end")

if [[ -z "$output_sas" ]]; then
	log_error "Failed to generate output SAS token after retries"
	exit 1
fi

log_info "Generating SAS token for error file..."
error_sas=$(generate_sas_token "$storage_account" "$storage_account_key" "$container" "$ERROR_FILE" "$end")

if [[ -z "$error_sas" ]]; then
	log_error "Failed to generate error SAS token after retries"
	exit 1
fi

# ==========================[2. Create Run Command]==========================
log_info "Creating VM run command..."
if [[ "$VERBOSE" == "true" ]]; then
	set -x
	log_debug "DEBUG ON"
	log_warning "Please note that sensitive information such as SAS token may be logged!"
fi

create_run_command=$(az vm run-command create --run-command-name "${run_command_name}" \
	--async-execution true \
	--resource-group "${vm_resource_group}" \
	--vm-name "${vm_name}" \
	--script "bash ${script_name} | tee ${logfolder}/${run_command_name}-${TIMESTAMP}.log" \
	--output-blob-uri "${BLOB_URI_BASE}/${OUTPUT_FILE}?${output_sas}" \
	--error-blob-uri "${BLOB_URI_BASE}/${ERROR_FILE}?${error_sas}" \
	--timeout-in-seconds "$TIMEOUT_SECONDS" \
	--run-as-user "$username" 2>&1) || {
	log_error "Failed to create run command: $create_run_command"
	exit 1
}

if [[ "$VERBOSE" == "true" ]]; then
	log_debug "DEBUG OFF"
	set +x
fi

log_success "VM run command '$run_command_name' created successfully"

# ==========================[3. Get Result and Output]==========================
# Wait for command completion if --no-wait is not specified
if [[ "$NO_WAIT" == "true" ]]; then
	log_warning "Skipping wait for execution completion! (--no-wait specified)"
	log_warning "Skipping execution output display! (--no-wait specified)"
	exit 0
fi

if wait_for_completion "$run_command_name" "$vm_resource_group" "$vm_name" "$TIMEOUT_SECONDS"; then
	log_success "Command execution completed!"
else
	log_error "Command execution failed or timed out!"
fi

# Get final results
log_info "Retrieving command results..."

if [[ "$VERBOSE" == "true" ]]; then
	az vm run-command show --run-command-name "${run_command_name}" \
		--resource-group "${vm_resource_group}" \
		--vm-name "${vm_name}" \
		--instance-view | tee "$FINAL_RESULT"
else
	az vm run-command show --run-command-name "${run_command_name}" \
		--resource-group "${vm_resource_group}" \
		--vm-name "${vm_name}" \
		--instance-view >"$FINAL_RESULT" 2>/dev/null
fi

# Display results
execution_state=$(cat "$FINAL_RESULT" | jq -r ".instanceView.executionState")
exit_code=$(cat "$FINAL_RESULT" | jq -r ".instanceView.exitCode")
start_time=$(cat "$FINAL_RESULT" | jq -r ".instanceView.startTime")
end_time=$(cat "$FINAL_RESULT" | jq -r ".instanceView.endTime")

# Set appropriate exit code
if [[ "$execution_state" == "Succeeded" ]]; then
	log_success "Command executed successfully"
elif [[ "$execution_state" == "Failed" ]] || [[ "$exit_code" != "0" && "$exit_code" != "null" ]]; then
	log_error "Command execution failed with exit code: $exit_code"
	exit 1
else
	log_error "Unexpected command execution state: $execution_state"
	exit 1
fi

printf "\n==================[EXECUTION INFO]===================\n"
printf "Execution State: %s\n" "$execution_state"
printf "Exit Code: %s\n" "$exit_code"
printf "Start Time: %s\n" "$start_time"
printf "End Time: %s\n" "$end_time"
printf "Output Blob: %s\n" "${BLOB_URI_BASE}/${OUTPUT_FILE}"
printf "Error Blob: %s\n" "${BLOB_URI_BASE}/${ERROR_FILE}"
printf "===============[END OF EXECUTION INFO]===============\n"

printf "\n==================[STDOUT]===================\n"
cat "$FINAL_RESULT" | jq -r ".instanceView.output"
printf "\n===============[END OF STDOUT]===============\n"

printf "\n==================[STDERR]===================\n"
cat "$FINAL_RESULT" | jq -r ".instanceView.error"
printf "\n===============[END OF STDERR]===============\n"

log_success "VM run command '$run_command_name' output retrieved successfully"
