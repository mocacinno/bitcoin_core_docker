# Welcome to the Bitcoin Core Docker Compilation Project

This repository serves as a comprehensive archive of all major versions of Bitcoin Core, from **v0.2.8** (released in 2009) to **v27.1**. Inside this repository, you will find the docker images of each version as well as the documentation and tools needed to compile these versions in a **SLES 15 SP6 BCI_minimal** container (usually in the form of a Dockerfile).

This project provides a historical snapshot of Bitcoin Core's development over the years and aims to be a valuable resource for the community in various scenarios, including but not limited to:

## Use Cases

- **Manipulating Old Wallets:** Restore or experiment with older wallet formats that may not be compatible with modern software versions.
- **Learning & Experimenting:** Study how Bitcoin Core has evolved, experiment with old versions, and test them in a contained environment.
- **Analyzing Feature Changes Over Time:** Track the introduction, modification, or deprecation of key features across different Bitcoin Core releases.
- **Resolving Community Discussions:** Refer to exact Bitcoin Core versions when participating in technical debates or contributing to community discussions.
- **Regression Testing:** Use older versions for regression tests when developing or maintaining Bitcoin-related software.
- **Security Audits:** Review historical releases for vulnerabilities or study security improvements introduced over time.
- **Forensics & Incident Analysis:** Investigate specific incidents that occurred in the past, such as blockchain reorganizations or transaction malleability, by running the software from that time.
- **Historical Blockchain Exploration:** Sync and explore the Bitcoin blockchain as it appeared when these older versions were released.
- **Compatibility Checks:** Test the backward and forward compatibility of applications, libraries, and tools interacting with Bitcoin Core.
- **Developer Reference:** Access a readily available reference for how the software was built and configured in earlier times.

This archive stands as a testament to Bitcoin's robust and evolving codebase, providing developers and enthusiasts with invaluable insights into the project's technical journey.

## shortcuts

Explore the documentation to get started:

- [Version Information](./versions/Readme.md): Details for each Bitcoin Core version compiled.
- [Developer Guide](./developers/Readme.md): Instructions for contributing to the project.
- [User Documentation](./userdocs/Readme.md): Guide for running the Docker images on your machine.
- [sponsor, tip](./tip.md)

> **Disclaimer**: Do not run older versions on sensitive systems, do not run older versions in production, do not fund wallets generated with older versions... Even if you use the newest version, be carefull!!! Read the dockerfile and verify if the image you're pulling was generated using the dockerfile you signed off on, or (even better) use the Dockerfile you verified to build the image yourself... I do not take any responsability if you get into troubles running these images!!!

Happy experimenting!

-- Mocacinno
