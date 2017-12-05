#!/bin/bash
# Copyright 2017 Google LLC All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This is a very naive script, and can encounter a number of edge cases (pods
# stuck in pending state, nodes not starting correctly, frequent scaling events, 
# etc). It is only provided as an example and should be expanded significantly 
# before use in a production environment.

# Config vars. Set in the container environment.
REQ_VARS=("K8S_CLUSTER"
          "GKE_BASE_INSTANCE_NAME"
          "GCP_ZONE")
for VAR in "${REQ_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo -n "ERROR: All of the following environment vars must "
    echo "be set to use this script:"
    echo "${REQ_VARS[@]}" | tr ' ' '\n'
    exit 1
  fi
done

# Usage and scaling targets and thresholds. 
# Override defaults by setting these variables in the container environment.
TARGET_USAGE="${TARGET_USAGE:-60}" # When scaling, target this amount of usage
USAGE_MIN="${USAGE_MIN:-40}" # If total usage is less than this, scale down
USAGE_MAX="${USAGE_MAX:-70}" # If total usage is greater than this, scale up
NODES_MIN="${NODES_MIN:-3}"  # Don't scale below this number of nodes
NODES_MAX="${NODES_MAX:-10}" # Don't scale above this number of nodes

# Filters
GAME="${GAME:-openarena}"
ROLE="${ROLE:-dgs}"

# Output format for gcloud
# https://cloud.google.com/sdk/gcloud/reference/topic/projections
NAME_ONLY="table[no-heading](NAME)"
MACHINE_TYPE_ONLY="table[no-heading](MACHINE_TYPE)"

# Init. Assumes homogeneous GKE node pool.
echo "Initializing..."
/usr/bin/gcloud config set compute/zone ${GCP_ZONE} 
CPUS_PER_NODE=$(gcloud compute instances list \
  --filter="name~'.*${K8S_CLUSTER}.*'" \
  --limit=1 --format="${MACHINE_TYPE_ONLY}" | cut -d'-' -f3 ) 

# Loop forever.
while true; do

  echo -n "Gathering GKE node info... "
  NODE_INFO=( $(gcloud compute instance-groups managed \
    list-instances ${GKE_BASE_INSTANCE_NAME}-grp \
    --format="${NAME_ONLY}") )
  NUM_NODES=${#NODE_INFO[@]}
  NUM_CPUS=$(( ${CPUS_PER_NODE} * ${NUM_NODES} ))
  echo "${CPUS_PER_NODE} cores, ${NUM_NODES} VMs. Total cores: ${NUM_CPUS}"

  echo -n "Gathering kubernetes pod info... "
  NUM_DGS_PODS=$(/usr/bin/kubectl get pods -l game=${GAME},role=${ROLE} \
    --no-headers | wc -l)
  if [ -n "${NUM_DGS_PODS}" ]; then
    echo -n "DGS Pods: ${NUM_DGS_PODS}"
    echo # Force newline

    echo -n "(current config: min ${USAGE_MIN} | "
    echo -n "target ${TARGET_USAGE} | max ${USAGE_MAX}) "
    echo -n "Calculating usage ... "
    NODE_USAGE=0 
    # Slightly complicated since bash doesn't support floating point arithmetic.
    if (( ${NUM_DGS_PODS} > 0 )); then
      NODE_USAGE=$(echo \(${NUM_DGS_PODS} \/ ${NUM_CPUS}\) \* 100 \
        | bc -l | cut -d'.' -f1) 
    fi  
    TARGET_NODE_NUM=$(echo ${NUM_DGS_PODS} \/ \
      \( ${CPUS_PER_NODE} \* \( ${TARGET_USAGE} \/ 100 \) \) + 1 \
      | bc -l | cut -d'.' -f1)

    # If bc didn't return anything, default to doing nothing (set target number
    # equal to current number)
    TARGET_NODE_NUM="${TARGET_NODE_NUM:-${NUM_NODES}}"

    # Clamp target number of nodes within bounds
    if   (( ${TARGET_NODE_NUM} < ${NODES_MIN} )); then
      TARGET_NODE_NUM=${NODES_MIN}
    elif (( ${TARGET_NODE_NUM} > ${NODES_MAX} )); then
      TARGET_NODE_NUM=${NODES_MAX}
    fi
    
    echo "NODE USAGE: ${NODE_USAGE}%"
    echo -n "Checking if resize of cluster ${K8S_CLUSTER} is necessary..."

    # Short-circut check; no need to do all this work if already have the
    # desired number of nodes!
    if (( ${TARGET_NODE_NUM} != ${NUM_NODES} )); then

      if (( ${NODE_USAGE} >= ${USAGE_MAX} && 
            ${TARGET_NODE_NUM} <= ${NODES_MAX} )); then
        # Scaling up 
        echo "Setting number of nodes in to ${TARGET_NODE_NUM}"
        /usr/bin/gcloud compute instance-groups managed \
          resize ${GKE_BASE_INSTANCE_NAME}-grp --size=${TARGET_NODE_NUM}

      elif (( ${NODE_USAGE} <= ${USAGE_MIN} && 
              ${TARGET_NODE_NUM} >= ${NODES_MIN} )); then
        # Scaling down.  Very naive; doesn't evaluate for best node to remove, just
        # always chooses the first node from the list returned by gcloud. 
        NUM_TO_REMOVE=$(( ${NUM_NODES} - ${TARGET_NODE_NUM} ))
        NODES_TO_REMOVE=$(/usr/bin/gcloud compute instance-groups managed \
          list-instances ${GKE_BASE_INSTANCE_NAME}-grp \
          --format=${NAME_ONLY} --limit=${NUM_TO_REMOVE})

        for NODE_TO_REMOVE in ${NODES_TO_REMOVE}; do
          echo "Setting node ${NODE_TO_REMOVE} to be removed."
          /usr/bin/gcloud compute instance-groups managed \
            abandon-instances ${GKE_BASE_INSTANCE_NAME}-grp \
            --instances=${NODE_TO_REMOVE} &
          # K8S nodes that aren't properly flagged as unschedulable won't be
          # stopped by the node stopper script, so do a naive 5 min loop to ensure 
          for i in $(seq 1 1000); do if (kubectl cordon ${NODE_TO_REMOVE}); then break; fi; sleep 3; done &
        done

        # Give some time for background processes to complete before looping.
        sleep 30 

      else
        # Target number of nodes not within the min/max range. 
        echo -n "No! Sleeping."
      fi

    else
      # Already have the desired number of nodes. 
      echo -n "No! Sleeping."
    fi

  else
    # Found 0 DGS pods...
    echo -n "WARNING: No DGS pods detected or unable to contact the K8S API!"
  fi
  echo
  echo "Sleeping..."
  sleep 15
done
