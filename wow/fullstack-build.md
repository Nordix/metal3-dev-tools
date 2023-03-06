# Description of combined Ironic and IPA build process

## Abreviations

- OCI (compatible format) - Open Container Initiative (compatible format)
- cluster - Kubernetes cluster
- IPA - Ironic Python Agent
- Artifactory - https://jfrog.com/artifactory/
- Harbor - https://goharbor.io/
- Jenkins - https://www.jenkins.io/

## High level overview of the build pipeline
The goal of the combined fullstack build pipeline is to build from source and test the all Metal3 and Openstack-Ironic components together thus verify that given version of
IPA, Ironic, BMO, CAPI, CAPM3, IPAM are compatible. In case of a successful build both a versioned archive of IPA and a versioned OCI container image of Ironic will be
generated and they will be stored according the current artifact retention policy.

There are two pipelines related to the combined Fullstack build process, one of them is called
`metal3_main_fullstack_building` that can be found [here](https://jenkins.nordix.org/view/Metal3%20Periodic/job/metal3_daily_main_fullstack_building/).
The other one is the `metal3_fullstack_building` and that is [here](https://jenkins.nordix.org/view/Metal3/job/metal3_fullstack_building_test/).
The difference between the two jobs is related to their trigger mechanism. `metal3_main_fullstack_building` is triggered periodically, manually and whenever there is
a change in `metal3-dev-tools` repository. `metal3_fullstack_building` is used to test `GitHub` pull requests and the job is triggered by
commenting `/test-metal3-fullstack` on a pull request.

The JJB configurations for the jobs are located in [Nordix gerrit](https://gerrit.nordix.org/infra/cicd) and inside the repository
the files are located at `jjb/metal3/job_fullstack_building.yml` for `metal3_main_fullstack_building` and at
`jjb/metal3/job_fullstack_building_test.yml` for `metal3_fullstack_building`.

The pipeline script has only a single stage that starts a wrapper script that runs on a `static worker VM` and the wrapper script will
bootstrap the VM that will actually build and test both the whole stack. The wrapper script is located at
`ci/scripts/image_scripts/start_centos_fullstack_build.sh`.

After the wrapper script has bootstrapped the builder VM it will first copy the Ironic build script from the `static worker VM` to the `builder VM` and the
Ironic build will be started on the `builder VM`. The script that builds the Ironic container image is located at
`ci/scripts/image_scripts/run_build_ironic.sh`. The script that builds the IPA and runs the combined test of the previously built Ironic and IPA components is
located at `ci/scripts/image_scripts/build_ipa.sh` and this script can and by default will build also CAPM3, IPAM, BMO from source and there is also an option
to build CAPI locally from source in case the build is executed manually from Jenkins webUI.

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

The IPA build process uses the python tool called [IPA builder](https://opendev.org/openstack/ironic-python-agent-builder) to build a selected version of
[IPA](https://github.com/Nordix/ironic-python-agent). The version of the IPA repository that will be built is specified via the `IPA_REF` and the `IPA_BRANCH` environment variables. The `IPA_BRANCH`specifies
what branch of IPA will be used during the build and the `IPA_REF` specifies the git commit hash that is used to select a specific version of the repository on the branch. By using the Nordix fork of the IPA
repository and custom commit hash and branch name it is possible to build versions of ipa that are not part of the [upstream IPA repository](https://opendev.org/openstack/ironic-python-agent).

The build process consists of the following steps:

1. Create a working directory and clone both the IPA and IPA builder repositories

2. Create an indentifier tag from `ISO 8061` timestamp an IPA's git commit `sha hash`

3. Install the dependencies and the IPA builder tool to a python virtual environment

4. Build the IPA initramfs and kernel images in the python virtual environment then exit the virtual environment

5. Package the initramfs and kernel images to a tar archive

6. Check the size of the archive

7. Clone the [metal3-dev-env](https://github.com/Nordix/metal3-dev-env) and use it to test whether the newly built IPA is compatible with the previously built
Ironic, CAPI, CAPM3, IPAM, BMO

8. When the combined IPA and Ironic test succeeds IPA archive will be uploaded to Nordix artifactory


## Combined IPA and Ironic testing

As it was already mentioned as the 7. step of the IPA build process the newly built IPA and Ironic images are tested together with the help of the
[metal3-dev-env](https://github.com/metal3-io/metal3-dev-env.git). The test process has two major parts the first one just simply bootstraps a development environment
using IPA and Ironic it is done by executing the `make` command in metal3-dev-env that will bootstrap a cluster (bootstrap cluster) that will serve as the test
environment. The bootstrap process of the dev-ev also handles the building of images (e.g. CAPI, CAPM3, IPAM, BMO) according to the implementation in the `02_configure_host.sh` script of dev-env.
After the environment setup has been successful then with the `make test` command the build script executes the `05_test.sh` and that will run the
ansible based test process.

The process started by the `make test` command will provision control plane and worker nodes for a new cluster (target cluster) then it will also test
deprovisioning of both the nodes and the control plane of the target cluster and it will also test pivoting to the target cluster and pivoting back to the
bootstrap cluster.

## Artifact storage and retention

As part of 5. step of the Ironic build process the versioned ironic OCI images are uploaded to [this repository](https://registry.nordix.org/harbor/projects/10/repositories/ironic-image).

All of the IPA images are stored in Nordix Artifactory at this [location](https://artifactory.nordix.org/artifactory/metal3/images/ipa) and under these location
the IPA artifacts are grouped into different groups based on their characteristics.
The versioned IPA images are sorted to different groups, the artifacts are grouped based on what Linux distribution is used as a base image, the grouping also
takes into consideration the version of the distribution and whether the artifact was created as part of a review process or is it already in a finalized format
called staging.

Example of the location of a `Centos 9 Stream` based staging and review artifacts:

  - review: https://artifactory.nordix.org/artifactory/metal3/images/ipa/review/centos/9-stream/20230112T0701Z-06413e5/
  - staging: https://artifactory.nordix.org/ui/native/metal3/images/ipa/staging/centos/9-stream/20221228T0412Z-5c0eab3/

As an example shows the directory structure is the following: `ipa/<staging or review>/<linux distribution>/<distribution version>/<artifact version>`

# Metadata and customization

The pipeline that handles the Metal3 fullstack build offers a number of customization options:

  - `IRONIC_REFSPEC`: Gerrit refspec of the patch we want to test. `Example: refs/changes/84/800084/22`
  - `IRONIC_IMAGE_REPO_COMMIT`: Ironic Image repository commit hash to build
  - `IRONIC_IMAGE_BRANCH`: Ironic image repository branch to build
  - `IRONIC_INSPECTOR_REFSPEC`: Gerrit refspec of the patch we want to test. `Example: refs/changes/84/800084/22`
  - `IPA_REPO`: The default Git repository of the Ironic Python Agent
  - `IPA_REF`: Ironic Python Agent Git repository reference string
  - `IPA_BRANCH`: Ironic Python Agent Git repository branch to build
  - `IPA_BUILDER_REPO`: Ironic Python Agent builder Git repository
  - `IPA_BUILDER_BRANCH`: Ironic Python Agent builder Git repository branch
  - `IPA_BUILDER_COMMIT`: Ironic Python Agent builder Git repository commit
  - `METAL3_DEV_ENV_REPO`: The Git repository of metal3-dev-env
  - `METAL3_DEV_ENV_BRANCH`: Metal3 dev env  Git repository branch
  - `METAL3_DEV_ENV_COMMIT`: Metal3 dev env Git repository commit
  - `BUILD_BMO_LOCALLY`: Enable or disable BMO local building (enabled by default)
  - `BUILD_CAPM3_LOCALLY`: Enable or disable CAPM3 local building (enabled by default)'
  - `BUILD_IPAM_LOCALLY`: Enable or disable IPAM local building (enabled by default)
  - `BUILD_CAPI_LOCALLY`: Enable or disable CAPI local building (disabled by default)
  - `BMO_REPO`: `The Git repository used to build BMO`
  - `BMO_BRANCH`: Git branch of the BMO repository to be used
  - `BMO_COMMIT`: Git commit of the BMO repository to be used
  - `CAPM3_REPO`: The Git repository used to build Cluster API provider Metal3
  - `CAPM3_BRANCH`: Cluster API provider Metal3 Git repository branch to build
  - `CAPM3_COMMIT`: Cluster API provider Metal3 Git repository commit hash to build
  - `IPAM_REPO`: IP Address Manager Git repository branch to build
  - `IPAM_BRANCH`: IP Address Manager Git repository branch to build
  - `IPAM_COMMIT`: IP Address Manager Git repository commit hash to build
  - `CAPI_REPO`: Cluster API Git repository branch to build
  - `CAPI_BRANCH`: Cluster API Git repository branch to build
  - `CAPI_COMMIT`: Cluster API Git repository commit hash to build
  - `STAGING`: Configures IPA builder upload mode (staging/review)

The custumization options provide git repository, branch, commit and refspec customization options in case of a manually triggered IPA-Ironic build job.
The options also provide the possibility to selectively enable/disable CAPI, CAPM3, IPAM, and BMO local building.
There is one additional type of custumization option that is called `STAGING` that controlls whether the IPA artifact will be uploaded to
`Artifactory` as part of a review or a staging group.

The IPA build script also creates a metadata file and packages into the IPA `.tar` archive. The metadata file contains metadata
such as repositories, branches and commit hashes and in some cases references and container image version for components used during
the building and testing of the Metal3 stack.

In case of CAPI the metadata content depends on whether CAPI is built from source or not. By default CAPI is not built from source
during the fullstack build because the Metal3 project's components (CAPM3, IPAM, BMO) are developed against stable CAPI releases.

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
 - IPAM
