function varargout = bst_mne_init(varargin)
% BST_MNE_INIT: Check the MNE-Python installation.
%
% USAGE:  [isOk, errorMsg, pyVer] = bst_mne_init('Initialize', isInteractive)
% 
% Reference documentation: 
% https://neuroimage.usc.edu/brainstorm/MnePython

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
% Authors: Francois Tadel, 2019-2020

eval(macro_method);
end


%% ===== INITIALIZE =====
% USAGE:  [isOk, errorMsg, pyVer] = bst_mne_init('Initialize', isInteractive)
function [isOk, errorMsg, pyVer] = Initialize(isInteractive)
    % Initialize Python
    [isOk, errorMsg, pyVer] = bst_python_init('Initialize', isInteractive);
    if ~isOk
        return;
    end
    
    % Check Python version
    if isempty(pyVer)
        errorMsg = 'BST> Could not load Python in Matlab.';
        return;
    elseif (str2num(pyVer) < 3.6)
        errorMsg = [...
            'BST> Minimum version of Python required by MNE>=0.21: 3.6' 10 ...
            'BST> Version of Python currently selected: ' pyVer];
        return
    end
    
    % Test MNE installation
    try
        FIFF = py.mne.io.constants.FIFF;
    catch
        errorMsg = 'MNE library not found. Please install it in Python first.';
        return;
    end
    
    isOk = 1;
end

