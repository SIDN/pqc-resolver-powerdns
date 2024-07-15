# PowerDNS recursive resolver with support for PQC algorithms

This repository contains the scripts to build PowerDNS Recursor server with for support quantum-safe algorithm.

Currently, we supported both Falcon512, SQIsign1 and Mayo2.

> [!CAUTION]
> This software is experimental and not meant to be used in production. Use this software at your own risk.

## Building the image

To build the image, run this (simplified) command:

	podman build -f Dockerfile --tag=resolver-powerdns:latest

The tag is an example, just make sure you can find the image again for running the image as container.

## Example 

A minimal working example of running the image is included in the directory example.
It should how to build a container running example.nl.
You can build it as follows:

	podman build -f example/Dockerfile --tag=patad-test-resolver-sqisign
	podman run --rm -d -p 5300:53/udp -p 5300:53/tcp patad-test-resolver-sqisign
	
And you can confirm it works on a regular domain name:

	dig example.nl -p 5300 @localhost 

To test the PQC algorithm support, please refer to our [testbed repository for an example]().

## Updating patch PowerDNS

Browse to SIDN Labs PowerDNS repository.
Then, for example:
    
    git checkout falcon-sqisign-20240315
    git diff auth-4.8.3 > /tmp/patch-4.8.3.diff

Then, move the patch file to the correct directory.
