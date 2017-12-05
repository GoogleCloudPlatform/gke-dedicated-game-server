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

# Default Openarena port.
DEFAULT_PORT=27961

# Check for kubectl in local path.
command -v kubectl >/dev/null 2>&1 || { echo >&2 "Command kubectl required in $PATH to use this script, exiting"; exit 1; }

# Loop 15 times, start one pod every ~20 seconds.
for i in $(seq 1 15); do
  NEW_PORT=`expr ${DEFAULT_PORT} + ${i}` 
  echo "Starting 'openarena.dgs.${i}' DGS pod on port ${NEW_PORT} (replaces any exising pod with the same name)"
  kubectl delete pods openarena.dgs.$i 2>&1 | grep -v "NotFound"
  sleep 20 
  sed "s/openarena\.dgs/openarena.dgs.$i/g" "$( cd $(dirname $0) ; \
    pwd -P )/../../openarena/k8s/openarena-pod.yaml" | 
    sed -e "s/${DEFAULT_PORT}/${NEW_PORT}/g" | kubectl apply -f -
done
