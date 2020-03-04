function isOk = bst_spm_init(isInteractive, SpmFunction)
% BST_SPM_INIT: Check SPM installation.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2017-2020

isOk = 0;
% Deployed: Code already included in the compiled version
if exist('isdeployed', 'builtin') && isdeployed
    isOk = 1;
    return;
end
% Default behavior
if (nargin < 1) || isempty(isInteractive)
    isInteractive = 0;
end
if (nargin < 2) || isempty(SpmFunction)
    SpmFunction = [];
end
% Get the saved SPM path
SpmDir = bst_get('SpmDir');
% Display the SPM folder 
if ~isempty(SpmDir) && ~isInteractive
    disp(['BST> SPM install: ' SpmDir]);
end

% Check if SPM is already initialized, but in the wrong place (eg. FieldTrip folder)
if exist('spm.m', 'file') && ~file_compare(bst_fileparts(which('spm')), SpmDir)
    wrongPaths = intersect(str_split(path,';'), str_split(genpath(bst_fileparts(which('spm'))),';'));
    for iPath = 1:length(wrongPaths)
        disp(['SPM> Removed conflicting folder from path: ' wrongPaths{iPath}]);
        rmpath(wrongPaths{iPath});
    end
end

% If SPM is not accessible in the path
if ~exist('spm_jobman.m', 'file')
    % If defined, add to the folder
    if ~isempty(SpmDir)
        addpath(SpmDir);
    % Else: Ask where is SPM installed
    elseif isInteractive
        % Warning message
        if ~java_dialog('confirm', [...
            'This process requires the SPM toolbox to be installed on your computer.', 10, ...
            'Download the toolbox at: http://www.fil.ion.ucl.ac.uk/spm/software/download' 10 ...
            'Then add the installation path in Brainstorm (File > Edit preferences).' 10 10 ...
            'Is SPM already installed on your computer?'])
            bst_error('SPM was not set up properly.', 'SPM setup', 0);
            return;
        end
        % Loop until a correct folder was picked
        isStop = 0;
        while ~isStop
            % Open 'Select directory' dialog
            SpmDir = bst_uigetdir(SpmDir, 'Select SPM directory');
            % Exit if not set
            if isempty(SpmDir) || ~ischar(SpmDir)
                SpmDir = [];
                isStop = 1;
            elseif ~file_exist(bst_fullfile(SpmDir, 'spm.m'))
                bst_error('The folder you selected does not contain a valid SPM installation.', 'SPM setup', 0);
            else
                isStop = 1;
            end
        end
        % Nothing selected: return an error
        if isempty(SpmDir)
            bst_error('SPM was not set up properly.', 'SPM setup', 0);
            return;
        end
        % Add selected folder to Matlab path
        addpath(SpmDir);
        % Save this folder for future use
        bst_set('SpmDir', SpmDir);
        % Display folder
        disp(['BST> New SPM folder: ' SpmDir]);
    % Just return an error
    else
        error(['Please download SPM: http://www.fil.ion.ucl.ac.uk/spm/software/download' 10 ...
               'Then add the installation path in Brainstorm (File > Edit preferences).']);
    end
% If spm.m is available but SpmDir is not defined: set it automatically
elseif isempty(SpmDir) || ~file_exist(SpmDir)
    SpmDir = bst_fileparts(which('spm'));
    bst_set('SpmDir', SpmDir);
end
isOk = 1;

% Add subfolders needed for a specific function
if ~isempty(SpmFunction) && ~exist(SpmFunction, 'file')
    switch (SpmFunction)
        case 'ft_read_headshape'
            addpath(fullfile(SpmDir, 'external', 'fieldtrip', 'fileio'));
            addpath(fullfile(SpmDir, 'external', 'fieldtrip', 'utilities'));
        case 'ft_specest_mtmconvol'
            addpath(fullfile(SpmDir, 'external', 'fieldtrip', 'specest'));
            addpath(fullfile(SpmDir, 'external', 'fieldtrip', 'preproc'));
            addpath(fullfile(SpmDir, 'external', 'fieldtrip', 'utilities'));
        case 'cat12'
            catDir = bst_fullfile(SpmDir, 'toolbox', 'cat12');
            if ~file_exist(catDir)
                error(['Please download and install the SPM12 toolbox "CAT12":' 10 ...
                       'http://www.neuro.uni-jena.de/vbm/download/']);
            end
            addpath(catDir);
    end
end
    