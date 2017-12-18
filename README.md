# Running Dedicated Game Servers in Kubernetes Engine

This is a repository with sample code to go along with the tutorial at 
https://cloud.google.com/solutions/gaming/running-dedicated-game-servers-in-kubernetes-engine
and is provided for reference. It is not intended to be used in production, but to
serve as a learning tool and starting point for running dedicated game servers
in GKE.

## Prerequisites
- The tutorial assumes you are using GKE. Users with a moderate amount of
  experience with Docker and Kubernetes can probably modify it to operate in
  other environments with a little work.
- Building docker images from the provided `Dockerfile`s requires an environment 
  with Docker installed as per the 
  [Docker documentation](https://docs.docker.com/engine/installation/).
- If you want to test a connection to the OpenArena server running on GKE at the
  end of the tutorial, you'll need to
  [install the OpenArena client](http://openarena.wikia.com/wiki/Manual/Install).

## Componenets

### OpenArena server

This tutorial includes example Dockerfiles and Kubernetes resource definitions
(in YAML format) that can be used to containerize the OpenArena server and run
it as a pod on GKE.

### Scaling Manager

These two scripts are used to scale up and down the number of nodes in the GKE
cluster as outlined in the tutorial. Dockerfiles and Kubernetes resource
definitions (in YAML format) are included to containerize these scripts and run
them as a deployment on GKE.
