# Contributing to Brainstorm

## Thank you for contributing to **Brainstorm**!
This repository (repo) holds the source code for the [Brainstorm application](https://neuroimage.usc.edu/brainstorm/Introduction).

When contributing, please ***first discuss the change*** you wish to make via the [Brainstorm forum](https://neuroimage.usc.edu/forums/), a [GitHub issue](https://github.com/brainstorm-tools/brainstorm3), or an [email](brainstorm@sipi.usc.edu) to the Brainstorm team.

Contributions to ***this*** repository include:
- :beetle: Solving [Issues](https://github.com/brainstorm-tools/brainstorm3/issues)
- :grey_question: Addressing [Forum questions](https://neuroimage.usc.edu/forums/)
- :star: Development of new features

To know other ways in which you can collaborate with Brainstorm visit the page [Brainstorm Contribute](https://neuroimage.usc.edu/brainstorm/Contribute) page.

Before starting a new contribution you need to be familiar with [Git](https://git-scm.com/) and [GitHub](https://github.com/) concepts like: ***commit, branch, push, pull, remote, fork, repository***, etc. There are plenty resources online to learn Git and GitHub, for example:
- [Git Guide](https://github.com/git-guides/)
- [GitHub Quick start](https://docs.github.com/en/get-started/quickstart)
- [GitHub guide on YouTube](https://www.youtube.com/githubguides)
- [Git and GitHub learning resources](https://docs.github.com/en/get-started/quickstart/git-and-github-learning-resources)
- [Collaborating with Pull Requests](https://docs.github.com/en/github/collaborating-with-pull-requests)
- [GitHub Documentation, guides and help topics](https://docs.github.com/en/github)
- And many more...

## How to contribute
We use the [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow). As such, the general process to contribute to Brainstorm consists of **7 steps**:

1. ### **Create your copy of the official Brainstorm repo**
 
    [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) the official Brainstorm repo (`https://github.com/brainstorm-tools/brainstorm3`) to your GitHub account. This will create your Brainstorm repo in your GitHub account. Then [clone](https://docs.github.com/en/get-started/quickstart/fork-a-repo#cloning-your-forked-repository) your Brainstorm repo (`https://github.com/YOUR-USERNAME/brainstorm3`) to your computer. These actions will create a copy of the Brainstorm repo in your GitHub account and a local repo in your computer so you can freely modify it without affecting the official Brainstorm repo.
    
    - Fork the official Brainstorm repo in [GitHub.com](https://github.com/), then: 
    ``` 
    $ git clone https://github.com/YOUR-USERNAME/brainstorm3
    ```

2. ### **Link your local repo to the official Brainstorm repo**  
  
    In your local repository, add the official Brainstorm repo as remote.
    ```
    $ git remote add official https://github.com/brainstorm-tools/brainstorm3
    ```
    At this point the remote `origin` refers to your forked repo (in your GitHub account) and the remote `official` to the repo in `https://github.com/brainstorm-tools/brainstorm3`. By doing this you can [pull](https://github.com/git-guides/git-pull) the official Brainstorm repository to keep your repos synchronized with the most recent version of Brainstorm.
    ```
    $ git checkout master    
    $ git pull official master
    $ git push origin master
    ```
   > **Important**: Perform your changes in the latest version of Brainstorm to facilitate the contribution process.

3. ### **Create a branch in your local repo**

    This [branch](https://docs.github.com/en/get-started/quickstart/github-flow#create-a-branch) is the one that will be used for your contribution.
    ```
    git checkout -b fix-something
    ```
    > **Tip**: Make a separate branch for each set of unrelated changes.

4. ### **Work on the desired changes**
   
    Your branch is a safe place to [make the changes](https://docs.github.com/en/get-started/quickstart/github-flow#make-changes) that you desire.
    ```
    git checkout fix-something
    ```
    [Commit](https://github.com/git-guides/git-commit) and [push](https://github.com/git-guides/git-push) your changes to your branch. Give each commit a [descriptive message](https://github.com/git-guides/git-commit) to help you and the developing team to understand what changes the commit contains. [Push](https://github.com/git-guides/git-push) your local branch to your `origin` remote. You need to [set the upstream](https://docs.github.com/en/github/collaborating-with-pull-requests/working-with-forks/configuring-a-remote-for-a-fork) the first time you push it.
    ```
    git push --set-upstream origin fix-something
    ```
    This will create the remote branch in your repo, and linked to your local branch. The remote branch will allow you to: have a remote backup of your changes, and work on it from in different places (or with different people).

5. ### **Done with the changes**
  
    Once you're happy with all the changes that you have done. Push them (if you haven't) to your remote fork.
    ```
    git push origin fix-something
    ```

6. ### **Create a new Pull Request**
  
    Using the GitHub website, create a [Pull Request](https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) or **PR** from your **remote branch** to the **master** branch in the the official Brainstorm repo.

7. ### **Code review**
    
    Once you have created a PR, we will start a [review](https://docs.github.com/en/github/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews) on the changes and provide feedback to have all the proposed changes inline with Brainstorm. When your PR is approved, the next step is to [merge](https://docs.github.com/en/github/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/merging-a-pull-request) your work to the official Brainstorm repo.
