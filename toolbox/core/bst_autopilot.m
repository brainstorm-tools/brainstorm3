function [ varargout ] = bst_autopilot( varargin )
%BST_AUTOPILOT Using Brainstorm features without the main GUI.
%
% USAGE:   brainstorm('autopilot', 'ReviewRaw', RawFile, FileFormat, isSeeg=0, OutputFile=[])

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

eval(macro_method);
end


%% ===== START STAND-ALONE =====
function BakDbDir = StartLocalDb(ProtocolName, isOverwrite)
    % Get previous database directory
    BakDbDir = bst_get('BrainstormDbDir');
    % Save brainstorm directory
    BrainstormDbDir = bst_fullfile(bst_get('BrainstormUserDir'), 'local_db');
    bst_set('BrainstormDbDir', BrainstormDbDir);
    % Delete existing protocol
    if isOverwrite
        gui_brainstorm('DeleteProtocol', ProtocolName);
    end
    % Create new protocol
    gui_brainstorm('CreateProtocol', ProtocolName, 1, 0);
    
end


%% ===== REVIEW RAW =====
% USAGE:  brainstorm('autopilot', 'ReviewRaw', RawFile, FileFormat, isSeeg=0, OutputFile=[])
function OutputFile = ReviewRaw(RawFile, FileFormat, isSeeg, OutputFile) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 3) || isempty(isSeeg)
        isSeeg = 0;
    end
    if (nargin < 4)
        OutputFile = [];
    end
    % Reset tracking variable
    global BstAutoPilot;
    BstAutoPilot = [];
    
    % Start Brainstorm
    BakDbDir = StartLocalDb('Review', 1);
    % Get default subject
    SubjectName = 'Sub';
    [sSubject, iSubject] = bst_get('Subject', SubjectName, 1);
    % If subject does not exist yet: create it
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName);
    end
    
    % Import options
    ImportOptions = db_template('ImportOptions');
    ImportOptions.DisplayMessages = 0;
    % Link raw file to database
    BstFiles = import_raw(RawFile, FileFormat, [], ImportOptions);
    % Change the type of channels from EEG to SEEG
    if isSeeg
        % Get channel file
        ChannelFile = bst_get('ChannelFileForStudy', BstFiles{1});
        % Load channel file
        ChannelMat = in_bst_channel(ChannelFile);
        % Get channel types
        iEeg = channel_find(ChannelMat.Channel, 'EEG');
        iSeeg = channel_find(ChannelMat.Channel, 'SEEG');
        % If there are only EEG channels, change type to SEEG
        if ~isempty(iEeg) && isempty(iSeeg)
            bst_process('CallProcess', 'process_channel_settype', BstFiles{1}, [], ...
                'sensortypes', 'EEG', ...
                'newtype',     'SEEG');
            Modality = 'SEEG';
        elseif ~isempty(iSeeg)
            Modality = 'SEEG';
        else
            Modality = [];
        end
    else
        Modality = [];
    end
    % Open file viewer
    hFig = view_timeseries(BstFiles{1}, Modality);
    % Show main Brainstorm window
    jBstFrame = bst_get('BstFrame');
    jBstFrame.setVisible(1);
    % Wait for the end of the edition
    waitfor(hFig);

    % Save modifications
    if ~isempty(OutputFile)
        % Make sure it is not the same as the input file
        if file_compare(RawFile, OutputFile)
            error('Cannot overwrite the input file.');
        end
        % Get tracked modifications to determine if a new file should be saved
        if (isfield(BstAutoPilot, 'isEventsModified') && isequal(BstAutoPilot.isEventsModified, 1)) || ...
           (isfield(BstAutoPilot, 'isBadModified') && isequal(BstAutoPilot.isBadModified, 1)) || ...
           (isfield(BstAutoPilot, 'isDataModified') && isequal(BstAutoPilot.isDataModified, 1))
            OutputFile = export_data(BstFiles{1}, [], OutputFile, FileFormat);
        else
            OutputFile = [];
        end
    end
    
    % Restore database folder
    bst_set('BrainstormDbDir', BakDbDir);
    % Close Brainstorm
    if brainstorm('status')
        brainstorm stop
    end
end





