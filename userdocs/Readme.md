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

1. **Running a full node**:
   In this usecase, we'll investigate how to run a full node, using the latest version available (currently v28.0) with persistent data (and wallet.dat) locations using our own entrypoint script...

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

## Building the Docker Image Yourself

1. **Clone the Repository**:

    ```bash
    git clone https://github.com/mocacinno/bitcoin_core_docker.git
    cd bitcoin_core_docker
    ```

2. **Build the image**:

    ```bash
    docker build -t my_btc_core:v27.1 .
    ```
