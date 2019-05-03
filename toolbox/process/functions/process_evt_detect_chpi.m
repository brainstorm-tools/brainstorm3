function varargout = process_evt_detect_chpi( varargin )
% PROCESS_EVT_DETECT_CHPI: Detect the activity of continuous head localization (cHPI coils) in Elekta recordings

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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect cHPI activity (Elekta)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 47;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle#Spectral_evaluation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'chpi_bad';
    % Channel name
    sProcess.options.channelname.Comment = 'Channel name: ';
    sProcess.options.channelname.Type    = 'channelname';
    sProcess.options.channelname.Value   = 'STI201';
    % Ignore noisy segments
    sProcess.options.method.Comment = {'Mark as bad when the HPI coils are OFF', ...
                                       'Mark as bad when the HPI coils are ON';   'off', 'on'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'off';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.Comment, ':', sProcess.options.channelname.Value];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>   
    % ===== GET OPTIONS =====
    % Event name
    evtName = strtrim(sProcess.options.eventname.Value);
    chanName = strtrim(sProcess.options.channelname.Value);
    if isempty(evtName) || isempty(chanName)
        bst_report('Error', sProcess, [], 'Event and channel names must be specified.');
        OutputFiles = {};
        return;
    end
    Method = sProcess.options.method.Value;

    % For each file
    iOk = false(1,length(sInputs));
    for iFile = 1:length(sInputs)
        % ===== GET DATA =====
        % Progress bar
        bst_progress('text', 'Reading channel to process...');
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time');
            sFile = DataMat.F;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Time');
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
        end
        % Load channel file
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        % Process only continuous files
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), 'This function can only process continuous recordings (no epochs).');
            continue;
        end
        % Check if specified channels are available
        iChannels = channel_find(ChannelMat.Channel, chanName);
        % Nothing detected
        if isempty(iChannels)
            bst_report('Error', sProcess, sInputs(iFile), ['Channel "' chanName '" doesn''t exist in this file.']);
            continue;
        end
        % Read channel to process
        [F, TimeVector] = in_fread(sFile, ChannelMat, 1, [], iChannels);
        % If nothing was read
        if isempty(F) || (length(TimeVector) < 2)
            bst_report('Error', sProcess, sInputs(iFile), 'Time window is not valid.');
            continue;
        end

        % ===== DETECT ACTIVITY =====
        bst_progress('text', 'Detecting activity...');
        % Detect on or off states
        switch (Method)
            case 'off',   F = (F == 0);
            case 'on',    F = (F ~= 0);
        end
        % Nothing detected
        if (~any(F) || all(F))
            bst_report('Warning', sProcess, sInputs(iFile), ['No change of cHPI activity detected on channel "' chanName '" in this file.']);
            continue;
        end
        % Extend by 1s the detected segments
        sfreq = 1 ./ (TimeVector(2) - TimeVector(1));
        F = (conv(double(F), ones(1,round(sfreq)), 'same') ~= 0); 
        % Perform detection
        diffF = diff([0 F 0]);
        startEve = find(diffF == 1);
        endEve = find(diffF == -1) -1;
        iEve = 1;
        while iEve < length(startEve)-1
            if startEve(iEve + 1) - endEve(iEve) <= minNewEvent
                % combine the two events
                endEve(iEve) = endEve(iEve + 1);
                startEve(iEve+1) = [];
                endEve(iEve+1) = [];
            else
                iEve = iEve + 1;
            end
        end

        % ===== CREATE EVENTS =====
        % Create new event structure
        sEvent = db_template('event');
        sEvent.label   = evtName;
        sEvent.samples = [startEve; endEve] + sFile.prop.samples(1) - 1;
        sEvent.times   = sEvent.samples ./ sFile.prop.sfreq;
        sEvent.epochs  = ones(1, size(sEvent.times,2));
        % Import new events in file structure
        sFile = import_events(sFile, [], sEvent);
        % Report changes in .mat structure
        if isRaw
            DataMat.F = sFile;
        else
            DataMat.Events = sFile.events;
        end
        % Save file definition
        bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
        % Report number of detected events
        bst_report('Info', sProcess, sInputs(iFile), sprintf('%s: %d events detected', chanName, size([sEvent.times],2)));
        iOk(iFile) = true;
    end
    % Return all the input files
    OutputFiles = {sInputs(iOk).FileName};
end




