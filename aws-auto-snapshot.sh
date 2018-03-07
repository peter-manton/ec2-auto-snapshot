#!/bin/bash

# EC2 Snapshot Utility 1.0
# Author: Peter Manton
# Performs snaphots of all of your EC2 instances volumes.
# TODO: Add rentention option (currently defaults to 7 days.)

# Define AWS CLI variables
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=

# Date vars
currentDay=$(date +%u)
declare -A daysofweek
daysofweek=( ["1"]="Monday" ["2"]="Tuesday" ["3"]="Wednesday" ["4"]="Thursday" ["5"]="Friday" ["6"]="Saturday" ["7"]="Sunday")

# Reporting vars
failedSnapshotRemovals=()
failedSnapshotCreations=()
SECONDS=0

printf "EC2 Snapshot Utility\n\n"

# Build a list of AWS instances
Instances=`/usr/bin/aws ec2 describe-instances | grep InstanceId | awk '{ print $2 }' | sed 's/"//g; s/,//g'`

# Create / delete snapshots for each instances volumes
while read -r instance; do
    # Obtain a list of volumes for this instance and duplicated information
    Volumes=`aws ec2 describe-volumes --region eu-west-1 --filters Name=attachment.instance-id,Values=$instance | grep VolumeId | awk '{ print $2 }' | sed 's/"//g; s/,//g' | xargs -n1 | sort -u | xargs -n 1`
    
    while read -r volume; do
		InstanceName=`aws ec2 describe-tags --filters Name=resource-id,Values=$instance Name=key,Values=Name --query Tags[].Value --output text`
		# Delete existing snapshots for the present day (if present)
		existingSnapshots=`aws ec2 describe-snapshots --filters Name=volume-id,Values=$volume Name=description,Values=*$currentDay* | grep SnapshotId  | awk '{ print $2 }' | sed 's/"//g; s/,//g' | xargs -n1 | sort -u | xargs -n 1`
		if [ ! -z "$existingSnapshots" ]
		then
			while read -r snapshot; do
				printf "Existing snapshot ($snapshot) found for $InstanceName / $volume - deleting it...\n"
				aws ec2 delete-snapshot --snapshot-id $snapshot
				if [ ! $? == 0 ]
					then
						failedSnapshotRemovals+=("$InstanceName / $volume")
				fi
					
			done <<< "$existingSnapshots"
		fi
		
		# Create new snapshot
		printf "Creating snapshot for $InstanceName / $volume\n\n"
		creationResult=`aws ec2 create-snapshot --volume-id $volume --description "Automated Snapshot (${daysofweek[$currentDay]}) for Instance: $InstanceName Volume ID: $volume"`
		if [ ! $? == 0 ]
			then
				failedSnapshotCreations+=("$InstanceName / $volume")
		fi
    done <<< "$Volumes"
done <<< "$Instances"

printf "Completed. Run time: $SECONDS.\n"
