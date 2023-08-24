toolbox/process/functions/process_channel_biosemi.m

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
    if strfind(lower(ChannelMat.Comment), 'eeg'):
        %       - Current channels names correspond to Biosemi style: A1...A32, B1...B32 C1... and so on, AND
        %         (Be aware of multiple naming e.g., A1 == A01 === A001, ...)

        for i in ChannelMat:
            newValue = regexprep(value, '0(?=[1-9])', '');
            ChannelMat(i) = newValue;   

        %        AND
        
        if length(ChannelMat.Channel) == 32:
            channelMap = mapping32;
            
        elseif length(ChannelMat.Channel) == 64:
            channelMap = mapping64;

        else:
            disp('The number of channels is not 32 or 64. Please check the channel file.');
        end

    
        
        % Call the renameChannels function
        newChannels = renameChannels(channels, channelMap);
        
    

    %       - All EEG channels make up a Biosemi cap, no 1 channel more, no 1 channel less.

        missingElectrodes = setdiff(keys(Tentensystem), channels);
        extraElectrodes = setdiff(channels, keys(Tentensystem));

        %       - Otherwise return without changes

        %       - If all conditions are met, then rename channels to 10-10 system according Biosemi caps.

    
                    %if not, return the missing channels                   
                            
                    
        % Display the results
           

        if isempty(missingElectrodes) && isempty(extraElectrodes)
                            % Channel data and channel map
                            channelData = ChannelMat;
                            
                            % Call the renameChannels function
                            newChannels = renameChannels(channelMat, channelMap);
                        else
                            if ~isempty(missingElectrodes)
                                result=missingElectrodes;
                                disp(['Missing electrode numbers:' num2str(missingElectrodes)]);
                            end
                            if ~isempty(extraElectrodes)
                                result=extraElectrodes;
                                disp(['Extra electrode numbers:' num2str(extraElectrodes)]);
                            end
                        end             


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
    %call GetBiosemiMapping
    Channel=GetBiosemiMapping()
    % TODO: Do name mapping
    %     for chan = 1 : size(ChannelMatOld,'C')
    %         ChannelMatOld.Channel(chan) = ChannelMatOld.Channel(chan).replace(ChannelMapOld);
    %     end
    %     ChannelMapOld = getChannelMap();

    % Function to rename the channels
        function renamedChannels = renameChannels(channelMat, channelMap)
            renamedChannels = channelData;  % Initialize with original channel names
            
            % Loop through each channel name
            for i = 1:length(channelData)
                originalName = channelData{i};
                
                % Check if the channel has a mapping in the dictionary
                if isKey(channelMap, originalName)
                    newName = channelMap(originalName);
                    renamedChannels{i} = newName;  % Rename the channel
                end
            end
        end


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

    %     ChannelNameMaps{1}.nameMap = {'Fp1','F3'};
    
    % TODO: Generate one-to-one channel name maps for Biosemi caps
    %       Maps can be as simple as cell arrays size (nChannels, 2), one column Biosemi, one column 10-10 system
    %       Then comparisons are simpler
    %       Or they can be containers.Map objects- since more flexible

    % Create a dictionary-like structure for mapping
        mapping64 = containers.Map({'A1', 'B1', 'B2', 'A2', 'A3', 'B5', 'B4', 'B3', 'A7', 'A6', 'A5', 'A4', 'B6', 'B7', 'B8', 'B9', 'B10', 'A8', 'A9', 'A10', 'A11', 'B15', 'B14', 'B13', 'B12', 'B11', 'A15', 'A14', 'A13', 'A12', 'B16', 'B17', 'B18', 'B19', 'B20', 'A16', 'A17', 'A18', 'A19', 'A32', 'B24', 'B23', 'B22', 'B21', 'A24', 'A23', 'A22', 'A21', 'A20', 'A31', 'B25', 'B26', 'B27', 'B28', 'B29', 'A25', 'A26', 'A30', 'B31', 'PO8', 'A27', 'A29', 'B32', 'A28'}
        , {'Fp1', 'Fpz', 'Fp2', 'AF7', 'AF3', 'AFz', 'AF4', 'AF8', 'F7', 'F5', 'F3', 'F1', 'Fz', 'F2', 'F4', 'F6', 'F8', 'FT7', 'FC5', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'FC6', 'FT8', 'T7', 'C5', 'C3', 'C1', 'Cz', 'C2', 'C4', 'C6', 'T8', 'TP7', 'CP5', 'CP3', 'CP1', 'CPz', 'CP2', 'CP4', 'CP6', 'TP8', 'P9', 'P7', 'P5', 'P3', 'P1', 'Pz', 'P2', 'P4', 'P6', 'P8', 'P10', 'PO7', 'PO3', 'POZ', 'PO4', 'O1', 'OZ', 'O2', 'IZ'});

        mapping32 = containers.Map({'A1', 'A2', 'A3', 'A31', 'A28', 'A5', 'A25', 'A8', 'A23', 'A10', 'A22', 'A11', 'A13', 'A20', 'A18', 'A16'}, {'Fp1', 'AF3', 'F7', 'Fz', 'F8', 'FC1', 'FC6', 'C3', 'C4', 'CP5', 'CP2', 'P7', 'Pz', 'P8', 'PO4', 'Oz'});
        
end
