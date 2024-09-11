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
