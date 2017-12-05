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
FROM debian:jessie
LABEL maintainer="Joseph Holley joeholley@google.com"

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install openarena-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV WDIR /root/.openarena/baseoa
WORKDIR $WDIR
RUN mkdir -p $WDIR
ADD ./single-match.cfg $WDIR/single-match.cfg

RUN rm -rf /usr/share/games/openarena/baseoa

EXPOSE 27950/udp
EXPOSE 27960/udp

ENTRYPOINT ["/usr/games/openarena-server"]
CMD ["+exec", "single-match.cfg", "+set", "dedicated", "1", "+set", "net_port", "27961"]
