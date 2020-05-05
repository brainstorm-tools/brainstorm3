function varargout = process_nwb_convert( varargin )
% PROCESS_CTF_CONVERT: Convert NWB file epoched/continuous
%
% USAGE:  process_ctf_convert('Compute', filename, 'continuous')
%         process_ctf_convert('Compute', filename, 'epoch')

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
% Authors: Konstantinos Nasiotis 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert to continuous (NWB)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 19;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ReviewRaw#Epoched_vs._continuous';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Option: Epoched/continuous
    sProcess.options.rectype.Comment = {'Epoched', 'Continuous'};
    sProcess.options.rectype.Type    = 'radio';
    sProcess.options.rectype.Value   = 2;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.Comment ': ' sProcess.options.rectype.Comment{sProcess.options.rectype.Value}];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Options
    switch (sProcess.options.rectype.Value)
        case 1,  recType = 'epoch';
        case 2,  recType = 'continuous';
        case 3,  recType = 'switch';
    end
    isInteractive = isfield(sProcess.options, 'interactive') && isequal(sProcess.options.interactive.Value, 1);
    
    ChannelFile = sProcess.options.ChannelFile;
    ChannelMat = in_bst_channel(ChannelFile.Value);
    
    % Convert all the files in input
    for i = 1:length(sInputs)
        % Load file
        DataFile = file_fullpath(sInputs(i).FileName);
        DataMat = in_bst_data(DataFile);
        sFile = DataMat.F;

        % Convert
        [sFile, Messages, outRecType] = Compute(sFile, recType, ChannelMat);
        % Error handling
        if isempty(sFile) && ~isempty(Messages)
            if isInteractive
                bst_error(Messages, 'Convert NWB file', 0);
            else
                bst_report('Error', sProcess, sInputs(i), Messages);
            end
            continue;
        elseif ~isempty(Messages)
            if isInteractive
                disp([10, 'NWB> ', strrep(Messages, char(10), [10 'NWB> ']), 10]);
            else
                bst_report('Warning', sProcess, sInputs(i), Messages);
            end
        end
        
        % Add history field
        DataMat = bst_history('add', DataMat, 'nwb', ['Converted to ' outRecType '.']);
        % Save new file structure
        DataMat.F    = sFile;
        DataMat.Time = sFile.prop.times;
        bst_save(DataFile, DataMat, 'v6');
        % Conversion successful
        OutputFiles{end+1} = sInputs(i).FileName;
    end
    
    % Interactive mode: close all figures + display message
    if isInteractive
        % Check if there are any loaded continuous datasets
        iDSRaw = bst_memory('GetRawDataSet');
        if ~isempty(iDSRaw)
            bst_memory('UnloadAll', 'Forced');
        end
        % Display a message
        if ~isempty(OutputFiles)
            java_dialog('msgbox', ['File converted to: ' outRecType '.']);
        end
    end
end

    
%% ===== COMPUTE =====
function [sFile, Messages, recType] = Compute(sFile, recType, ChannelMat)
    % ===== PARSE INPUTS =====
    if (nargin < 2)
        recType = 'continuous';
    end
    Messages = [];
    
    % ===== LOAD =====
    % Check that it is an NWB file
    if ~any(strcmpi(sFile.format, {'NWB', 'NWB-CONTINUOUS'}))        
        Messages = 'Conversion from epoched to continuous is only available for NWB files.';
        sFile = [];
        return;
    end
    % Switch
    if strcmpi(recType, 'switch')
        if strcmpi(sFile.format, 'NWB-CONTINUOUS')
            recType = 'epoch';
        else
            recType = 'continuous';
        end
    end
    
    % ===== CONVERT => CONTINUOUS =====
    if strcmpi(recType, 'continuous')
        % Check if loaded file is epoched
        if isempty(sFile.epochs) || (length(sFile.epochs) == 1) || strcmpi(sFile.format, 'NWB-CONTINUOUS')
            Messages = 'Only the files that contain two epochs or more can be converted to continuous files.';
            sFile = [];
            return;
        end
       
        % Remove epochs 
        sFile.epochs = [];
        
        % Assign all events to epoch1
        for iEvent = 1:length(sFile.events)
            sFile.events(iEvent).epochs =ones(1,length(sFile.events(iEvent).epochs));
        end
            
        sFile.format = 'NWB-CONTINUOUS';

    % ===== CONVERT => EPOCHED =====
    elseif strcmpi(recType, 'epoch')
        % Check if loaded file is epoched
        if ~isempty(sFile.epochs) || strcmpi(sFile.format, 'NWB')
            Messages = 'Only the files that are forced to continuous mode can be converted back to epoched mode.';
            return;
        end
        
        %% Initialize EPOCHS and EVENTS structure
        nwb2 = sFile.header.nwb;
        [sFile, nEpochs] = in_trials_nwb(sFile, nwb2);
        
        % Assign events to the appropriate epochs
        events = in_events_nwb(sFile, nwb2, nEpochs, ChannelMat);
        sFile.events = events;
    end
end


