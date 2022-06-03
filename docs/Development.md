# Development

## Working with the submodules

Clone the repository with submodules:

    git clone --recursive https://github.com/JaneliaSciComp/expansion-microscopy-pipeline.git

If you have already cloned the repository, run this after cloning to fetch the submodules:

    git submodule update --init --recursive

To update the external modules:

    git pull --recurse-submodules

To make changes to a submodule, cd into its directory and then checkout the master branch:

    cd external-modules/spark 
    git checkout master

Commit as normal, then back at the root update the submodule commit pointer and check it in:

    git submodule update --remote
    git commit external-modules/spark -m "Updated submodule to HEAD"


## Building containers

All containers used by the pipeline have been made available on Docker Hub. You can rebuild these to make customizations or to replace the algorithms used. To build the containers and push to Docker Hub you can install [maru](https://github.com/JaneliaSciComp/maru) and run `maru build`.


## Publishing containers

To push to Docker Hub, you need to login first:

    docker login

To push to AWS ECR, you need to login as follows:

    aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws

