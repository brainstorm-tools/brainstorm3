% DEMO_PYTHON: Examples of MATLAB-Python integration.
%
% FUNCTIONS:
%    - demo_matlab.py : Original Python example 
%    - demo_matlab.m  : Call demo_matlab.py from Matlab
%    - demo_matlab.m  : Reproduce demo_matlab.py with Matlab calls
% 
% REFERENCES
%    - Installation: https://neuroimage.usc.edu/brainstorm/MnePython
%    - Dataset: https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf
%
% AUTHORS:
%    - Python version: Mainak Jas <mainak.jas@telecom-paristech.fr>
%    - Matlab version: Francois Tadel, 2018-2020

% Initialize Brainstorm-Python
bst_python_init('Initialize', 1);
brainstorm stop
% Unload existing modules
clear classes

% Load python module and execute method
try
    % Load module
    mod = py.importlib.import_module('demo_python');
    % Force reloading Python module
    py.importlib.reload(mod);
    % Execute test() method
    raw = py.demo_python.test();
catch e
    if contains(e.message, 'sys.stdin')
        error([10 'MATLAB does not support the use of Python function input().' 10 ...
            'You must download the dataset manually from a Python terminal:' 10 ...
            '>>> import mne' 10 ...
            '>>> mne.datasets.brainstorm.bst_raw.data_path()' 10 10]);
    else
        rethrow(e);
    end
end
