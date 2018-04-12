function varargout = process_tuning_curves( varargin )
% PROCESS_TUNING_CURVES
%
% USAGE: OutputFiles = process_tuning_curves('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Martin Cousineau, Konstantinos Nasiotis 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Tuning Curves';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1203;
    sProcess.Description = 'www.in.gr';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % === EVENTS SELECTION ===
    sProcess.options.label1.Comment = 'Select which events to plot (X axis) and spikes (Y axis) to count.';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.eventsel.Comment = 'Events';
    sProcess.options.eventsel.Type    = 'event_ordered';
    sProcess.options.eventsel.Value   = {};
    sProcess.options.eventsel.Spikes  = 'exclude';
    % === SPIKES SELECTION ===
    sProcess.options.spikesel.Comment    = 'Neurons';
    sProcess.options.spikesel.Type       = 'event';
    sProcess.options.spikesel.Value      = {};
    sProcess.options.spikesel.Spikes  = 'only';
    % === SELECT: TIME WINDOW
    sProcess.options.timewindow.Comment    = 'Time window:';
    sProcess.options.timewindow.Type       = 'range';
    sProcess.options.timewindow.Value      = {[0, 0.150],'ms',[]};
    % === NORMALIZE OUTPUT ===
    sProcess.options.normalize.Comment = 'Normalize Tuning Curve';
    sProcess.options.normalize.Type    = 'checkbox';
    sProcess.options.normalize.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
%     global GlobalData;

    % Check if the user actually selected Neurons and or Conditions
    
    if length(sProcess.options.spikesel.Value) == 0
        error('You have to select in the right box the Neurons that will be displayed'); 
    end
    if length(sProcess.options.eventsel.Value) == 0
        error('You have to select the Conditions that will be displayed'); 
    elseif length(sProcess.options.eventsel.Value) == 1
        error('You should select more Conditions to be displayed'); 
    end

    OutputFiles = {};
    ProtocolInfo = bst_get('ProtocolInfo');
    
    % Compute on each raw input independently
    for iFile = 1:length(sInputs)
        disp(sProcess.options.eventsel.Value);
        disp(sProcess.options.spikesel.Value);
        
        
        % Read the link to raw file and the Events
        raw_link = load(fullfile(ProtocolInfo.STUDIES,sInputs(iFile).FileName));
        events = raw_link.F.events;    
        allEventLabels = {events.label}';

        % Initialize the output file. Its size will be nNeurons x nEvents selected
        final_matrix = zeros(length(sProcess.options.spikesel.Value),length(sProcess.options.eventsel.Value));
        
        % Compute the spikes in the bin around the Events selected
        for iNeuron = 1:length(sProcess.options.spikesel.Value)
            index_NeuronEvents = find(ismember(allEventLabels, sProcess.options.spikesel.Value{iNeuron})); % Find the index of the spike-events that correspond to that electrode (Exact string match)
            times_NeuronEvents = events(index_NeuronEvents).times;
            
            for iEvent = 1:length(sProcess.options.eventsel.Value)
                index_StimulusEvents = find(ismember(allEventLabels, sProcess.options.eventsel.Value{iEvent})); % Find the index of the spike-events that correspond to that electrode (Exact string match)
                times_StimulusEvents = events(index_StimulusEvents).times;
                
                for iSampleEvent = 1:length(times_StimulusEvents)
                    condition_success = sum((times_NeuronEvents>times_StimulusEvents(iSampleEvent)- sProcess.options.timewindow.Value{1}(1)) & (times_NeuronEvents<times_StimulusEvents(iSampleEvent) + sProcess.options.timewindow.Value{1}(2)));
                    if condition_success
                        final_matrix(iNeuron, iEvent) = condition_success;
                    end
                end
            end
            
            
            % Create the plot, and overlap a Shape-Preserving Interpolant fit on it
            figure(iNeuron);

            x = 1:length(sProcess.options.eventsel.Value);
            % Y will be the y points that will be plotted
            if sProcess.options.normalize.Value
                y = final_matrix(iNeuron,:)./max(final_matrix(iNeuron,:));
                set(gcf,'Name',['Normalized : ' sProcess.options.spikesel.Value{iNeuron}])
            else
                y = final_matrix(iNeuron,:);
                set(gcf,'Name',sProcess.options.spikesel.Value{iNeuron})
            end

            % Fit the Shape-Preserving Interpolant
            f = fit(x.',y.','pchip');
            plot(f,x,y)
            set(gca,'Xtick',1:length(sProcess.options.eventsel.Value),'Xticklabel',sProcess.options.eventsel.Value);
            xlabel 'Condition'; ylabel 'Number of Spikes'; legend 'Spikes' 'Fitted Curve';
            if max(y) == 0
                axis([0 length(sProcess.options.eventsel.Value)+1 0 Inf]);
            else
                axis([0 length(sProcess.options.eventsel.Value)+1 0 max(y) + std(y)]);
            end
        end
    end
    
end
    
    
    
