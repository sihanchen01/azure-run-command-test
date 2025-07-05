#!/bin/bash

./start.sh \
    --vm-resource-group "testvm_group" \
    --vm-name "testvm" \
    --run-command-name "MyRunCommand3" \
    --log-folder "/home/azureuser/log" \
    --script-name "/home/azureuser/test3.sh" \
    --storage-account-resource-group "mytestvm_group" \
    --storage-account "sihansatest" \
    --container "run-command-test" \
    --run-as-user "azureuser"