# Getting started

## Pre-requisites

This walk-through assumes that you have an EST email address set up.
Any question or issue related to the Nordix setup should be addressed to
discuss@lists.nordix.org

There is a [Nordix getting started](https://wiki.nordix.org/display/DEV/Getting+Started)

## Google account

You should be able to use your EST email to use the Google Sign-in for the
Nordix tools. If you follow the steps laid out below then you should have an
account, using your EST email, to sign into the Nordix Jenkins and other Nordix
services.

* Follow this [link](https://accounts.google.com/signup/v2/webcreateaccount?hl=en&flowName=GlifWebSignIn&flowEntry=SignUp)
* Click on "Use my current email address instead".
* Create an account using <user>@est.tech.
* When logging into Nordix services, click on "Connect with Google" after
  clicking on "Log in".
* Click on the relevant @est.tech account, enter your password (it also may
  automatically log you in)

You should be good to go.

## Github

You do not need a specific account for EST, you can use your normal account and
username provided that you set your EST email account in your Github account
(as primary so that it is used for the web-based operations).

Your commits must be done with your EST email address. The CLA is linked to your
email address.

We require signing the commits, here is how to set up GPG keys for signing with
Github:
* [Create a GPG key](https://help.github.com/en/articles/generating-a-new-gpg-key)
* [Add the key in Github](https://help.github.com/en/articles/telling-git-about-your-signing-key)
* [Use the key to sign commits](https://help.github.com/en/articles/signing-commits)

As we use the EST email address in the commits, we need to tell Github to not
hide our identity. Click on your picture in the right top corner,
Settings -> Emails and untick "Keep my email addresses private".

Then ask someone with the permissions on the repositories to add you.

We have some guidelines related to the Ways of Working with Github in our
[Github Workflow](wow/github-workflow.md).

## Openstack

We have a tenant on Citycloud. The control panel is at
[City cloud control panel](https://citycontrolpanel.com). You can ask for an
account on the Nordix discuss mailing list or within the team.

## Artifactory

You need a specific account in [Artifactory](https://artifactory.nordix.org).
Ask for an account on the Nordix discuss mailing list.

## Harbour

You need a specific account in [Harbour](https://registry.nordix.org). Create an
account and then ask to be given permissions on the repositories.

## Wiki

Most of our documentation is in [Nordix wiki](https://wiki.nordix.org)

## Other Nordix tools

You should be able to log in most services with your Google account

## Mailing lists

We suggest you join the following mailing lists :

* [Discuss Nordix](https://lists.nordix.org/mailman/listinfo/discuss) for all
  questions related to Nordix
* [Discuss Airship](http://lists.airshipit.org/cgi-bin/mailman/listinfo/airship-discuss)
* [Announce Airship](http://lists.airshipit.org/cgi-bin/mailman/listinfo/airship-announce)
* [cluster API (Cluster-lifecycle SIG)](https://groups.google.com/forum/#!forum/kubernetes-sig-cluster-lifecycle)
  Joining this group will also allow you to edit the cluster-api google docs.
