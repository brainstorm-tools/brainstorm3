function varargout = process_evt_classify( varargin )
% PROCESS_EVT_CLASSIFY: Artifact rejection for a group of recordings file

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
% Authors: Patricia Moscibrodzki, Elizabeth Bock, Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Classify by shape';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 60;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect?highlight=%28Enable+classification%29#Custom_detection';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'blink';   
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensors: ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    % Number of dimension
    sProcess.options.ndims.Comment = 'Number of dimensions: ';
    sProcess.options.ndims.Type    = 'value';
    sProcess.options.ndims.Value   = {10, [], 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.Comment ': ' sProcess.options.eventname.Value];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get options
    evtName = strtrim(sProcess.options.eventname.Value);
    if isempty(evtName)
        bst_report('Error', sProcess, sInput, 'No event selected.');
        return;
    end
    SensorTypes = sProcess.options.sensortypes.Value;
    % Number of dimensions
    ndims = sProcess.options.ndims.Value{1};
       
    % ===== GET DATA =====
    bst_progress('text', 'Reading recordings...');
    % Load the raw file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F');
        sFile = DataMat.F;
    else
        sFile = in_fopen(sInput.FileName, 'BST-DATA');
    end
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    % Get channels to process
    iChannels = channel_find(ChannelMat.Channel, SensorTypes);
    if isempty(iChannels)
        bst_report('Error', sProcess, sInput, 'No channels to process.');
        return;
    end
    % Get selected event
    iEvt = find(strcmpi({sFile.events.label}, evtName));
    if isempty(iEvt)
        bst_report('Error', sProcess, sInput, ['Event "' evtName '" does not exist in file.']);
        return;
    end
    sEvent = sFile.events(iEvt);
    % For extended events: use the middle of the event
    evtSamples = round(mean(sEvent.times .* sFile.prop.sfreq, 1));
    % Initialize concatenated data matrix
    nOcc = size(evtSamples, 2);
    F = zeros(length(iChannels), nOcc);
    % If number of dimensions is larger that number of samples: fix and issue warning
    if (nOcc < ndims)
        bst_report('Warning', sProcess, sInput, sprintf('Number of samples (%d) is smaller than number of dimensions (%d)', nOcc, ndims));
        ndims = nOcc;
    end
    % Reading options
    % NOTE: FORCE READING CLEAN DATA (Baseline correction + CTF compensators + Previous SSP)
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode      = 'Time';
    ImportOptions.UseCtfComp      = 1;
    ImportOptions.UseSsp          = 1;
    ImportOptions.EventsMode      = 'ignore';
    ImportOptions.DisplayMessages = 0;
    ImportOptions.RemoveBaseline  = 'no';
    % Read data for each event
    for iOcc = 1:nOcc
        F(:,iOcc) = in_fread(sFile, ChannelMat, sEvent.epochs(iOcc), [evtSamples(iOcc), evtSamples(iOcc)], iChannels, ImportOptions);
    end
    % Remove average value for each sensor
    F = bst_bsxfun(@minus, F, mean(F,2));

    % ===== CLASSIFY =====
    bst_progress('text', 'Classification...');
    % Decompose the matrix
    [U,S,V] = svd(F,0);
    s = diag(S);
    v = abs(V);
    % Compute the event score
    eventScore = bst_bsxfun(@times, v(:,1:ndims), s(1:ndims)')';
    % Get maximum fit of each event
    [maxx, evtClass] = max(eventScore);

    % ===== CREATE NEW EVENTS ====
    % Initialize new events list
    newEvents = repmat(sEvent, 0);
    % Loop on new events groups
    for iClass = 1:max(evtClass)
        % Get all the occurrences for this category
        iOcc = (evtClass == iClass);
        if isempty(iOcc)
            continue;
        end
        % Create new event category
        iNew = length(newEvents) + 1;
        newEvents(iNew) = sEvent;
        newEvents(iNew).label    = sprintf('%s %02d', sEvent.label, iNew);
        newEvents(iNew).epochs   = sEvent.epochs(iOcc);
        newEvents(iNew).times    = sEvent.times(:,iOcc);
        newEvents(iNew).color    = [];
        newEvents(iNew).channels = cell(1, size(newEvents(iNew).times, 2));
        newEvents(iNew).notes    = cell(1, size(newEvents(iNew).times, 2));
    end
    
    % ===== SAVE MODIFICATIONS =====
    % Remove the initial category
    sFile.events(iEvt) = [];
    % Import events file
    sFile = import_events(sFile, [], newEvents);
    % Report changes in .mat structure
    if isRaw
        DataMat.F = sFile;
    else
        DataMat.Events = sFile.events;
    end
    % Save file definition
    bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
    % Report number of detected events
    bst_report('Info', sProcess, sInput, sprintf('Events classified in %d categories', length(newEvents)));

    % Return the file in input
    OutputFiles = {sInput.FileName};
end


