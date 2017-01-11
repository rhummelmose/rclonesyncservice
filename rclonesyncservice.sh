#!/bin/bash

# globals
service_name="rclonesyncservice"
service_version="0.0.1"

# exit codes and text
error_number_success=0; error_text[$error_number_success]="error_number_success"
error_number_general=1; error_text[$error_number_general]="error_number_general"
error_number_lock_failed=2; error_text[$error_number_lock_failed]="Lock error_number_lock_failed"
error_number_received_signal=3; error_text[$error_number_received_signal]="error_number_received_signal"

# version argument
if [[ ${@} == "-v" || ${@} == "--version" ]]; then
    echo ${service_version}
    exit ${error_number_success}
fi

# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it such
# as in the --default example).
# note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )
while [[ $# -gt 1 ]]; do
    argument_key="$1"
    case $argument_key in
        -f|--frequency)
        attempt_frequency_seconds="$2"
        shift # past argument
        ;;
        -p|--paths)
        paths_to_synchronize_argument="$2"
        paths_to_synchronize=()
        old_ifs=$IFS
        IFS=","
        for path in ${paths_to_synchronize_argument[@]}; do
            paths_to_synchronize+=("${path}")
        done
        IFS=$old_ifs
        shift # past argument
        ;;
        -s|--source)
        source_volume_path_component="$2"
        shift # past argument
        ;;
        -d|--destination)
        rclone_destination="$2"
        shift # past argument
        ;;
        *)
        echo "[${service_name}] Ignoring invalid argument key ${argument_key} with value $2"
        ;;
    esac
    shift # past argument or value
done

# lock dirs/files
lock_directory_path="${TMPDIR}/${service_name}-lock"
pid_file_path="${lock_directory_path}/PID"

# argument defaults and enforcement
if [ -z "${attempt_frequency_seconds}" ]; then
    attempt_frequency_seconds=5 # default to 60 seconds frequency
fi
if [ -z "${source_volume_path_component}" ]; then
    echo "[${service_name}] Invalid source argument" >&2
    exit ${error_number_general}
fi
if [ -z "${rclone_destination}" ]; then
    echo "[${service_name}] Invalid destination argument" >&2
    exit ${error_number_general}
fi
if [ ${#paths_to_synchronize[@]} -eq 0 ]; then
    echo "[${service_name}] Invalid paths argument" >&2
    exit ${error_number_general}
fi

###
### synchronization functionality
###

function attempt_synchronization {

    source_volume_path=""
    mounted_volumes=$(mount)

    for token in $mounted_volumes; do
        if [[ ${token} == *"${source_volume_path_component}"* ]]; then
            source_volume_path=${token}
            break
        fi
    done

    if [ -z "${source_volume_path}" ]; then
        echo "[${service_name}] Source volume could not be found"
        attempt_synchronization_after_seconds ${attempt_frequency_seconds}
    fi

    for path in "${paths_to_synchronize[@]}"; do
        echo "[${service_name}] Synchronizing: ${path}"
        rclone sync "${source_volume_path}/${path}" ${rclone_destination}:"${path}"
    done

    attempt_synchronization_after_seconds ${attempt_frequency_seconds}
}

function attempt_synchronization_after_seconds {
    echo "[${service_name}] Waiting for ${1} seconds before synchronizing"
    sleep ${1}s
    attempt_synchronization
}

###
### start locking attempt
###

trap 'error_code=$?; echo "[${service_name}] Exit: ${error_text[error_code]}($error_code)" >&2' 0
echo -n "[${service_name}] Locking: " >&2

if mkdir "${lock_directory_path}" &>/dev/null; then

    # lock succeeded, install signal handlers before storing the PID just in case
    # storing the PID fails
    trap 'error_code=$?;
          echo "[${service_name}] Removing lock. Exit: ${error_text[error_code]}($error_code)" >&2
          rm -rf "${lock_directory_path}"' 0
    echo "$$" >"${pid_file_path}"

    # the following handler will exit the script upon receiving these signals
    # the trap on "0" (EXIT) from above will be triggered by this trap's "exit" command!
    trap 'echo "[${service_name}] Killed by a signal." >&2
          exit ${error_number_received_signal}' 1 2 3 15
    echo "Success, installed signal handlers"

    attempt_synchronization

else

    # lock failed, check if the other PID is alive
    other_pid="$(cat "${pid_file_path}")"

    # if cat isn't able to read the file, another instance is probably
    # about to remove the lock -- exit, we're *still* locked
    #  Thanks to Grzegorz Wierzowiecki for pointing out this race condition on
    #  http://wiki.grzegorz.wierzowiecki.pl/code:mutex-in-bash
    if [ $? != 0 ]; then
      echo "Lock failed, PID ${other_pid} is active" >&2
      exit ${error_number_lock_failed}
    fi

    if ! kill -0 $other_pid &>/dev/null; then
        # lock is stale, remove it and restart
        echo "[${service_name}] Removing stale lock of nonexistant PID ${other_pid}" >&2
        rm -rf "${lock_directory_path}"
        echo "[${service_name}] Restarting myself" >&2
        exec "$0" "$@"
    else
        # lock is valid and OTHERPID is active - exit, we're locked!
        echo "[${service_name}] Lock failed, PID ${other_pid} is active" >&2
        exit ${error_number_lock_failed}
    fi

fi
