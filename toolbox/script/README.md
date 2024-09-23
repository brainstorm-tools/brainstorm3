# Brainstorm tests
## Description
Scripts to test Brainstorm releases (Source and Binary)

**Only for the Brainstorm team**\*

This repo can be used to automate tests of the Brainstorm source code with tutorial scripts.
Data is downloaded using the neuroimage FTP server with, links available [here](https://neuroimage.usc.edu/bst/download.php)

\* While all the data is public, it is behind the registration to Brainstorm


## Testing Brainstorm source distribution

### With GitHub actions
Run the `Run tutorial (on Brainstorm source)` GitHub action in the `master` branch of the `brainstorm-tools/brainstorm3` repository, indicate:
* **Test to run**, the name of the tutorial script to run
* **Brainstorm username to send email**, a report will be send to this Brainstorm user once the tutorial is done.

| Tutorial name             | Info  | OS | :octocat: exec time |
|---------------------------|-------|----|-----------|
| tutorial_introduction     | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/AllIntroduction)          | 🐧🪟🍎 |  90 min |
| tutorial_connectivity     | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity)             | 🐧🪟🍎 |  05 min |
| tutorial_coherence        | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/CorticomuscularCoherence) | 🐧🪟🍎 | 140 min |
| tutorial_ephys            | [Link](https://neuroimage.usc.edu/brainstorm/e-phys/Introduction)                | 🐧❌❌ |  XX min |
| tutorial_epilepsy         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy)                 | 🐧🪟🍎 |  20 min |
| tutorial_epileptogenicity | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity)         | 🐧🪟🍎 |  25 min |
| tutorial_fem_tensors      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/FemTensors)               | ❌❌❌ |  XX min |
| tutorial_neuromag         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/TutMindNeuromag)          | 🐧🪟🍎 |  35 min |
| tutorial_phantom_ctf      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomCtf)               | 🐧🪟🍎 |  20 min |
| tutorial_phantom_elekta   | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomElekta)            | 🐧🪟🍎 |  10 min |
| tutorial_practicalmeeg    | [Link](https://neuroimage.usc.edu/brainstorm/WorkshopParis2019)                  | 🐧🪟🍎 |  30 min |
| tutorial_raw              | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf)           | 🐧🪟🍎 |  10 min |
| tutorial_resting          | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Resting)                  | 🐧🪟❌ |  XX min |
| tutorial_simulations      | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations)              | 🐧🪟🍎 |  35 min |
| tutorial_yokogawa         | [Link](https://neuroimage.usc.edu/brainstorm/Tutorials/Yokogawa)                 | 🐧🪟🍎 |  60 min |


### Locally
With Matlab installed,
1. Clone this repository and the `brainstorm3` repo in the same directory. I.e, `./bst-test` and `./brainstorm3`
2. Create a symbolic link to `./bst-test/test_brainstorm.m` in `./brainbstorm3` (or copy the file)

#### Linux
```
matlab22b . -nodisplay -r "brainstorm test_brainstorm.m tutorial_connectivity BRAINSTORM_USERNAME local"
```

#### Windows
```
matlab.exe -batch "brainstorm test_brainstorm.m tutorial_connectivity BRAINSTORM_USERNAME local"
```

#### macOS
```
matlab.exe -batch "brainstorm test_brainstorm.m tutorial_connectivity BRAINSTORM_USERNAME local"
```

## Testing Brainstorm binary distribution

### Locally
You need a physical (or a virtual) machine with the OS to test and their respective [Matlab Runtime](https://www.mathworks.com/products/compiler/matlab-runtime.html) installed.

#### Linux
**Execution:**
```
./brainstorm3.command /usr/local/MATLAB/MATLAB_Runtime/R2022b test_brainstorm.m tutorial_connectivity BRAINSTORM_USERNAME local
```

#### Windows


#### macOS
