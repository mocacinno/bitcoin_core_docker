# User Documentation

This guide will help users set up Docker and run the Bitcoin Core images provided in this repository.

## Setting Up Docker

1. **Install Docker**:
   Follow the [official installation guide](https://docs.docker.com/get-docker/) to install Docker on your machine.

2. **Run the Container**:
   To run the Bitcoin Core container, use the following command:

   ```bash
   docker run -it mocacinno/btc_core:v27.1
   ```

3. **Persist Data**:
    To persist the data from within the container's /root/.bitcoin folder, use a Docker volume:

    ```bash
    docker run -it -v /local/path/to/bitcoin:/root/.bitcoin mocacinno/btc_core:v27.1
    ```

4. **Disable Networking**:
    If you want to start an isolated bitcoind without network access:

    ```bash
    docker run -it --network none mocacinno/btc_core:v27.1
    ```

## Use cases

### **Running a full node**

   In this usecase, we'll investigate how to run a full node, using the latest version available (currently v28.0) with persistent data (and wallet.dat) locations using our own entrypoint script...

   ***Warning***

   BEFORE running any container (including this one), it might be a good idear to validate the content of the image (and even better build it yourself)!!! In order to do so, read the next chapter (validate and build your own image)

   ```bash
   #add any command to entrypoint.sh that needs to be executed, "bitcoind -daemon &" is usually a good starting point. I use vi here, but you can use any editor you like
   vi entrypoint.sh
   #make entrypoint.sh executable
   chmod +x entrypoint.sh
   #make a directory to store all blockchain data and wallets for persistence
   mkdir mybtcdata
   #run the actual command, map mybtcdata directory, map entrypoint.sh, make sure entrypoint.sh is used as en entrypoint and make sure you start detached
   docker run --privileged -v /root/mybtcdata:/root/.bitcoin -v $(pwd)/entrypoint.sh:/entrypoint.sh --entrypoint /entrypoint.sh -d  mocacinno/btc_core:v28.0 
   #you can use the same way to inject a custom bitcoin.conf, just create one locally and add "-v $(pwd)/bitcoin.conf:/root/.bitcoin/bitcoin.conf" to the docker command
   ```

   <link rel="stylesheet" href="https://mocacinno.com/asciinema-player.css">
   <div id="fullnode"></div>
   <script src="https://mocacinno.com/asciinema-player.min.js"></script>
   <script>
      AsciinemaPlayer.create('casts/fullnode.cast', document.getElementById('fullnode'));
   </script>

### **validate and build your own image**

   It's never a good idear to blindly run images from anybody... even if you trust them. It's actually pretty simple to validate and build these images yourself!!!

   **option 1: use github actions**
   my [repo](https://github.com/mocacinno/bitcoin_core_docker) actually uses github actions to automatically build every time i push any changes to any branch... Offcourse, the images are not pushed to dockerhub, but to ghcr.io (github's own image repo). If you just clone my repo, and make sure all permissions are set correctly, you could just switch to the branch you want to build, verify the Dockerfile inside this branch, then modify the .actiontrigger file off this branch, and github will just build the image for you... After 10-20 minutes, you'll see a "packages" link on the left menu on your public repo page, and all built images will be stored here... Quick and easy :)

   **option 2: build it yourself**
   This option isn't that hard either... You need a running docker (or podman) on a linux host, preferably with buildx installed (not tested, but it should also work without buildx).

   ```bash
   git clone https://github.com/mocacinno/bitcoin_core_docker
   cd bitcoin_core_docker
   git switch v28.0
   vi Dockerfile
   docker build  -t btc_core:v28.0 .
   docker run --entrypoint /bin/bash --network none -it btc_core:v28.0
   ```

   <div id="build_image"></div>
   <script>
      AsciinemaPlayer.create('casts/build_image.cast', document.getElementById('build_image'));
   </script>
