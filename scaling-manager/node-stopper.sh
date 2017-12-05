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
# This is a very naive script, and can encounter a number of edge cases (API
# timeouts, frequent scaling events,  etc). 
# It is only intended as an example and should be expanded significantly 
# before use in a production environment.
# It should be tested only in a safe environment as it is capable of many
# potentially disruptive actions!

# Config vars. Set env vars in the container environment.
REQ_VARS=("K8S_CLUSTER" 
          "GKE_BASE_INSTANCE_NAME"
          "GCP_ZONE")
for VAR in "${REQ_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo -n "ERROR: All of the following environment vars must be set to use "
    echo "this script:"
    echo "${REQ_VARS[@]}" | tr ' ' '\n'
    exit 1
  fi
done

/usr/bin/gcloud config set compute/zone ${GCP_ZONE}

# Pod filters
GAME="${GAME:-openarena}"
ROLE="${ROLE:-dgs}"

# Output format for gcloud
# https://cloud.google.com/sdk/gcloud/reference/topic/projections
NAME_ONLY="table[no-heading](NAME)"

# Loop forever.
while true; do
  echo "Getting list of nodes from k8s and GKE... "
  ALL_K8S_NODES=( $(gcloud compute instances list \
    --filter="Name ~ ^${GKE_BASE_INSTANCE_NAME} AND status:RUNNING" \
    --format="${NAME_ONLY}") )
  MIG_NODES=( $(gcloud compute instance-groups managed \
    list-instances ${GKE_BASE_INSTANCE_NAME}-grp \
    --format="${NAME_ONLY}") )
  
  # Diff the two node lists to find running nodes no longer in the MIG
  # ('abandoned' nodes)
  if (( "${#ALL_K8S_NODES[@]}" > "${#MIG_NODES[@]}" )); then
    echo -n "Checking for nodes abandoned from the managed instance group "
    echo "${GKE_BASE_INSTANCE_NAME}-grp... "
    ABANDONED_NODES=( $(echo ${MIG_NODES[@]} ${ALL_K8S_NODES[@]} \
      | tr ' ' '\n' | sort | uniq -u) )
    
    if [ -n "${ABANDONED_NODES}" ]; then
      # Get lists of nodes with and without running pods
      echo "Abandoned nodes found:"
      echo "${ABANDONED_NODES[@]}" | tr ' ' '\n'
      echo -n "Checking if ${#ABANDONED_NODES[@]} abandoned nodes have "
      echo "finished running all dgs pods... "
      ACTIVE_NODES=$(kubectl get pods -l game=${GAME},role=${ROLE} -o wide \
        --no-headers 2>/dev/null | awk '{print $7}' | sort -u)
      INACTIVE_NODES=$(echo ${ALL_K8S_NODES[@]} ${ACTIVE_NODES[@]} \
        | tr ' ' '\n' | sort | uniq -u)
      
      # Get all abandoned nodes with no running pods 
      NODES_TO_STOP=$(echo ${ABANDONED_NODES[@]} ${INACTIVE_NODES[@]} \
        | tr ' ' '\n' | sort | uniq -d) 
      
      if [ -n "${NODES_TO_STOP}" ]; then
        echo
        for NODE in ${NODES_TO_STOP}; do
          if kubectl get nodes ${NODE} 2>&1 | egrep -q '(SchedulingDisabled|NotFound)'; then 
            echo "Found empty node ${NODE}! Attempting to stop..."
            echo kubectl delete node ${NODE} 
            kubectl delete node ${NODE} &
            # Change 'stop' to 'delete' to completely remove VM instance instead
            # of just terminating it
            echo gcloud --quiet compute instances stop ${NODE}
            gcloud --quiet compute instances stop ${NODE} &
          else
            (>&2 echo "WARNING: Node ${NODE} not cordoned! Taking no action.")
          fi
        done

        # Wait for background processes to return before continuing
        echo "Waiting for actions to complete..."
        wait 
      fi
    fi
  fi
  echo
  echo "Sleeping..."
  sleep 30
done
