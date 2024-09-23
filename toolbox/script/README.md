# Brainstorm scripts
This directory contains the scripts to replicate most [Brainstorm tutorials](https://neuroimage.usc.edu/brainstorm/Tutorials) and to test different parts of Brainstorm 


Scripts to test Brainstorm releases (Source and Binary)


| Tutorial name             | Info  | Report | OS | :octocat: exec time |
|---------------------------|-------|--------|----|---------------------|
| tutorial_introduction     | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/AllIntroduction)          | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  90 min |
| tutorial_connectivity     | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity)             | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  05 min |
| tutorial_coherence        | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/CorticomuscularCoherence) | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 | 140 min |
| tutorial_ephys            | [Link](https://neuroimage.usc.edu/brainstorm/e-phys/Introduction)                | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧❌❌ |  XX min |
| tutorial_dba              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/DeepAtlas)                | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧❌❌ |  XX min |
| tutorial_epilepsy         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy)                 | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  20 min |
| tutorial_epileptogenicity | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity)         | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  25 min |
| tutorial_fem_charm        | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/FemMedianNerveCharm)      | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | ❌❌❌ |   N/A   |
| tutorial_fem_tensors      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/FemTensors)               | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | ❌❌❌ |   N/A   |
| tutorial_frontiers2018    | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle)             | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | ❌❌❌ |   N/A   |
| tutorial_visual           | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle)             | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | ❌❌❌ |   N/A   |
| tutorial_hcp              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/HCP-MEG)                  | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | ❌❌❌ |   N/A   |
| tutorial_neuromag         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/TutMindNeuromag)          | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  35 min |
| tutorial_omega            | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega)             | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | ❌❌❌ |   N/A   |
| tutorial_phantom_ctf      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomCtf)               | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  20 min |
| tutorial_phantom_elekta   | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomElekta)            | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  10 min |
| tutorial_practicalmeeg    | [Link](https://neuroimage.usc.edu/brainstorm/WorkshopParis2019)                  | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  30 min |
| tutorial_raw              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf)           | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  10 min |
| tutorial_resting          | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Resting)                  | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟❌ |  XX min |
| tutorial_simulations      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations)              | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  35 min |
| tutorial_yokogawa         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Yokogawa)                 | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html) | 🐧🪟🍎 |  60 min |

\* `N\A` indicates that this tutorial is not run on GitHub runners, see below #LINK_TO_SECTION

# Script `test_tutorial.m` 
This scripts allows to tests Brainstorm by running tutorial scripts.

Tutorial scripts can be run:
1. On GitHub runners (only for source distribution)
2. Locally (source and compiled distributions)

## 1. On GitHub runners
In this scenario, 3 [GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners): Linux, Windows and macOS) are setup with Matlab. 
This is achieved by using the `Test tutorial (source)` GitHub action in the `master` branch of the `brainstorm-tools/brainstorm3` repository. As some tutorials require data, this is automatically downloaded by providing a Brainstorm username and password.

The GitHub action requires these three parameters:

* **Tutorial name**: the name of the tutorial script to run
* **Brainstorm username**: to send email with report, and to download needed data
* **Brainstorm password**: to download needed data

:bulb: Some tutorial scripts require large datasets or additional software, these are not run on GitHub runners and are indicated in TABLE X, with the legend `N/A`.

## 2. Locally
It is also possible to run the tutorial scripts locally using `test_tutorial.m`, to tests the source and compiled Brainstorm distributions.

When run locally, the `test_tutorial.m` scripts requires this parameters:

**tutorialNames** : Tutorial or {Tutorials} to run
**dataDir**       : (optional) Directory wtih tutorial data files               (default = 'pwd'/tmpdir)
**reportDir**     : (optional) Directory to save reports                        (default = reports are not saved)
**bstUser**       : (optional) BST user to receive email with report            (default = no email)
**bstPwd**        : (optional) Password for BST user to download data if needed (default = empty)

### Source distribution
A local installation of Matlab and a local copy of Brainstorm source are required.
It can be run directly from Matlab IDE, or from the terminal making use of Brainstorm capability of executing scripts when in server mode.

#### Linux
```
matlab22b . -nodisplay -r "brainstorm test_tutorial.m tutorial_connectivity BST_USE BST_PWD local"
```

#### Windows
```
matlab.exe -batch "brainstorm test_tutorial.m tutorial_connectivity BST_USE BST_PWD local"
```

#### macOS
```
matlab.exe -batch "brainstorm test_tutorial.m tutorial_connectivity BST_USE BST_PWD local"
```

### Compiled distribution
You need a physical (or a virtual) machine with the OS to test, a copy of compiled Brainstorm and the installed [Matlab Runtime](https://www.mathworks.com/products/compiler/matlab-runtime.html) that matches the OS and Runtime required by the compiled Brainstorm. 

#### Linux
```
./brainstorm3.command test_tutorial.m tutorial_connectivity BST_USE BST_PWD local
```

#### Windows


#### macOS
