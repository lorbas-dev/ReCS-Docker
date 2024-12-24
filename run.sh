#!/bin/bash
docker run -it --name="hlds" -p 27015:27015 -p 27015:27015/udp hlds_deploy
