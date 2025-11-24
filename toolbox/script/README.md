# Brainstorm scripts
This directory contains the scripts to replicate most [Brainstorm tutorials](https://neuroimage.usc.edu/brainstorm/Tutorials) and to test different parts of Brainstorm.
Tutorials can be executed individually with the respective `tutorial_TUTORIALNAME.m` script, or by calling the script `test-tutorial.m`.
These scripts can be run on Brainstorm releases (**source** and **binary**).

## Tutorial scripts

| Tutorial name             | Info  | Report | Locally<br>source | Locally<br>binary | :octocat:<br>runner | :octocat: <br>exec time |
|---------------------------|-------|--------|-------------------|-------------------|---------------------|-------------------------|
| tutorial_introduction     | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/AllIntroduction)          | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialIntroduction.html)  | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  70 min |
| tutorial_connectivity     | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity)             | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialConnectivity.html)  | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  05 min |
| tutorial_coherence        | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/CorticomuscularCoherence) | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialCMC.html)           | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 | 100 min |
| tutorial_ephys            | [Link](https://neuroimage.usc.edu/brainstorm/e-phys/Introduction)                | [Report](https://neuroimage.usc.edu/bst/examples/report_Tutorial_e-Phys.html)       | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  25 min |
| tutorial_dba              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/DeepAtlas)                | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialDba.html)           | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_epilepsy         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy)                 | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialEpilepsy.html)      | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  15 min |
| tutorial_epileptogenicity | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity)         | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialEpimap.html)        | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  15 min |
| tutorial_fem_charm        | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/FemMedianNerveCharm)      | [Report](https://neuroimage.usc.edu/brainstorm/Tutorials/FemMedianNerveCharm)       | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_fem_tensors      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/FemTensors)               | [Report](https://neuroimage.usc.edu/brainstorm/Tutorials/FemTensors)                | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_frontiers2018    | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle)             | [Report](https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle)              | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_visual           | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle)             | [Report](https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle)              | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_hcp              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/HCP-MEG)                  | [Report](https://neuroimage.usc.edu/brainstorm/Tutorials/HCP-MEG)                   | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_neuromag         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/TutMindNeuromag)          | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialNeuromag.html)      | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  20 min |
| tutorial_omega            | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega)             | [Report](https://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega)              | 🐧🪟🍎 | 🐧🪟🍎 |   N/A   |   N/A   |
| tutorial_phantom_ctf      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomCtf)               | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialPhantom.html)       | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  20 min |
| tutorial_phantom_elekta   | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomElekta)            | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialPhantomElekta.html) | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  10 min |
| tutorial_practicalmeeg    | [Link](https://neuroimage.usc.edu/brainstorm/WorkshopParis2019)                  | [Report](https://neuroimage.usc.edu/bst/examples/report_PracticalMEEG.html)         | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  30 min |
| tutorial_raw              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf)           | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialRaw.html)           | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  10 min |
| tutorial_resting          | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Resting)                  | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialResting.html)       | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  85 min |
| tutorial_simulations      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations)              | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialSimulation.html)    | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  40 min |
| tutorial_yokogawa         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Yokogawa)                 | [Report](https://neuroimage.usc.edu/bst/examples/report_TutorialYokogawa.html)      | 🐧🪟🍎 | 🐧🪟🍎 | 🐧🪟🍎 |  50 min |

\* `N\A` indicates that this tutorial is not run on GitHub runners, [see below](#1-on-github-runners)

# Function `test_tutorial.m`
This function allows to run one or more tutorial scripts. This function handles fetching the required data and sending reports by email.
Source code can be found in:

The `test_tutorial.m` can be run:
1. On GitHub-hosted runners (only for source distribution)
2. Locally (source and compiled distributions)

## 1. On GitHub-hosted runners
The function `test_tutorial.m` can be run on [GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners) for a specific **tutorial script** by using the **Test tutorial (source)** (`run_tutorial.yaml`) GitHub workflow in  the `master` branch of the `brainstorm-tools/brainstorm3`. This workflow makes use of the [Matlab GitHub actions](https://github.com/matlab-actions) to setup a Matlab environment and run code. The workflow starts 3 runners (Linux, Windows and macOS) then, for each runner Matlab is installed, and Brainstorm is started in server mode to run `test_tutorial.m` with the **tutorial script** is indicated in the workflow **Tutorial name** droplist. The three runners run simultaneously.

:bulb: Some tutorial scripts are not available on `Test tutorial (source)` GitHub workflow because these tutorial scripts:
* are not supported on the server mode (`tutorial_dba`), or
* require large datasets (`tutorial_frontiers2018`, `tutorial_visual` , `tutorial_hcp`, `tutorial_omega`), or
* require additional software such as SimNIBS or BrainSuite (`tutorial_fem_charm`, `tutorial_fem_tensors`)
As such these are not shown on the `Test tutorial (source)` GitHub action, and indicated in the [Table above](#tutorial-scripts), with the legend `N/A`.

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
It can be run directly from inside the **Matlab IDE** or from the OS **Terminal** making use of Brainstorm capability of executing scripts when in server mode.
The following sections show the commands to run `test_tutorial.m`, assuming that the current directory is `brainstorm3/`

#### Matlab IDE
This execution is the same regardless of the OS
```
brainstorm ./toolbox/script/test_tutorial.m TUTORIALNAME DATADIR REPORTDIR BSTUSER BSTPWD
brainstorm ./toolbox/script/test_tutorial.m {'TUTORIALNAME1','TUTORIALNAME2'} DATADIR REPORTDIR BSTUSER BSTPWD
```

#### Terminal
The parameters given to Matlab differ a bit among OS.
If an argument needs to be set to empty, it can be replaced with two single quotes ``''``

**Linux and macOS**
```
matlab -nodisplay -r "brainstorm ./toolbox/script/test_tutorial.m TUTORIALNAME DATADIR REPORTDIR BSTUSER BSTPWD"
matlab -nodisplay -r "brainstorm ./toolbox/script/test_tutorial.m {'TUTORIALNAME1','TUTORIALNAME2'} DATADIR REPORTDIR BSTUSER BSTPWD"
```

**Windows**
```
matlab.exe -batch "brainstorm .\toolbox\script\test_tutorial.m TUTORIALNAME DATADIR REPORTDIR BSTUSER BSTPWD"
matlab.exe -batch "brainstorm .\toolbox\script\test_tutorial.m {'TUTORIALNAME1','TUTORIALNAME2'} DATADIR REPORTDIR BSTUSER BSTPWD"
```

### Compiled distribution
You need a physical (or a virtual) machine with the OS to test, a copy of compiled Brainstorm and the installed [Matlab Runtime](https://www.mathworks.com/products/compiler/matlab-runtime.html) that matches the OS and Runtime required by the compiled Brainstorm. The following sections show the commands to run `test_tutorial.m`, assuming that the current directory is `brainstorm3/bin/R2023a`

#### Terminal
This execution differs a bit among OS.
:bulb: Be careful if `BSTUSER` or `BSTPWD` contain special characters are [escaping](https://en.wikipedia.org/wiki/Escape_character) them will be needed

**Linux and macOS**
The parameter `MATLABROOT` corresponds to the Matlab Runtime full path, e.g `/usr/local/MATLAB/MATLAB_Runtime/R2023a` or `/Applications/MATLAB/MATLAB_Runtime/R2023a`
```
./brainstorm3.command MATLABROOT ../../toolbox/script/test_tutorial.m TUTORIALNAME DATADIR REPORTDIR BSTUSER BSTPWD
./brainstorm3.command MATLABROOT ../../toolbox/script/test_tutorial.m "{'TUTORIALNAME1','TUTORIALNAME2'}" DATADIR REPORTDIR BSTUSER BSTPWD
```

**Windows**
```
./brainstorm3.bat ..\..\toolbox\script\test_tutorial.m TUTORIALNAME DATADIR REPORTDIR BSTUSER BSTPWD
./brainstorm3.bat ..\..\toolbox\script\test_tutorial.m "{'TUTORIALNAME1','TUTORIALNAME2'}" DATADIR REPORTDIR BSTUSER BSTPWD
```
