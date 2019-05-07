function varargout = process_ctf_convert( varargin )
% PROCESS_CTF_CONVERT: Convert CTF file epoched/continuous
%
% USAGE:  process_ctf_convert('Compute', filename, 'continuous')
%         process_ctf_convert('Compute', filename, 'epoch')

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
% Authors: Francois Tadel, 2011-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert to continuous (CTF)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 12;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ReviewRaw#Epoched_vs._continuous';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
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
    % Convert all the files in input
    for i = 1:length(sInputs)
        % Load file
        DataFile = file_fullpath(sInputs(i).FileName);
        DataMat = in_bst_data(DataFile);
        sFile = DataMat.F;

        % Convert
        [sFile, Messages, outRecType] = Compute(sFile, recType);
        % Error handling
        if isempty(sFile) && ~isempty(Messages)
            if isInteractive
                bst_error(Messages, 'Convert CTF file', 0);
            else
                bst_report('Error', sProcess, sInputs(i), Messages);
            end
            continue;
        elseif ~isempty(Messages)
            if isInteractive
                disp([10, 'CTF> ', strrep(Messages, char(10), [10 'CTF> ']), 10]);
            else
                bst_report('Warning', sProcess, sInputs(i), Messages);
            end
        end
        
        % Add history field
        DataMat = bst_history('add', DataMat, 'ctf', ['Converted to ' outRecType '.']);
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
function [sFile, Messages, recType] = Compute(sFile, recType)
    % ===== PARSE INPUTS =====
    if (nargin < 2)
        recType = 'continuous';
    end
    Messages = [];
    
    % ===== LOAD =====
    % Check that it is a CTF file
    if ~any(strcmpi(sFile.format, {'CTF', 'CTF-CONTINUOUS'}))        
        Messages = 'Conversion from epoched to continuous is only available for CTF .ds files.';
        sFile = [];
        return;
    end
    % Switch
    if strcmpi(recType, 'switch')
        if strcmpi(sFile.format, 'CTF-CONTINUOUS')
            recType = 'epoch';
        else
            recType = 'continuous';
        end
    end
    
    % ===== CONVERT => CONTINUOUS =====
    if strcmpi(recType, 'continuous')
        % Check if loaded file is epoched
        if isempty(sFile.epochs) || (length(sFile.epochs) == 1) || strcmpi(sFile.format, 'CTF-CONTINUOUS')
            Messages = 'Only the files that contain two epochs or more can be converted to continuous files.';
            sFile = [];
            return;
        end
        % Process each epoch
        for i = 1:length(sFile.epochs)
            % Rebuild absolute sample indices for this file
            nSamples = round((sFile.epochs(i).times(2) - sFile.epochs(i).times(1)) .* sFile.prop.sfreq) + 1;
            if (i == 1)
                epochSmp = [0, nSamples-1];
            else
                epochSmp = [epochSmp; epochSmp(i-1,2) + [1, nSamples]];
            end
        end
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % %%% DETECTION OF DOUBLED EVENTS IS NOW DONW IN IN_EVENTS_CTF %%%
        % %%% Kept here for compatibility purposes, not necessary      %%%
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Update events
        for iEvt = 1:length(sFile.events)
            evtSamples = round(sFile.events(iEvt).times .* sFile.prop.sfreq);
            % Detect events that appear a the last sample of a trial and at the first one of the next one (only for simple events)
            if (size(sFile.events(iEvt).times,1) == 1)
                % Get the length of the epoch in samples for each event occurrence
                smpEpoch = round([sFile.epochs(sFile.events(iEvt).epochs).times] .* sFile.prop.sfreq);
                % Detect if the occurrence is at the first sample or in the last 5 samples
                isLast  = (smpEpoch(2:2:end) - evtSamples < 5);
                isFirst = (evtSamples - smpEpoch(1:2:end) == 0);
                % Detect the markers that are doubled: last sample of epoch #i and first of epoch #i+1 
                iDouble = find(isFirst(2:end) & isLast(1:end-1)) + 1;
            else
                iDouble = [];
            end
            % Process each occurrence of each independent separately
            for iOcc = 1:size(sFile.events(iEvt).times,2)
                % Identify the epoch in which this event is occurring
                iEpoch = sFile.events(iEvt).epochs(iOcc);
                adjustSmp = epochSmp(iEpoch,1) - round(sFile.epochs(iEpoch).times(1) .* sFile.prop.sfreq);
                % Re-refence this event occurrence starting from the beginning of the continuous file (sample 0)
                evtSamples(:,iOcc) = evtSamples(:,iOcc) + adjustSmp;
            end
            % Update times and epoch indice
            sFile.events(iEvt).times  = evtSamples ./ sFile.prop.sfreq;
            sFile.events(iEvt).epochs = ones(size(sFile.events(iEvt).epochs));
            % Remove those doubled markers (remove the first sample of epoch #i+1)
            if ~isempty(iDouble)
                % Get the times to remove
                tRemoved = sFile.events(iEvt).times(1,iDouble);
                % Remove the events occurrences
                sFile.events(iEvt).times(:,iDouble)  = [];
                sFile.events(iEvt).epochs(:,iDouble) = [];
                sFile.events(iEvt).channels(iDouble) = [];
                sFile.events(iEvt).notes(iDouble)    = [];
                if ~isempty(sFile.events(iEvt).reactTimes)
                    sFile.events(iEvt).reactTimes(iDouble) = [];
                end
                % Display message
                Messages = [Messages, 10, 'Removed ' num2str(length(iDouble)) ' x "' sFile.events(iEvt).label, '": ', sprintf('%1.3fs ', tRemoved)];
            end
        end
        % Display message
        if ~isempty(Messages)
            Messages = ['Errors detected in the events of the .ds file (duplicate markers): ' Messages];
        end
        % Remove epochs 
        sFile.epochs = [];
        sFile.prop.times = [epochSmp(1,1), epochSmp(end,2)] ./ sFile.prop.sfreq;
        sFile.format = 'CTF-CONTINUOUS';

    % ===== CONVERT => EPOCHED =====
    elseif strcmpi(recType, 'epoch')
        % Check if loaded file is epoched
        if ~isempty(sFile.epochs) || strcmpi(sFile.format, 'CTF')
            Messages = 'Only the files that are forced to continuous mode can be converted back to epoched mode.';
            return;
        end
        % Initialize epochs structure
        nEpochs = sFile.header.gSetUp.no_trials;
        nSamples = sFile.header.gSetUp.no_samples;
        sFile.epochs = repmat(db_template('epoch'), [1 nEpochs]);
        epochSmp = [0, nSamples - 1] - sFile.header.gSetUp.preTrigPts;
        % Loop on each epoch
        for iEpoch = 1:nEpochs
            % Create new epoch
            sFile.epochs(iEpoch).label = sprintf('Epoch #%d', iEpoch);
            sFile.epochs(iEpoch).times = epochSmp ./ sFile.prop.sfreq;
            % Rebuild initial position of the epoch in the continuous file
            epochCont = [0, nSamples-1] + (iEpoch - 1) * nSamples;
            % Update events
            for iEvt = 1:length(sFile.events)
                % Ignore empty events
                if ~isempty(sFile.events(iEvt).times)
                    % Find occurrences that are included in this epoch
                    evtSmp = round(sFile.events(iEvt).times .* sFile.prop.sfreq);
                    iOcc = find((evtSmp(1,:) >= epochCont(1)) & (evtSmp(1,:) <= epochCont(2)));
                    % Update times and epoch indice
                    if ~isempty(iOcc)
                        % Recompute sample indices
                        evtSmp(:,iOcc) = evtSmp(:,iOcc) - epochCont(1) + epochSmp(1);
                        sFile.events(iEvt).epochs(iOcc)    = repmat(iEpoch, [1, length(iOcc)]);
                        % In case of extended events: end of the event has to be at max the last sample of the epoch
                        if (size(evtSmp,1) == 2)
                            iOutside = find(evtSmp(2,iOcc) > epochSmp(2));
                            if ~isempty(iOutside)
                                Messages = [Messages 'Some extended events had to be cropped to fit a single epoch.' 10];
                                evtSmp(2,iOcc(iOutside)) = epochSmp(2);
                            end
                        end
                        % Convert samples indices in times
                        sFile.events(iEvt).times(:,iOcc) = evtSmp(:,iOcc) ./ sFile.prop.sfreq;
                    end
                end
            end
        end
        % Update the other fields
        sFile.prop.times   = [epochSmp(1), epochSmp(2)] ./ sFile.prop.sfreq;
        sFile.format = 'CTF';
    end
end


