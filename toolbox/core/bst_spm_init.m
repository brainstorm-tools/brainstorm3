function isOk = bst_spm_init(isInteractive, SpmFunction)
% BST_SPM_INIT: Check SPM installation.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

% Deployed: does not work
if exist('isdeployed', 'builtin') && isdeployed
    error(['SPM functions cannot be called from the compiled version of Brainstorm.' 10 ...
           'We would need to compile Brainstorm and SPM together. Doable but complicated.' 10 ...
           'Please post a message on the forum if you are interested in contributing.']);
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
% % Check if SPM is already initialized
% if exist('spm', 'file')
%     isOk = 1;
%     return;
% end
isOk = 0;
% If SPM is not accessible in the path
if ~exist('spm.m', 'file')
    % If defined, add to the folder
    if ~isempty(SpmDir)
        addpath(SpmDir);
    % Else: Ask where is SPM installed
    elseif isInteractive
        % Warning message
        if ~java_dialog('confirm', [...
            'This process require the SPM toolbox to be installed on your computer.', 10, ...
            'Download the toolbox at: http://www.fil.ion.ucl.ac.uk/spm/software/download' 10 10 ...
            'Is SPM already installed on your computer?'])
            bst_error('SPM was not set up properly.', 'SPM setup', 0);
            return;
        end
        % Loop until a correct folder was picked
        isStop = 0;
        while ~isStop
            % Open 'Select directory' dialog
            SpmDir = uigetdir(SpmDir, 'Select SPM directory');
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
    end
end
    