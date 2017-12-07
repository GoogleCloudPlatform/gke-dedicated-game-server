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
DOCKERFILES=$( ls Dockerfile.* | cut -d'.' -f2 )

if [ -z "${PROJECT_ID}" -o -z "${GCR_REGION}" ]; then
  echo -n "This script requires the GCR_REGION and PROJECT_ID environment "
  echo -n "variables to determine the target gcr.io registry: "
  echo '${GCR_REGION}.gcr.io/${PROJECT_ID}/'
  echo "More details at: "
  echo -n "https://cloud.google.com/container-registry/"
  echo "docs/pushing-and-pulling#choosing_a_registry_name"
  exit 1
fi

for FILE in ${DOCKERFILES}; do
  docker build -f \
    Dockerfile.${FILE} -t ${GCR_REGION}.gcr.io/${PROJECT_ID}/${FILE}:latest .
  gcloud docker -- push ${GCR_REGION}.gcr.io/${PROJECT_ID}/${FILE}:latest
done
