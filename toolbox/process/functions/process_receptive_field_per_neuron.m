function varargout = process_receptive_field_per_neuron( varargin )
% PROCESS_RECEPTIVE_fIELD_PER_NEURON: Computes the (spatial) receptive field of
% a neuron

% THIS FUNCTION CAN BE USED ON THE RAW - LFP SIGNALS AFTER SPIKE-SORTING

% It assumes that the user selects time segments were the animal's
% location-gaze is recorded. If the user selects periods were the location
% is not recorded, the importer should import those signals as NaN values.


% Users input the x,y channels they want and a grid-bin-size
% 
% USAGE:    sProcess = process_rasterplot_per_neuron('GetDescription')
%        OutputFiles = process_rasterplot_per_neuron('Run', sProcess, sInput)

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
% Authors: Konstantinos Nasiotis, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Receptive Fields';
    sProcess.FileTag     = 'raster';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1509;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Time window
    sProcess.options.timewindow.Comment = 'Time window: ';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Event name
    sProcess.options.eventname.Comment = 'Event name (empty=continuous): ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Event window
    sProcess.options.eventtime.Comment = 'Event window (ignore if no event): ';
    sProcess.options.eventtime.Type    = 'range';
    sProcess.options.eventtime.Value   = {[-.200, .200], 'ms', []};
    % ==== Parameters 
    sProcess.options.label1.Comment = '<BR><U><B>Select 2 sensors for X,Y axis</B></U>:';
    sProcess.options.label1.Type    = 'label';
    % Options: Sensor types
    sProcess.options.sensornames.Comment = 'Sensor names: ';
    sProcess.options.sensornames.Type    = 'text';
    sProcess.options.sensornames.Value   = 'OpenFieldPositionx, OpenFieldPositiony';
    % Options: Bin size
    sProcess.options.binsize.Comment = 'Grid bin size: ';
    sProcess.options.binsize.Type    = 'text'; % I HAD VALUE HERE AND IT DOESNT LET ME PUT 2 DECIMAL VALUES
    sProcess.options.binsize.Value   = '0.01';
%     % Options: Bin size
%     sProcess.options.binsize.Comment = 'Grid bin size: ';
%     sProcess.options.binsize.Type    = 'value'; % I HAD VALUE HERE AND IT DOESNT LET ME PUT 2 DECIMAL VALUES
%     sProcess.options.binsize.Value   = {0.01, 'cm', 10};
    % Options: Parallel Processing
    sProcess.options.paral.Comment = 'Parallel processing';
    sProcess.options.paral.Type    = 'checkbox';
    sProcess.options.paral.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned values
    OutputFiles = {};
    % Extract method name from the process name
    strProcess = strrep(strrep(func2str(sProcess.Function), 'process_', ''), 'data', '');
    strOptions = '=> ';
    
    
                        %%%%%%%%%%%%%%% I HAD VALUE HERE AND IT DOESNT LET
                        %%%%%%%%%%%%%%% ME PUT 2 DECIMAL VALUES %%%%%%%%%%
                        % Bin size
                        a = cell(1,3);
                        a{1} = str2num(sProcess.options.binsize.Value);
                        a{2} = ' cm';
                        sProcess.options.binsize.Value = a; clear a
                        bin_size = sProcess.options.binsize.Value{1};
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
%     % Bin size
%     if isfield(sProcess.options, 'binsize') && ~isempty(sProcess.options.binsize) && ~isempty(sProcess.options.binsize.Value) && iscell(sProcess.options.binsize.Value) && sProcess.options.binsize.Value{1} > 0
%         bin_size = sProcess.options.binsize.Value{1};
%     else
%         bst_report('Error', sProcess, sInputs, 'Positive bin size required.');
%         return;
%     end
    
    % Get time window
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    % Get options values
    if isfield(sProcess.options, 'eventname') && isfield(sProcess.options.eventname, 'Value') && ~isempty(sProcess.options.eventname.Value)
        % Event name
        evtName = strtrim(sProcess.options.eventname.Value);
        if isempty(evtName)
            bst_report('Warning', sProcess, [], 'Event name is not specified: starting from the beginning of the file.');
        end
        strOptions = [strOptions, 'Event=' evtName ', '];
    else
        evtName = [];
    end
    % Event time window (only used if event is a point in time, not a window)
    if isfield(sProcess.options, 'eventtime') && isfield(sProcess.options.eventtime, 'Value') && ~isempty(sProcess.options.eventtime.Value) && ~isempty(sProcess.options.eventtime.Value{1}) && ~isempty(evtName)
        evtTimeWindow = sProcess.options.eventtime.Value{1};
        strOptions = [strOptions, sprintf('Epoch=[%1.3f,%1.3f]s, ', evtTimeWindow(1), evtTimeWindow(2))];
    else
        evtTimeWindow = [];
    end
    
                                            
                                            
    %% Prepare parallel pool, if requested
    if sProcess.options.paral.Value
        try
            poolobj = gcp('nocreate');
            if isempty(poolobj)
                parpool;
            end
        catch
            sProcess.options.paral.Value = 0;
        end
    else
        poolobj = [];
    end
                                        
    
    
    %% What should be used - TimeWindow or Events' Windows
    if ~isempty(TimeWindow)
        if isempty(evtTimeWindow)
            useEvents     = 0;
        else
            useEvents     = 1;
            warning 'Using events-time window, not the data time window'
        end
    else
        if ~isempty(evtTimeWindow)
            useEvents     = 1;
        else
            bst_report('Error', sProcess, [], 'Both the time window and the events time window are empty');
        end
    end
    
    
    
    %%
    nFiles = length(sInputs);
    
    % Process each even group seperately
    for iFile = 1:nFiles
        sCurrentInput = sInputs(iFile);
        
        
        
        % === OUTPUT STUDY ===
        % Get output study
        [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sCurrentInput);
        tfOPTIONS.iTargetStudy = iStudy;


        % Get channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        % Load channel file
        ChannelMat = in_bst_channel(sChannel.FileName);

        %% Check That the channels selected exist in the dataset
        channels_labels = {ChannelMat.Channel.Name}';
        
        selected_channels = strsplit(sProcess.options.sensornames.Value);
        channels_exist  = sum(ismember(channels_labels, selected_channels))==2; % Both selected channels exist in the ChannelMat
        
        if ~channels_exist 
            bst_report('Error', sProcess, sCurrentInput, 'One or both of the selected channels are not present in this dataset'); % Doesn't this work??
            error('One or both of the selected channels are not present in this dataset');
        end

        selected_channel_indices = find(ismember(channels_labels, selected_channels));

        %% Get Events
        
        DataMat = in_bst(sCurrentInput.FileName,[],0); % Load just the header, that also contains events
        
        Fs = DataMat.F.prop.sfreq;
        
        events = DataMat.F.events;
        
        
        %% Create a cell that holds all of the labels of the Neurons
        labelsForDropDownMenu = {};
        for iEvent = 1:length(events)
            if process_spikesorting_supervised('IsSpikeEvent', events(iEvent).label)
                labelsForDropDownMenu{end+1} = events(iEvent).label;
            end
        end
        labelsForDropDownMenu = unique(labelsForDropDownMenu,'stable')';
        
        nNeurons = length(labelsForDropDownMenu);
        %% Check if the events selected exist in the Dataset
        if useEvents
            events_labels = {events.label}';
            events_exist = sum(find(ismember(events_labels, evtName)));
            
            
            if events_exist
                
            
            
            
            else
                
                bst_report('Warning', sProcess, [], 'Event name does not exist in this file, skipping...');
                create_file = 0;
                
                
            end
            
            
        else % Using the Time-Window
            
          
            
            % Load the needed channels only for the selected Time-window
            [location, TimeVector] = in_fread(DataMat.F, ChannelMat, [], round(TimeWindow * Fs), selected_channel_indices);
            
            
%             figure;plot(F(1,:), F(2,:),'.');
            
            
        end
        
        
        
        %% Create a grid based on the size that the user selected
        location   = location(:,~isnan(location(1,:)));
        TimeVector = TimeVector(:,~isnan(location(1,:))); % Get rid of the timestamps were no location Data exist
        
        minX = min(location(1,:));
        maxX = max(location(1,:));
        minY = min(location(2,:));
        maxY = max(location(2,:));
        
        
        xAxis = minX:sProcess.options.binsize.Value{1}:maxX;
        yAxis = minY:sProcess.options.binsize.Value{1}:maxY;
        
        rf = zeros(nNeurons, length(xAxis), length(yAxis));
        
        
        if ~isempty(location)
            if sProcess.options.paral.Value
                parfor iNeuron = 1:length(labelsForDropDownMenu)
                    rf(iNeuron,:,:) = create_rf(iNeuron, labelsForDropDownMenu, xAxis, yAxis, events, location, TimeVector);
                end
            else
                for iNeuron = 1:length(labelsForDropDownMenu)
                    rf(iNeuron,:,:) = create_rf(iNeuron, labelsForDropDownMenu, xAxis, yAxis, events, location, TimeVector);
                end
            end
            create_file = 1;
        else
            create_file = 0;
        end
        
        
        
        figure(100);plot(location(1,:),location(2,:),'.')
        
        
        
        %% Build the output file
        if create_file
            
            tfOPTIONS.ParentFiles = {sCurrentInput.FileName};

            % Prepare output file structure
            FileMat.TF            = rf;
            FileMat.Time          = xAxis;
            FileMat.TFmask        = true(size(rf,2), size(rf,3));
            FileMat.Freqs         = yAxis;
            FileMat.Std           = [];
            FileMat.Comment       = ['Receptive Field Plot: ' ];
            FileMat.DataType      = 'data';
            FileMat.TimeBands     = [];
            FileMat.RefRowNames   = [];
            FileMat.RowNames      = labelsForDropDownMenu;
            FileMat.Measure       = 'power';
            FileMat.Method        = 'morlet';
            FileMat.DataFile      = []; % Leave blank because multiple parents
            FileMat.SurfaceFile   = [];
            FileMat.GridLoc       = [];
            FileMat.GridAtlas     = [];
            FileMat.Atlas         = [];
            FileMat.HeadModelFile = [];
            FileMat.HeadModelType = [];
            FileMat.nAvg          = [];
            FileMat.ColormapType  = [];
            FileMat.DisplayUnits  = [];
            FileMat.Options       = tfOPTIONS;
            FileMat.History       = [];

            % Add history field
            FileMat = bst_history('add', FileMat, 'compute', ...
                ['Receptive Field per neuron: ' num2str(bin_size) ' cm']);


            % Get output study
            sTargetStudy = bst_get('Study', iStudy);
            % Output filename
            FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_rf');
            OutputFiles = {FileName};
            % Save output file and add to database
            bst_save(FileName, FileMat, 'v6');
            db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
        end
    end
        
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_timefreq: Success');
end





function grid = create_rf(iNeuron, labelsForDropDownMenu, xAxis, yAxis, events, location, TimeVector)

    grid = zeros(length(xAxis), length(yAxis));
    
    indexNeuronEvent = find(ismember({events.label}, labelsForDropDownMenu{iNeuron}));   
    
    
    %% Check which TimeVector sample is closest to each Spike
    [~, iSpikeTime] = histc(events(indexNeuronEvent).times, TimeVector); % Selected spikes within the TimeVector
    SpikesBinsOccurences = find(iSpikeTime);
    
    [~, TimeVectorBinsOccurences] = histc(events(indexNeuronEvent).times(SpikesBinsOccurences), TimeVector); % Selected TimeVector samples close to the selected spikes

       
    %% Now check on which cell of the grid the spikes occured
    
    [~, iX] = histc(location(1,TimeVectorBinsOccurences), xAxis); % These start from 0 and go up to 19 (for a 20x20 grid) - I add 1 to align it properly - CHECK THAT THIS IS CORRECT
    [~, iY] = histc(location(2,TimeVectorBinsOccurences), yAxis); % These start from 0 and go up to 19 (for a 20x20 grid) - I add 1 to align it properly - CHECK THAT THIS IS CORRECT
    
    iX = iX + 1; % These start from 0 and go up to 19 (for a 20x20 grid) - I add 1 to align it properly - CHECK THAT THIS IS CORRECT
    iY = iY + 1; % These start from 0 and go up to 19 (for a 20x20 grid) - I add 1 to align it properly - CHECK THAT THIS IS CORRECT
    
    % Get unique combinations of iX and iY
    [iXY,~,ic] = unique([iX;iY]', 'rows','stable');
    numoccurences = accumarray(ic, 1);
    
    for ii = 1:size(iXY,1)
        grid(iXY(ii,1),iXY(ii,2)) = numoccurences(ii);
    end
    
    
    %% Get the normalization Kernel - Occupancy Kernel
    kernel = zeros(length(xAxis), length(yAxis));

    [~, iX] = histc(location(1,:), xAxis);
    [~, iY] = histc(location(2,:), yAxis);
    
    iX = iX + 1; % These start from 0 and go up to 19 (for a 20x20 grid) - I add 1 to align it properly - CHECK THAT THIS IS CORRECT
    iY = iY + 1; % These start from 0 and go up to 19 (for a 20x20 grid) - I add 1 to align it properly - CHECK THAT THIS IS CORRECT
    
    % Get unique combinations of iX and iY
    
    [iXY,~,ic] = unique([iX;iY]', 'rows','stable');
    
    numoccurences = accumarray(ic, 1);
    
    for ii = 1:size(iXY,1)
        kernel(iXY(ii,1),iXY(ii,2)) = numoccurences(ii);
    end
    
    kernel(kernel == 0) = 1;
    
    grid = grid./kernel;
    
 
%     figure; imagesc(kernel)
    

end


