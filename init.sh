#!/bin/bash

test_invalid_sas() {
    echo "================ [Test: Invalid SAS Token] ================"  
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --vm-name "testvm" \
        --run-command-name "InvalidExpirationTest" \
        --log-folder "/home/azureuser/log" \
        --script-name "/home/azureuser/test2.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "sihantest" \
        --container "run-command-test" \
        --run-as-user "azureuser" \
        --timeout 1800 \
        --sas-expiry 20
    echo
    echo
}

test_invalid_storage_account() {
    echo "================ [Test: Invalid Storage Account] ================"
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --vm-name "testvm" \
        --run-command-name "InvalidStorageTest" \
        --log-folder "/home/azureuser/log" \
        --script-name "/home/azureuser/test.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "invalidaccount" \
        --container "run-command-test" \
        --run-as-user "azureuser" \
        --timeout 1800 \
        --sas-expiry 30
    echo
    echo
}

test_missing_required_args() {
    echo "================ [Test: Missing Required Arguments] ================"
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --run-command-name "MissingArgsTest" \
        --log-folder "/home/azureuser/log" \
        --script-name "/home/azureuser/test.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "sihansatest" \
        --container "run-command-test"
    echo
    echo
}

test_invalid_log_foler() {
    echo "================ [Test: Invalid Log Folder] ================"
    # test.sh will run for 100 seconds
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --vm-name "testvm" \
        --run-command-name "InvalidLogFolder" \
        --log-folder "/home/azureuser/doesnotexist" \
        --script-name "/home/azureuser/test.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "sihansatest" \
        --container "run-command-test" \
        --run-as-user "azureuser" \
        --timeout 1800 \
        --sas-expiry 30
    echo
    echo
}



test_no_wait() {
    echo "================ [Test: No Wait Mode] ================"
    # test.sh will run for 100 seconds
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --vm-name "testvm" \
        --run-command-name "NoWaitTest" \
        --log-folder "/home/azureuser/log" \
        --script-name "/home/azureuser/test2.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "sihansatest" \
        --container "run-command-test" \
        --run-as-user "azureuser" \
        --timeout 1800 \
        --sas-expiry 30 \
        --no-wait
    echo
    echo
}

test_verbose() {
    echo "================ [Test: Verbose Mode] ================"
    # test3.sh: hostname && lsblk
    # use default timeout of 3600 seconds
    # use default SAS expiry of 30 minutes
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --vm-name "testvm" \
        --run-command-name "VerboseTest" \
        --log-folder "/home/azureuser/log" \
        --script-name "/home/azureuser/test.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "sihansatest" \
        --container "run-command-test" \
        --run-as-user "azureuser" \
        --verbose
    echo
    echo
}

test_wait_for_completion() {
    echo "================ [Test: Wait for Completion] ================"
    # test2.sh will run for 30 seconds, wait_for_completion interval is 10 seconds
    ./start.sh \
        --vm-resource-group "testvm_group" \
        --vm-name "testvm" \
        --run-command-name "WaitForComplete" \
        --log-folder "/home/azureuser/log" \
        --script-name "/home/azureuser/test2.sh" \
        --storage-account-resource-group "mytestvm_group" \
        --storage-account "sihansatest" \
        --container "run-command-test" \
        --run-as-user "azureuser" \
        --timeout 600 \
        --sas-expiry 10
    echo
    echo
}



echo "Running tests..."

# test_invalid_sas 2>&1 | tee testlog/01-test_invalid_sas.log
# test_invalid_storage_account 2>&1 | tee testlog/02-test_invalid_storage_account.log 
# test_missing_required_args 2>&1 | tee testlog/03-test_missing_required_args.log
test_invalid_log_foler 2>&1 | tee testlog/04-test_invalid_log_folder.log
# test_no_wait 2>&1 | tee testlog/04-test_no_wait.log
# test_verbose 2>&1 | tee testlog/05-test_verbose.log
# test_wait_for_completion 2>&1 | tee testlog/06-test_wait_for_completion.log