#!/bin/bash


usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --vm-resource-group, -r <resource_group>       Resource group of the VM"
    echo "  --vm-name, -v <vm_name>                        Name of the VM"
    echo "  --run-command-name, -n <run_command_name>      Name for the run command"
    echo "  --log-folder, -l <log_folder>                  Folder to store logs"
    echo "  --script-name, -s <script_name>                Name of the script to run"
    echo "  --storage-account, -a <storage_account>        Storage account name"
    echo "  --storage-account-resource-group, -g <rg>      Resource group of the storage account"
    echo "  --container, -c <container_name>               Blob container name"
    echo "  --run-as-user, -u <username>                   User to run the command as"
    echo "  --help, -h                                     Show this help message"
}


while [[ "$#" -gt 0 ]]; do
    case $1 in
        --vm-resource-group|-r) 
            vm_resource_group="$2"
            shift 2
            ;;
        --vm-name|-v) 
            vm_name="$2"
            shift 2
            ;;
        --run-command-name|-n) 
            run_command_name="$2"
            shift 2
            ;;
        --log-folder|-l) 
            logfolder="$2"
            shift 2
            ;;
        --script-name|-s) 
            script_name="$2"
            shift 2
            ;;
        --storage-account|-a) 
            storage_account="$2"
            shift 2
            ;;
        --storage-account-resource-group|-g) 
            storage_account_resource_group="$2"
            shift 2
            ;;
        --container|-c) 
            container="$2"
            shift 2
            ;;
        --run-as-user|-u) 
            username="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *) 
            echo "Unknown parameter passed: $1";
            usage
            exit 1 
            ;;
    esac
done


set -x

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

BLOB_URI_BASE="https://${storage_account}.blob.core.windows.net/${container}"

OUTPUT_FILE="${run_command_name}-stdout-${TIMESTAMP}.txt"
ERROR_FILE="${run_command_name}-stderr-${TIMESTAMP}.txt"

# 0. set storage account key
storage_account_key=$(az storage account keys list \
    --resource-group ${storage_account_resource_group} \
    --account-name ${storage_account} \
    --query '[0].value')

# 1. get SAS token for the storage account
end=`date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ'`

output_sas=$(az storage blob generate-sas \
    --account-name ${storage_account} \
    --account-key ${storage_account_key} \
    -c ${container} \
    -n ${OUTPUT_FILE} \
    --permissions rw \
    --expiry $end \
    --https-only)

error_sas=$(az storage blob generate-sas \
    --account-name ${storage_account} \
    --account-key ${storage_account_key} \
    -c ${container} \
    -n ${ERROR_FILE} \
    --permissions rw \
    --expiry $end \
    --https-only)

# 2. create vm run command

az vm run-command create --run-command-name "${run_command_name}" \
    --async-execution true \
    --resource-group "${vm_resource_group}" \
    --vm-name "${vm_name}" \
    --script "bash ${script_name} | tee ${logfolder}/${run_command_name}-${TIMESTAMP}.log" \
    --output-blob-uri "${BLOB_URI_BASE}/${OUTPUT_FILE}/${output_sas}" \
    --error-blob-uri "${BLOB_URI_BASE}/${ERROR_FILE}/${error_sas}" \
    --run-as-user "$username"

# 3. az vm run-command show to get the output and error

az vm run-command show --run-command-name "${run_command_name}" \
    --resource-group "${vm_resource_group}" \
    --vm-name "${vm_name}" \
    --instance-view | tee tmp.json


printf "\n==================[STDOUT]===================\n"
cat tmp.json | jq -r ".instanceView.output"
printf "\n===============[END OF STDOUT]===============\n"

printf "\n==================[STDERR]===================\n"
cat tmp.json | jq -r ".instanceView.error"
printf "\n===============[END OF STDERR]===============\n"