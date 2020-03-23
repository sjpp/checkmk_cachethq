# CheckMK CacheHQ integration
A CheckMK alert handler Bash script to update CacheHQ

## Requirements

* cUrl
* You need to have a running CheckMK instance with Check_MK Enterprise Edition as "alert handlers" are only available in this edition
* You need to have a running CacheHQ instance, reachable from your CheckMK instance

## Usage

This is a simple Bash script that is run by CheckMK alerts handling mechanism. It grabs and processes environment variables created by CheckMK and turns them into HTTP request to the CacheHQ REST API.

The script must be executable and placed in the `/opt/omd/sites/$INSTANCE_NAME/local/share/check_mk/alert_handlers/` directory.
