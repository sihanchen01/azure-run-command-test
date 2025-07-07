#!/bin/bash

# Example script to call start_at_work.sh with correct parameters
# This version removes blob storage parameters for work environment

run_basic_test() {
	echo "================ [Test: Basic Run Command] ================"
	./start_at_work.sh \
		--vm-resource-group "testvm_group" \
		--vm-name "testvm" \
		--run-command-name "BasicWorkTest" \
		--log-folder "/home/azureuser/log" \
		--script-name "/home/azureuser/test3.sh" \
		--run-as-user "azureuser" \
		--timeout 1800 \
		--verbose
	echo
	echo
}
echo "Running work environment tests..."

run_basic_test 2>&1 | tee testlog-at-work/01-basic.log

echo "Work environment test completed!"
