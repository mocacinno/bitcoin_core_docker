# Developer Guide

This guide explains how developers can contribute to the Bitcoin Core Docker Compilation project.

## Setting Up Your Environment

1. **Install Docker**:

    Follow the official Docker installation guide for your operating system: [Install Docker](https://docs.docker.com/get-docker/).

2. **Fork the Repository**:
    - Go to the [GitHub repository](https://github.com/mocacinno/bitcoin_core_docker) and click on "Fork" to create a copy in your own GitHub account.

3. **Clone Your Fork**:

    ```bash
    git clone https://github.com/yourusername/bitcoin_core_docker.git
    cd bitcoin_core_docker
    ```

4. **Modify the Dockerfile**:
    - Switch to the branch for the version you're modifying: `git checkout v26.1`
    - Make your modifications to the Dockerfile in the version folder.

5. **Testing Your Changes**: Build and test the modified Docker image:

    ```bash
    docker build -t yourusername/btc_core:v26.1 .
    docker run -it yourusername/btc_core:v26.1 /bin/bash
    ```

6. **Commit Your Changes**:

    ```bash
    git add .
    git commit -m "Description of your changes"
    git push origin v26.1
    ```

7. **Create a pull request**:
    - Open a pull request from your fork to the original repository. Make sure to explain your changes clearly.
