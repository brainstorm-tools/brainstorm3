function varargout = process_correlogram( varargin )
% PROCESS_RIPPLES_AUTOCORRELOGRAM: Computes the autocorrelogram of ripple
% events
% 
% USAGE:    sProcess = process_ripples_autocorrelogram('GetDescription')
%        OutputFiles = process_ripples_autocorrelogram('Run', sProcess, sInput)

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
% Authors: Konstantinos Nasiotis, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Auto/cross-correlogram';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = {'Peyrache Lab', 'Ripples'};
    sProcess.Index       = 2222;
    sProcess.Description = 'www.peyrachelab.com';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Time window
    sProcess.options.timewindow.Comment = 'Time window: ';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Option: Event name
    sProcess.options.evtname.Comment = 'Event string to look for: ';
    sProcess.options.evtname.Type    = 'text';
    sProcess.options.evtname.Value   = 'Ripple';
    % Event window
    sProcess.options.eventtime.Comment = 'Event window (ignore if no event): ';
    sProcess.options.eventtime.Type    = 'range';
    sProcess.options.eventtime.Value   = {[-30, 30], 's', 3};
    % Options: Bin size
    sProcess.options.nbins.Comment = 'Total number of bins: ';
    sProcess.options.nbins.Type    = 'value';
    sProcess.options.nbins.Value   = {1000, [], 0};
    % Options: Bin size
    sProcess.options.binsize.Comment = 'Bin size: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {0.050, 'ms', 0};
    
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
    
    % Add other options
    Method = strProcess;
    if isfield(sProcess.options, 'sensortypes')
        SensorTypes = sProcess.options.sensortypes.Value;
    else
        SensorTypes = [];
    end
    
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    elseif ~isfield(tfOPTIONS, 'TimeWindow')
        TimeWindow = [];
    end
    
    %% Selected parameters
    selected_string   = sProcess.options.evtname.Value;
    binSize           = sProcess.options.binsize.Value{1}'; % This is in seconds
    TimeWindow_events = sProcess.options.eventtime.Value{1};
    nBins             = sProcess.options.nbins.Value{1};
    
    %% Start computing the correlograms for each RAW file
    for iFile = 1:length(sInputs)
        DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time');
        
        if isempty(TimeWindow)
            TimeWindow = [DataMat.Time(1) DataMat.Time(end)];
        end
        events  = DataMat.F.events;
        
        %% Find the events that contain the selected_string
        iSelectedEvents = find(contains({events.label},selected_string));
        
        %% If an eventType contains only a single event within it, get rid of it. The CrossCorr2 crashes with only one sample input
        keepEventType = true(length(iSelectedEvents),1);
        for iEvent = 1:length(iSelectedEvents)
            if length(events(iSelectedEvents(iEvent)).times) == 1
                keepEventType(iEvent) = false;
            end
        end
        
        iSelectedEvents = iSelectedEvents(keepEventType);
        events = events(iSelectedEvents);
        
        %% If events are extended, convert to simple events
        for iEvent = 1:length(events)
            if size(events(iEvent).times,1) == 2
                events(iEvent).times = mean(events(iEvent).times);
            end
        end
        
        %% Select only the events that are within the boundaries
        for iEvent = 1:length(events)
            keep_events = find(events(iEvent).times-TimeWindow_events(1) > TimeWindow(1) & events(iEvent).times+TimeWindow_events(2) < TimeWindow(2));
            events(iEvent).times = events(iEvent).times(keep_events);
        end
        
        %% Compute the correlograms
        all_correlograms = zeros(((length(events)^2)+length(events))/2,nBins+1);
        all_labels       = cell(((length(events)^2)+length(events))/2,1);
        
        ii = 0;
        for iEvent = 1:length(iSelectedEvents)
            for jEvent = 1:length(iSelectedEvents)
                if iEvent <= jEvent
                    ii = ii+1;
                    if iEvent == jEvent
                        all_labels{ii} = ['AutoCorrelograms (' erase(events(iEvent).label, 'Fast Ripple ') ')'];
                    else
                        all_labels{ii} = ['CrossCorrelograms (' erase(events(iEvent).label, 'Fast Ripple ') ' - ' erase(events(jEvent).label, 'Fast Ripple ') ')'];
                    end
                    
                    [all_correlograms(ii,:), B] = CrossCorr2(events(iEvent).times', events(jEvent).times', binSize, nBins); % THE INPUTS ARE IN SECONDS. THIS SHOULD BE OK.
                    all_correlograms(ii,B==0) = 0; %getting rid of central bin
%                     [A, B] = CrossCorr2(events(iEvent).times, events(jEvent).times, binSize, nBins)
%                     [C,B] = CrossCorr2(t1,t2,binsize,nbins)
                end
            end
        end
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        all_correlograms = all_correlograms/10; % CONFIRM THIS WITH ADRIEN - CROSSCORR2 SEEMS TO GIVE 10 TIMES LARGER VALUES THAN CROSSCORR
        disp('CONFIRM THIS WITH ADRIEN - CROSSCORR2 SEEMS TO GIVE 10 TIMES LARGER VALUES THAN CROSSCORR')
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%         figure(1); imagesc(B, 1:size(all_correlograms,1),all_correlograms)
%         yticks(1:size(all_correlograms,2))
%         yticklabels(all_labels)
%         xlabel 'Time (s)'
%         title 'Correlograms'
        
        %% Fill the fields of the output files for each correlogram separately
        
        [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iFile));
        sTargetStudy = bst_get('Study', iStudy);
        iTargetStudy = db_add_condition(bst_fileparts(sTargetStudy.BrainStormSubject), ['Correlograms_' erase(sTargetStudy.Condition{1},'@raw')], 1);
        
        for iCorrelogram = 1:length(all_labels)
            tfOPTIONS.ParentFiles = {sInputs(iFile).FileName};
            % Prepare output file structure
            FileMat.Value = all_correlograms(iCorrelogram,:);
            FileMat.Std   = [];
            FileMat.Description = {'Correlogram'};
            FileMat.Time = B'; 
            FileMat.DataType = 'recordings';
    %        temp = in_bst(sInputs(iFile).FileName, 'ChannelFlag');
    %        FileMat.ChannelFlag = temp.ChannelFlag;
            FileMat.ChannelFlag  = 1;
            FileMat.nAvg         = 1;
            FileMat.Events       = [];
            FileMat.SurfaceFile  = [];
            FileMat.Atlas        = [];
            FileMat.DisplayUnits = [];
            FileMat.Comment = all_labels{iCorrelogram};

            % Add history field
            FileMat = bst_history('add', FileMat, 'compute', ...
                ['Auto/Cross-correlogram: [' num2str(TimeWindow_events(1)) ', ' num2str(TimeWindow_events(2)) '] s']);
            % Output filename
            FileName = bst_process('GetNewFilename', bst_fullfile(bst_fileparts(sTargetStudy.BrainStormSubject), ['Correlograms_' erase(sTargetStudy.Condition{1},'@raw')]), 'matrix');
            OutputFiles = {FileName};
            % Save output file and add to database
            bst_save(FileName, FileMat, 'v6');
            db_add_data(iTargetStudy, FileName, FileMat);
        end
    end
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_timefreq: Success');
end

%% Function that computes crosscorrelation with set binsize and output selected nbins
% copyright (c) 2004 Francesco P. Battaglia
% This software is released under the GNU GPL
% www.gnu.org/copyleft/gpl.html
function [C,B] = CrossCorr2(t1,t2,binsize,nbins)

    nt1  = length(t1);
    nt2 = length(t2);

    % we want nbins to be odd */
    if floor(nbins / 2)*2 == nbins
        nbins = nbins+1;
    end

    m = - binsize * ((nbins+1) / 2);
    B = zeros(nbins,1);
    for j = 1:nbins
        B(j) = m + j * binsize;
    end

    % cross correlations */

    w = ((nbins) / 2) * binsize;
    C = zeros(nbins,1);
    i2 = 2;

    for i1 = 1:nt1
        lbound = t1(i1) - w;
        while t2(i2) < lbound && i2 < nt2
            i2 = i2+1;
        end
        while t2(i2-1) > lbound && i2 > 2
        i2 = i2-1;
        end

        rbound = lbound;
        l = i2;
        for j = 1:nbins
            k = 0;
            rbound = rbound+binsize;
            while t2(l) < rbound && l < nt2-1  
                l = l+1;
                k = k+1;
            end

          C(j) = C(j)+k;
        end

    end
end