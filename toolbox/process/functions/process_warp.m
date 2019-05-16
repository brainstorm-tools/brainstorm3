function varargout = process_warp( varargin )
% PROCESS_WARP: Warp default anatomy to fit head points.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Warp default anatomy';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 4;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutWarping';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Option: Default channel files
    sProcess.options.usedefault.Comment = {'Scale', 'Warp'};
    sProcess.options.usedefault.Type    = 'radio';
    sProcess.options.usedefault.Value   = 2;
    % Options: tolerance
    sProcess.options.tolerance.Comment = 'Outlier points to ignore:';
    sProcess.options.tolerance.Type    = 'value';
    sProcess.options.tolerance.Value   = {2, '%', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Define options of the warping function
    Options = struct(...
        'tolerance',     sProcess.options.tolerance.Value{1} / 100, ...  % Convert to a value [0,1]
        'isScaleOnly',   (sProcess.options.usedefault.Value == 1), ...
        'isInteractive', 0);
    % Get list of subjects in input
    uniqueSubj = unique({sInputs.SubjectName});
    % Loop on all the subjects
    for i = 1:length(uniqueSubj)
        % Get first input file for this subject
        iInput = find(strcmpi(uniqueSubj, {sInputs.SubjectName}));
        % Run the warping function
        bst_warp_prepare(sInputs(iInput(i)).ChannelFile, Options);
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end



