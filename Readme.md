# TL;DR; How to run

```bash
xauth list
# usually, the bottom line is your current display, copy the bottom line
docker run -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix --network=host --entrypoint /bin/bash -it ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.0_SLES16
init.sh
xauth add <output of xauth list, see step 1>
bitcoin
```
