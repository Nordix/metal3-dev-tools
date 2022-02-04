# Description of combined Ironic and IPA build process

## Abreviations

- OCI (compatible format) - Open Container Initiative (compatible format)
- cluster - Kubernetes cluster
- IPA - Ironic Python Agent
- Artifactory - https://jfrog.com/artifactory/
- Harbor - https://goharbor.io/
- Jenkins - https://www.jenkins.io/

## High level overview of the build pipeline
The goal of the combined Ironic and IPA build pipeline is to build and test the two components together thus verify that given version of IPA and Ironic are
compatible. In case of a successful build both a versioned archive of IPA and a versioned OCI container image of Ironic will be generated and they will be
stored according the current artifact retention policy.

There are two pipelines related to the combined Ironic and IPA build process, one of them is called
`metal3_master_openstack_ipa_and_ironic_image_building` that can be found [here](https://jenkins.nordix.org/view/Metal3/job/metal3_master_openstack_ipa_and_ironic_image_building/).
The other one is the `metal3_openstack_ipa_and_ironic_image_building` and that is [here](https://jenkins.nordix.org/view/Metal3/job/metal3_openstack_node_image_building/).
The difference between the two jobs is related to their trigger mechanism. `metal3_master_openstack_ipa_and_ironic_image_building` is triggered periodically, manually and whenever there is
a change in `metal3-dev-tools` repository. `metal3_openstack_ipa_and_ironic_image_building` is used to test `GitHub` pull requests and the job is triggered by
commenting `/test-ipa` on a pull request.

The JJB configurations for the jobs are located in [Nordix gerrit](https://gerrit.nordix.org/infra/cicd) and inside the repository
the files are located at `jjb/metal3/job_ipa_image_building.yml` for `metal3_master_openstack_ipa_and_ironic_image_building` and at `jjb/metal3/job_ipa_image_building_test.yml` for `metal3_openstack_ipa_and_ironic_image_building`.

The pipeline script has only a single stage that starts a wrapper script that runs on a `static worker VM` and the wrapper script will
bootstrap the VM that will actually build and test both IPA and Ironic. The wrapper script is located at
`ci/scripts/image_scripts/start_centos_ipa_ironic_build.sh`.

After the wrapper script has bootstrapped the builder VM it will first copy the Ironic build script from the `static worker VM` to the `builder VM` and the
Ironic build will be started on the `builder VM`. The script that builds the Ironic container image is located at
`ci/scripts/image_scripts/run_build_ironic.sh`. The script that builds the IPA and runs the combined test of the previously built Ironic and IPA components is
located at `ci/scripts/image_scripts/build_ipa.sh`

## Ironic build

This script can be configured to build the a specific version of the Ironic container image based on a git `refspec` specified by the `IRONIC_REFSPEC` environment
variable.

The build process consists of the following steps:

1. The specified version of the [ironic repository](https://review.opendev.org/openstack/ironic) is cloned and a container image tag is created out of the
git `sha` hash of the commit referenced by the `HEAD` pointer on the current branch.

2. The docker image tag is saved to `/tmp/vars.sh` on the builder vm to be used during the combined testing of IPA and Ironic.

3. The script checks whether there is a ironic image in [nordix harbor](https://registry.nordix.org/harbor) with the same name and image tag and if not then the build process will continue.

4. In case the build process continues the script will rely on upstream [patch-image.sh](https://github.com/metal3-io/ironic-image/blob/main/patch-image.sh) to patch the [ironic image](https://github.com/metal3-io/ironic-image/blob/main/Dockerfile). First the patch file is constructed then the docker image will be built
and the path to the patch file will be supplied with the `docker build` command's `--build-arg` option.

5. When the build process succeeds the newly created OCI image will be uploaded to nordix harbor.

## IPA build
The goal of the IPA build process is to create a custom `.tar` archive that contains the linux kernel and the rootfs image that make up an IPA instance. The
resulting IPA `.tar` archive is uploaded to [nordix artifactory](https://artifactory.nordix.org/)

The IPA build process uses the python tool called [IPA builder](https://github.com/Nordix/ironic-python-agent-builder.git) to build a selected version of
[IPA](https://github.com/Nordix/ironic-python-agent). The version of the IPA repository tha will be built is specified via the `IPA_REF` and the `IPA_BRANCH` environment variables. The `IPA_BRANCH`specifies what branch of IPA will be used during the build and the `IPA_REF` specifies the git commit hash that is used to select a specific version of the repository on the branch. By using the Nordix fork of the IPA repository and custom commit hash and branch name it is possible to build versions of ipa that are not part of the [upstream IPA repository](https://opendev.org/openstack/ironic-python-agent).

The build process consists of the following steps:

1. Create a working directory and clone both the IPA and IPA builder repositories

2. Create an indentifier tag from `ISO 8061` timestamp an IPA's git commit `sha hash`

3. Install the dependencies and the IPA builder tool to a python virtual environment

4. Build the IPA initramfs and kernel images in the python virtual environment then exit the virtual environment

5. Package the initramfs and kernel images to a tar archive

6. Check the size of the archive

7. Clone the [metal3-dev-env](https://github.com/Nordix/metal3-dev-env) and use it to test whether the newly built IPA is compatible with the previously built
Ironic version

8. When the combined IPA and Ironic test succeeds IPA archive will be uploaded to Nordix artifactory


## Combined IPA and Ironic testing

As it was already mentioned as the 7. step of the IPA build process the newly built IPA and Ironic images are tested together with the help of the
[metal3-dev-env](https://github.com/Nordix/metal3-dev-env). The test process has two major parts the first one just simply bootstraps a development environment
using IPA and Ironic it is done by executing the `make` command in metal3-dev-env that will bootstrap a cluster (bootstrap cluster) that will serve as the test
environment. After the environment setup has been successful then with the `make test` command the build script executes the `05_test.sh` and that will run the
ansible based test process.

The process started by the `make test` command will provision control plane and worker nodes for a new cluster (target cluster) then it will also test
deprovisioning of both the nodes and the control plane of the target cluster and it will also test pivoting to the target cluster and pivoting back to the
bootstrap cluster.

## Artifact storage and retention

As part of 5. step of the Ironic build process the versioned ironic OCI images are uploaded to [this repository](https://registry.nordix.org/harbor/projects/10/repositories/ironic-image).

All of the IPA images are stored in Nordix Artifactory at this [location](https://artifactory.nordix.org/artifactory/airship/images/ipa) and under these location
the IPA artifacts are grouped into different groups based on their characteristics.
The versioned IPA images are sorted to different groups, the artifacts are grouped based on what Linux distribution is used as a base image, the grouping also
takes into consideration the version of the distribution and whether the artifact was created as part of a review process or is it already in a finalized format
called staging.

Example of the location of a `Centos 8 Stream` based staging and review artifacts:

  - review: https://artifactory.nordix.org/artifactory/airship/images/ipa/review/centos/8-stream/20210908T1017Z-2acdf3c
  - staging:  https://artifactory.nordix.org/artifactory/airship/images/ipa/staging/centos/8-stream/20210918T0020Z-47a7fb5

As an example shows the directory structure is the following: `ipa/<staging or review>/<linux distribution>/<distribution version>/<artifact version>`

# Metadata and customization

The pipeline that handles the IPA and Ironic build offers a number of customization options:

  - `IRONIC_REFSPEC`: Gerrit refspec of the patch we want to test. `Example: refs/changes/84/800084/22`
  - `IRONIC_IMAGE_REPO_COMMIT`: Ironic Image repository commit hash to build
  - `IRONIC_IMAGE_BRANCH`: Ironic image repository branch to build
  - `IRONIC_INSPECTOR_REFSPEC`: Gerrit refspec of the patch we want to test. `Example: refs/changes/84/800084/22`
  - `BMO_BRANCH`: Git branch of the BMO repository to be used
  - `BMO_COMMIT`: Git commit of the BMO repository to be used
  - `IPA_COMMIT`: Ironic Python Agent repository commit hash to build
  - `IPA_BRANCH`: Ironic Python Agent repository branch to build
  - `IPA_BUILDER_BRANCH`: Ironic Python Agent builder repository tool branch
  - `IPA_BUILDER_COMMIT`: Ironic Python Agent builder repository tool commit
  - `METAL3_DEV_ENV_BRANCH`: Metal3 dev env repository branch
  - `METAL3_DEV_ENV_COMMIT`: Metal3 dev env repository commit
  - `STAGING`: Configures IPA builder upload mode (staging/review)

The custumization options provide git branch, commit and refspec customization options in case of a manually triggered IPA-Ironic build job.
There is one additional type of custumization option that is called `STAGING` this controls whether the IPA artifact will be uploaded to
`Artifactory` as part of a review or a staging group.

The IPA build script also creates a metadata file and packages into the IPA `.tar` archive. The metadata file contains git metadata
such as repositories, branches and commit hashes and in some cases refspec and container image version for components used for
Ironic and IPA build.

Metadata is generated for the following components:
 - IPA builder
 - IPA
 - Ironic-image
 - Ironic-inspector
 - Ironic
 - Metal3-dev-env
 - BMO
 - CAPI
 - CAPM3