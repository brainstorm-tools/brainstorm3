function varargout = process_channel_biosemi( varargin )
% PROCESS_CHANNEL_BIOSEMI: Rename channels for BioSemi raw recordings in database.

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
function sProcess = GetDescription()
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Rename EEG channels from BioSemi caps';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 43;
    sProcess.Description = 'https://www.biosemi.com/headcap.htm';
    sProcess.isSeparator = 1;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Label
    sProcess.options.title.Comment = ['This process EEG channels from BioSemi system to the 10-10 EEG standard.<BR>' ...
                                      'Only <B>16</B>, <B>32</B> and <B>64</B> electrode caps are supported.<BR>'];
    sProcess.options.title.Type    = 'label';

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) 
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) 
    OutputFiles = {};
    % Get channel file
    sChannel = bst_get('ChannelForStudy', [sInputs.iStudy]);
    % Rename EEG channels in channel file
    [ChannelFileRenamed, errorMsg] = Compute(sChannel.FileName);
    if ~isequal(ChannelFileRenamed, sChannel.FileName) || ~isempty(errorMsg)
        bst_report('Error', sProcess, [], errorMsg);
    end
    % Return input files
    OutputFiles = {sInputs.FileName};
end

%% ===== INTERACTIVE CALL =====
function ComputeInteractive(ChannelFile)
    [~, errorMsg] = Compute(ChannelFile);
    if ~isempty(errorMsg)
        bst_error(errorMsg, 'Rename EEG BioSemi channels', 0);
    else
        java_dialog('msgbox', 'EEG BioSemi channels were renamed.');
    end
end

%% ===== RENAME CHANNELS =====
function [ChannelFileNew, errorMsg] = Compute(ChannelFile)
    ChannelFileNew = '';
    errorMsg = '';
    % Load channel file
    ChannelMat = in_bst_channel(ChannelFile, 'Channel', 'History');
    % Verify that EEG channels name form a valid BioSemi cap
    eegIxs = strcmpi({ChannelMat.Channel.Type}, 'EEG');
    if ~any(eegIxs)
        errorMsg = sprintf('There are not EEG channels in channel file: %s', ChannelFile);
        return
    end
    % Remove zeros at left from BioSemi channel names, A001 --> A1 or A01 --> A1)
    eegChannelNames = cellfun(@(x)regexprep(x, '0(?=[1-9])', ''), {ChannelMat.Channel(eegIxs).Name}, 'UniformOutput', false);
    nEegChannels = length(eegChannelNames);
    % Check that EEG channels correspond to a BioSemi cap
    if ~ismember(nEegChannels, [16, 32, 64])
        errorMsg = sprintf('Number of EEG channels is %d. It must be 16, 32 or 64', nEegChannels);
        return
    end
    % Get BioSemi mapping
    biosemiMap = GetBiosemiMap(nEegChannels);
    % Find channels in map
    [C, iMissing, iExtra] = setxor(biosemiMap(1,:), eegChannelNames, 'stable');
    if ~isempty(C)
        if ~isempty(iMissing)
            missingChannels = cellfun(@(c)cat(2,' ',c), biosemiMap(1, iMissing), 'UniformOutput', 0);
            errorMsg = [errorMsg, 'Missing EEG channels:', missingChannels{:}, 10];
        end
        if ~isempty(iExtra)
            extraChannels = cellfun(@(c)cat(2,' ',c), eegChannelNames(iExtra), 'UniformOutput', 0);
            errorMsg = [errorMsg, 'Extra EEG channels:', extraChannels{:}, 10];
        end
        return
    end
    % Mapping
    [~,ib] = ismember(eegChannelNames, biosemiMap(1,:));
    [ChannelMat.Channel(eegIxs).Name] = biosemiMap{2,ib};
    ChannelMatNew.Channel = ChannelMat.Channel;
    % Add in History
    ChannelMatNew.History = ChannelMat.History;
    ChannelMatNew = bst_history('add', ChannelMatNew, 'edit', 'Channel names renamed to 10-10 system according BioSemi caps.');
    % Update file
    bst_save(file_fullpath(ChannelFile), ChannelMatNew, 'v7', 1);
    ChannelFileNew = ChannelFile;
end

%% ===== BIOSEMI CAPS =====
function biosemiMap = GetBiosemiMap(capSize)
    switch capSize
        case 16
            biosemiMap = { 'A1',  'A2',  'A5',  'A4',  'A3',  'A6',  'A7',  'A8', ...
                           'A9', 'A10', 'A13', 'A12', 'A11', 'A14', 'A15', 'A16'; ...
                          'Fp1', 'Fp2',  'F3',  'Fz',  'F4',  'T7',  'C3',  'Cz', ...
                           'C4',  'T8',  'P3',  'Pz',  'P4',  'O1',  'Oz',  'O2'};

        case 32
            biosemiMap = { 'A1', 'A30',  'A2', 'A29',  'A3',  'A4', 'A31', 'A27', ...
                          'A28',  'A6',  'A5', 'A26', 'A25',  'A7',  'A8', 'A32', ...
                          'A23', 'A24', 'A10',  'A9', 'A22', 'A21', 'A11', 'A12', ...
                          'A13', 'A19', 'A20', 'A14', 'A18', 'A15', 'A16', 'A17'; ...
                          'Fp1', 'Fp2', 'AF3', 'AF4',  'F7',  'F3',  'Fz',  'F4', ...
                           'F8', 'FC5', 'FC1', 'FC2', 'FC6',  'T7',  'C3',  'Cz', ...
                           'C4',  'T8', 'CP5', 'CP1', 'CP2', 'CP6',  'P7',  'P3', ...
                           'Pz',  'P4',  'P8', 'PO3', 'PO4',  'O1',  'Oz',  'O2'};

        case 64
            biosemiMap = { 'A1',  'B1',  'B2',  'A2',  'A3',  'B5',  'B4',  'B3', ...
                           'A7',  'A6',  'A5',  'A4',  'B6',  'B7',  'B8',  'B9', ...
                          'B10',  'A8',  'A9', 'A10', 'A11', 'B15', 'B14', 'B13', ...
                          'B12', 'B11', 'A15', 'A14', 'A13', 'A12', 'B16', 'B17', ...
                          'B18', 'B19', 'B20', 'A16', 'A17', 'A18', 'A19', 'A32', ...
                          'B24', 'B23', 'B22', 'B21', 'A24', 'A23', 'A22', 'A21', ...
                          'A20', 'A31', 'B25', 'B26', 'B27', 'B28', 'B29', 'A25', ...
                          'A26', 'A30', 'B31', 'B30', 'A27', 'A29', 'B32', 'A28'; ...
                          'Fp1', 'Fpz', 'Fp2', 'AF7', 'AF3', 'AFz', 'AF4', 'AF8', ...
                           'F7',  'F5',  'F3',  'F1',  'Fz',  'F2',  'F4',  'F6', ...
                           'F8', 'FT7', 'FC5', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', ...
                          'FC6', 'FT8',  'T7',  'C5',  'C3',  'C1',  'Cz',  'C2', ....
                           'C4',  'C6',  'T8', 'TP7', 'CP5', 'CP3', 'CP1', 'CPz', ...
                          'CP2', 'CP4', 'CP6', 'TP8',  'P9',  'P7',  'P5',  'P3', ...
                           'P1',  'Pz',  'P2',  'P4',  'P6',  'P8', 'P10', 'PO7', ...
                          'PO3', 'POz', 'PO4', 'PO8',  'O1',  'Oz',  'O2',  'Iz'};

        otherwise
            error('BioSemi cap size %d is not supported.', capSize);
    end
end
