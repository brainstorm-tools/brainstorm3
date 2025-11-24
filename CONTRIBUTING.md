# Contributing to Brainstorm

## Thank you for contributing to **Brainstorm**!
This repository (repo) holds the source code for the [Brainstorm application](https://neuroimage.usc.edu/brainstorm/Introduction).

When contributing, please ***first discuss the change*** you wish to make in one of the three following ways:

- A post in the [Brainstorm forum](https://neuroimage.usc.edu/forums/) (preferred communication method)
- A [GitHub issue](https://github.com/brainstorm-tools/brainstorm3/issues)
- An [email](brainstorm@sipi.usc.edu) to the [Brainstorm team](https://neuroimage.usc.edu/brainstorm/AboutUs)

Contributions to ***this*** repository include:
- :beetle: Solving [Issues](https://github.com/brainstorm-tools/brainstorm3/issues)
- :grey_question: Addressing questions in the [Brainstorm forum](https://neuroimage.usc.edu/forums/)
- :star: Development of new features

To know other ways in which you can collaborate with Brainstorm, visit the [Contribute](https://neuroimage.usc.edu/brainstorm/Contribute) page.

## MATLAB resources
Brainstorm is developed with [MATLAB](https://www.mathworks.com/products/matlab.html) (and bit of [Java](https://www.java.com/en/) for the GUI).
This is a brief list of resources to get started with MATLAB if you are new or come from a different programming language:
- [Get Started with MATLAB](https://www.mathworks.com/help/matlab/getting-started-with-matlab.html)
- [MATLAB Fundamentals](https://matlabacademy.mathworks.com/details/matlab-fundamentals/mlbe)
- [Introduction to MATLAB for Python Users](https://blogs.mathworks.com/student-lounge/2021/02/19/introduction-to-matlab-for-python-users/)
- [MATLAB for Brain and Cognitive Scientists](https://mitpress.mit.edu/9780262035828/)
- [Brainstorm scripting](https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting)
- [Debug MATLAB Code Files](https://www.mathworks.com/help/matlab/matlab_prog/debugging-process-and-features.html)
- [MATLAB Debugging Tutorial (video)](https://www.youtube.com/watch?v=PdNY9n8lV1Y)

## Git and GitHub resources
Before starting a new contribution, you need to be familiar with [Git](https://git-scm.com/) and [GitHub](https://github.com/) concepts like: ***commit, branch, push, pull, remote, fork, repository***, etc. There are plenty resources online to learn Git and GitHub, for example:
- [Git Guide](https://github.com/git-guides/)
- [GitHub Quick start](https://docs.github.com/en/get-started/quickstart)
- [GitHub guide on YouTube](https://www.youtube.com/githubguides)
- [Git and GitHub learning resources](https://docs.github.com/en/get-started/quickstart/git-and-github-learning-resources)
- [Collaborating with Pull Requests](https://docs.github.com/en/github/collaborating-with-pull-requests)
- [GitHub Documentation, guides and help topics](https://docs.github.com/en/github)
- And many more...

## How to contribute
We use the [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow) as guideline for contributions. Thus, the general process to contribute to Brainstorm consists of **7 steps**:

1. ### **Create your copy of the official Brainstorm repo**

    [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) the official Brainstorm repo (`https://github.com/brainstorm-tools/brainstorm3`) to your GitHub account. This will create your Brainstorm repo in your GitHub account. Then [clone](https://docs.github.com/en/get-started/quickstart/fork-a-repo#cloning-your-forked-repository) your Brainstorm repo (`https://github.com/YOUR-USERNAME/brainstorm3`) to your computer. These actions will create a copy of the Brainstorm repo in your GitHub account and a local repo in your computer so you can freely modify it without affecting the official Brainstorm repo.

    Fork the official Brainstorm repo in [https://github.com/brainstorm-tools/brainstorm3](https://github.com/brainstorm-tools/brainstorm3), then:
    ```
    $ git clone https://github.com/YOUR-USERNAME/brainstorm3
    ```

2. ### **Link your local repo to the official Brainstorm repo**  

    In your local repository, add the official Brainstorm repo as a remote.
    ```
    $ git remote add official https://github.com/brainstorm-tools/brainstorm3
    ```
    At this point the remote `origin` refers to your forked repo (in your GitHub account), and the remote `official` to the repo in `https://github.com/brainstorm-tools/brainstorm3`. By doing this you can [pull](https://github.com/git-guides/git-pull) the official Brainstorm repository to keep your repo synchronized with the most recent version of Brainstorm.
    ```
    $ git checkout master    
    $ git pull official master
    $ git push origin master
    ```
   > :warning: Perform your changes in the latest version of Brainstorm to facilitate the contribution process.

3. ### **Create a branch in your local repo**

    Create a [branch](https://docs.github.com/en/get-started/quickstart/github-flow#create-a-branch) in your local repo. This branch is the one that will be used for your contribution.
    ```
    git checkout -b fix-something
    ```
    > :bulb: Make a separate branch for each set of unrelated changes.

4. ### **Work on the desired changes**

    Your branch is a safe place to [make the changes](https://docs.github.com/en/get-started/quickstart/github-flow#make-changes) that you desire.
    ```
    git checkout fix-something
    ```

    [Commit](https://github.com/git-guides/git-commit) your changes to your local branch.
    - Give each commit a [descriptive message](https://github.com/git-guides/git-commit) to help you and the maintainers to understand what changes the commit contains.
    - Do not push your commits until you're happy with them, or you have good reason to do it.
    <br/><br/>

    > :bulb: Working locally give you the freedom of rewriting your commit history to clean it up. A clean commit history simplifies the contribution process.
See: [Git tools rewriting history](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History) for more info.

5. ### **Done with the changes**
    When you're done the desired changes. The next step is to push your local branch (if you haven't) to your remote `origin` repo.

    To [push](https://github.com/git-guides/git-push) your local branch to the remote `origin` for the first time, you need to [set the upstream](https://docs.github.com/en/github/collaborating-with-pull-requests/working-with-forks/configuring-a-remote-for-a-fork). This process creates a branch in your remote repo, links it to your local branch, and pushes your local changes to the repo in your GitHub account.

    ```
    git push --set-upstream origin fix-something
    ```

    Once the upstream is set, additional local commits can be push with:
    ```
    git push origin fix-something
    ```

6. ### **Create a new Pull Request**

    Once you're **happy** with all the changes that you have done, and you have pushed them to your remote repo, using the GitHub website, create a [Pull Request (PR)](https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) from your **remote branch** to the **master** branch in the official Brainstorm repo.

    > :warning: For greater collaboration, select the option [Allow edits by maintainers](https://docs.github.com/en/github/collaborating-with-pull-requests/working-with-forks/allowing-changes-to-a-pull-request-branch-created-from-a-fork) before creating your PR. This will allow Brainstorm maintainers to add commits to your PR branch before merging it. You can always change this setting later.

 ![image](https://user-images.githubusercontent.com/8238803/135626746-aaaac892-8c44-494e-a79d-b7195e3b2b5e.png)

7. ### **Code review**

    Once you have created a PR, we will start a [review](https://docs.github.com/en/github/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews) on the changes and provide feedback to have all the proposed changes inline with Brainstorm. When your PR is approved, the next step is to [merge](https://docs.github.com/en/github/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/merging-a-pull-request) your work to the official Brainstorm repo.

**Do not hesitate in [contacting us](#contact) if you have any question.**
