# Github Workflow

## Overview

The workflow is based on the understanding that:

* A project is forked from Open Source project to nordix
* A local copy is cloned from nordix

We refer to the Open Source project repo as `upstream`, `upstream/master` and
to the forked repo in the Nordix organization as `origin`, `origin/master`

Main branch is called `master`, containing the latest stable release.

Feature development and bug fixing are done in topic branches, branched of `master` branch. Upon completion and code review, topic branch is merged into `upstream` branch.

## Branches

### Topic branches (features and bug fixes)

Topic branches need to be branched off `master` and named `type/name-username`,
where  type is `feature` or `fix` and `username` the Github username or the name
of the person creating the branch, to mark ownership of the branch.

For example, a branch name for a feature called `Add support for policies` by user xyz would be `feature/policy-support-xyz` or similar, where a `User cannot login` bug would be `fix/user-cannot-login-xyz` or similar.

If applicable, branch name should also contain Github Issue ID, for example `fix/13-userr-cannot-login-xyz`.

## Commit Message

Commit message should be formatted as following.

```sh
Capitalized, short (50 chars or less or as subjected by open source repo practise) summary

More detailed explainatory text, if necessary. Wrap it to about 72 characters or so.
Write your commit message in the imperative: "Fix bug" and not "Fixed bug" or "Fixes bug".

Co-authored-by: My Name <my.name@est.tech>
```

If your commit includes contributions from someone else, add this person as
co-author by adding the Co-authored-by trailer at the end of your commit.

Note that the email address might be protected by Github, then you need to
use the address provided by Github.

## git workflow for a Github repo through Nordix

### 1. Create a topic branch

Create and checkout local branch where you will do your work.

`git checkout -b <topic-branch> origin/master`

Make sure to have the latest code from the upstream repository

```sh
git fetch upstream
git rebase upstream/master
```

When pushing the branch for the first time, ensure correct tracking is set up:

`git push -u origin <topic-branch>`

### 2. Keep topic branch up-to-date

When changes have been pushed to `master` branch, ensure your topic branch is up-to-date.

```sh
git fetch upstream
git checkout <topic-branch>
git rebase upstream/master
```

<!-- markdownlint-disable MD026 -->
### 3. Code, test ....
<!-- markdownlint-enable MD026 -->

Do your magic :)

### 4. Commit the changes

Changes should be grouped into logical commits, Refer to above [commit message](#commit-message) for details.

```sh
git add -p # only for existing files
git add <file> # when new file added
git commit -S
```

### 5. Push the changes

Rebase your changes on the upstream master to make sure
to have the latest commits in

```sh
git fetch upstream
git rebase upstream/master
```

Changes should be pushed to a correct origin branch:

`git push -u origin <topic-branch>`

You may need to force push your topic-branch, however this MUST be
avoided as much as possible in this stage

`git push -fu origin <topic-branch>`

### 6. Open a Internal Pull Request

When the changes in your branch are completed, a pull request has to be opened on Github.

Before opening it, **please ensure your branch is up-to-date with `master`** branch and your commits are properly formatted.

```sh
git fetch upstream
git checkout <topic-branch>
git rebase upstream/master
git push -fu origin <topic-branch>
```

### 7. Code review

Code review is done on web through Github's pull request. Pull request author assigns the reviewer or publishes the PR link to team chat(Slack) to notify the reviewers.

### 8. Squash your commits

Once the pull request is approved, at this stage you should squash your commits,
making logical units, for example introducing a single feature, squashing all
the small fixes coming from the code review.

```sh
git fetch upstream
git rebase -i upstream/master
```

### 9. Open an `Upstream` Pull Request

When the local code review is done and commit gets 2 thumbs up(+2), an upstream pull request is made from same topic-branch to the open source project for code review.

Before opening it, **please ensure your branch is up-to-date with `master`** branch and your commits are properly formatted.

```sh
git fetch upstream
git checkout <topic-branch>
git rebase upstream/master
git push -u origin <topic-branch>
```

### 10. Upstream Code review

Upstream Code review is done based on the practises defined by the open source project.

Nevertheless the assumption is the pull request is ready for merge to the upstream when the reviewrs has given 1 or 2 thumbs up (+1 or +2).

### 11. Merging the code into upstream

Pull request author can merge the code after PR has thumbs up or practises
defined by the open source project. After a successful code review, `topic`
branch is merged to `upstream`. Merging then depends on the project and is
usually done through the web interface. Once merged, you can

```sh
git fetch
git checkout <topic-branch>
```

### 12. Delete the branch when needed

To avoid leaving unneeded branches in the repository, delete your branch if you
don't use it anymore.

```sh
git push origin :<topic-branch>
```

Above command will ensure that the topic branch is removed locally and remotely

## git workflow for a Nordix github repo

It is exactly the same process except that steps 9. 10. and 11. do not happen.
Instead the code is merged with the internal pull request.
