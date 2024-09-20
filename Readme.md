# Bitcoin Core Docker Compilation Project

Welcome to the Bitcoin Core Docker compilation project repository! This repository documents the process of compiling all major versions of Bitcoin Core (from v0.2.8 to v27.1) inside a SLES 15 SP6 BCI_minimal container.

This project aims to make older Bitcoin Core versions available for use in specific scenarios like:

- Manipulating old wallets
- Learning and experimenting
- Analyzing feature changes over time
- Resolving community discussions
- Regression testing

Explore the documentation to get started:

- [Version Information](./versions/Readme.md): Details for each Bitcoin Core version compiled.
- [Developer Guide](./developers/Readme.md): Instructions for contributing to the project.
- [User Documentation](./userdocs/Readme.md): Guide for running the Docker images on your machine.

> **Disclaimer**: Do not run older versions on sensitive systems, do not run older versions in production, do not fund wallets generated with older versions... Even if you use the newest version, be carefull!!! Read the dockerfile and verify if the image you're pulling was generated using the dockerfile you signed off on, or (even better) use the Dockerfile you verified to build the image yourself... I do not take any responsability if you get into troubles running these images!!!

Happy experimenting!

-- Mocacinno
