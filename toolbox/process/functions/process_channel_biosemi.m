function varargout = process_channel_biosemi( varargin )
% PROCESS_CHANNEL_BIOSEMI: Rename channels for Biosemi raw recordings in database.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Vatsala Nema, 2023
%          Raymundo Cassani, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Rename EEG channels Biosemi caps';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 43;
    sProcess.Description = '';
    sProcess.isSeparator = 1;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % TODO: Add a text describing the changes, with a link to Biosemi info
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};

    % ===== GET CHANNEL FILE  =====
    sChannel = bst_get('ChannelForStudy', [sInputs.iStudy]);

    % ===== VERIFY DEVICE AND BIOSEMI NAMING SYSTEM =====
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName, 'Channel');
    ChannelMat.Channel;
    % TODO: Check:
    %       - There are EEG channels, AND
    %       - Current channels names correspond to Biosemi style: A1...A32, B1...B32 C1... and so on, AND
    %         (Be aware of multiple naming e.g., A1 == A01 === A001, ...)
    %       - All EEG channels make up a Biosemi cap, no 1 channel more, no 1 channel less.
    %       - Otherwise return without changes

    % ===== RENAME CHANNELS IN CHANNEL FILE  =====
    ChannelFileRenamed = Compute(sChannel.FileName);
    if ~isequal(ChannelFileRenamed, sChannel.FileName)
        bst_report('Error', sProcess, [], 'Channel file was not changed.');
    end

    % Return input files
    OutputFiles = {sInputs.FileName};
end

%% ===== RENAME CHANNELS =====
function ChannelFileNew = Compute(ChannelFile)
    ChannelFileNew = [];
    ChannelFileFull = file_fullpath(ChannelFile);
    % Load channel file
    ChannelMatOld = in_bst_channel(ChannelFile, 'Channel', 'History');
    % TODO: Get maps with GetBiosemiMapping
    % TODO: Do name mapping
    ChannelMatNew.Channel = ChannelMatOld.Channel;
    % Add in History
    ChannelMatNew.History = ChannelMatOld.History;
    ChannelMatNew = bst_history('add', ChannelMatNew, 'edit', 'Channel names renamed to 10-10 system according Biosemi caps.');
    % Update file
    bst_save(ChannelFileFull, ChannelMatNew, 'v7', 1);
    ChannelFileNew = file_short(ChannelFileFull);
end

%% ===== NAME MAPS =====
function ChannelNameMaps = GetBiosemiMaps()
    ChannelNameMaps = [];
    % TODO: Generate one-to-one channel name maps for Biosemi caps
    %       Maps can be as simple as cell arrays size (nChannels, 2), one column Biosemi, one column 10-10 system
    %       Then comparisons are simpler
end
