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
function sProcess = GetDescription()
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
function Comment = FormatComment(sProcess) 
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) 
    OutputFiles = {};

    % ===== GET CHANNEL FILE  =====
    sChannel = bst_get('ChannelForStudy', [sInputs.iStudy]);

    % ===== VERIFY DEVICE AND BIOSEMI NAMING SYSTEM =====
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName, 'Channel');
    
    % TODO: Check:

    %       - There are EEG channels, AND
    % Find indices of channels with type 'EEG'
    eegIndices = find(strcmpi({ChannelMat.channel.type}, 'EEG'));
    
    % Use the indices to filter the channels
    eegChannels = ChannelMat.channel(eegIndices);
        %       - Current channels names correspond to Biosemi style: A1...A32, B1...B32 C1... and so on, AND
        %         (Be aware of multiple naming e.g., A1 == A01 === A001, ...)

        for i = 1:length(eegChannels)
            newValue = regexprep(value, '0(?=[1-9])', '');
            eegChannels(i) = newValue;   
        end
        %        AND
        %       - All EEG channels make up a Biosemi cap, no 1 channel more, no 1 channel less.
        ChannelMaps=GetBiosemiMapping(eegChannels);
        missingEEGElectrodes = setdiff(keys(ChannelMaps), eegchannels);
        extraEEGElectrodes = setdiff(eegchannels, keys(ChannelMap));

        %       - Otherwise return without changes

        %       - If all conditions are met, then rename channels to 10-10 system according Biosemi caps.
                    %if not, return the missing channels                   
                  
        % Display the results

        if isempty(missingEEGElectrodes) && isempty(extraEEGElectrodes)
                            % Channel data and channel map
                           %channelmap=GetBioSemiCaps(ChannelMat);
                                                       
                            % Call the compute function to rename the channels
                            OutputFiles={eegChannels,ChannelMat}; 
        
         else
                            if ~isempty(missingEEGElectrodes)
                                
                                bst_report('Error', sProcess, [], 'There are missing EEG channels.', num2str(missingElectrodes));
                            end
                            if ~isempty(extraEEGElectrodes)
                               
                                dbst_report('Error', sProcess, [], 'There are extra EEG channels.', num2str(extraElectrodes));
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
    %ChannelFileNew = [];
    ChannelFileFull = file_fullpath(ChannelFile);

    % Load channel file
    ChannelMatOld = in_bst_channel(ChannelFile, 'Channel', 'History');
    eegIndices = find(strcmpi({ChannelMatOld.channel.type}, 'EEG'));
    
    % Use the indices to filter the channels
    eegChannels = ChannelMatOld.channel(eegIndices);


    % TODO: Get maps with GetBiosemiMapping
    %call GetBiosemiMapping
    channelMap=GetBiosemiMaps(eegChannels);
    % TODO: Do name mapping
    numEEGChannels=sum(ChannelMat.Channel.type=='eeg');
         for chan = 1 : numEEGChannels
             ChannelMatOld.Channel(chan) = ChannelMatOld.Channel(chan).replace(channelMap);
         end
    %     ChannelMapOld = getChannelMap();             
       
    ChannelMatNew.Channel = ChannelMatOld.Channel;
    % Add in History
    ChannelMatNew.History = ChannelMatOld.History;
    ChannelMatNew = bst_history('add', ChannelMatNew, 'edit', 'Channel names renamed to 10-10 system according Biosemi caps.');
    % Update file
    bst_save(ChannelFileFull, ChannelMatNew, 'v7', 1);
    ChannelFileNew = file_short(ChannelFileFull);
end

%% ===== NAME MAPS =====
function ChannelMap = GetBiosemiMaps(eegchannels)
%Biosemi structure can be found at: https://www.biosemi.com/headcap.htm
    %ChannelNameMaps = [];
        mapping64 = containers.Map({'A1', 'B1', 'B2', 'A2', 'A3', 'B5', 'B4', 'B3', 'A7', 'A6', 'A5', 'A4', 'B6', 'B7', ...
            'B8', 'B9', 'B10', 'A8', 'A9', 'A10', 'A11', 'B15', 'B14', 'B13', 'B12', 'B11', 'A15', 'A14', 'A13', 'A12', ...
            'B16', 'B17', 'B18', 'B19', 'B20', 'A16', 'A17', 'A18', 'A19', 'A32', 'B24', 'B23', 'B22', 'B21', 'A24', ...
            'A23', 'A22', 'A21', 'A20', 'A31', 'B25', 'B26', 'B27', 'B28', 'B29', 'A25', 'A26', 'A30', 'B31', 'PO8', ...
            'A27', 'A29', 'B32', 'A28'}, {'Fp1', 'Fpz', 'Fp2', 'AF7', 'AF3', 'AFz', 'AF4', 'AF8', 'F7', 'F5', 'F3', ...
            'F1', 'Fz', 'F2', 'F4', 'F6', 'F8', 'FT7', 'FC5', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'FC6', 'FT8', 'T7', ...
            'C5', 'C3', 'C1', 'Cz', 'C2', 'C4', 'C6', 'T8', 'TP7', 'CP5', 'CP3', 'CP1', 'CPz', 'CP2', 'CP4', 'CP6', ...
            'TP8', 'P9', 'P7', 'P5', 'P3', 'P1', 'Pz', 'P2', 'P4', 'P6', 'P8', 'P10', 'PO7', 'PO3', 'POZ', 'PO4', ...
            'O1', 'OZ', 'O2', 'IZ'});

        mapping32 = containers.Map({'A1', 'A30','A2','A29', 'A3','A4' 'A31', 'A27', 'A28', 'A6','A5','A26', 'A25','A7','A8', ...
            'A32', 'A23', 'A24', 'A10', 'A9','A22', 'A21','A11','A12', 'A13','A19', 'A20', 'A14','A18','A15', 'A16','A17'}, ...
            {'Fp1','Fp2', 'AF3','AF4', 'F7','F3', 'Fz','F4', 'F8', 'FC5','FC1','FC2','FC6', 'C3', 'Cz', 'C4', 'T8', 'CP5', ...
            'CP1','CP2','CP6','P7','P3','Pz','P4' 'P8', 'PO3','PO4','O1', 'Oz','O2'});
      
    % TODO: Generate one-to-one channel name maps for Biosemi caps
    %       Maps can be as simple as cell arrays size (nChannels, 2), one column Biosemi, one column 10-10 system
    %       Then comparisons are simpler
    %       Or they can be containers.Map objects- more flexible

    % Create a dictionary-like structure for mapping
    numEEGChannels=sum(eegchannels);
       if numEEGChannels == 32
           ChannelMap = mapping32;        
       elseif numEEGChannels == 64
           ChannelMap = mapping64;   
       else
                      bst_report('Error', sProcess, [], 'The number of channels is not 32 or 64. Please check the channel file.');
       end       
end
