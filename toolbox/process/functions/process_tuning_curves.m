function varargout = process_tuning_curves( varargin )

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
% Authors: Martin Cousineau, 2018
%          Konstantinos Nasiotis, 2018
%          Francois Tadel, 2022
%          Raymundo Cassani, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Tuning curves';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1210;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % === EVENTS SELECTION ===
    sProcess.options.label1.Comment   = 'Select which events to plot (X axis) and spikes (Y axis) to count.';
    sProcess.options.label1.Type      = 'label';
    sProcess.options.eventsel.Comment = 'Conditions';
    sProcess.options.eventsel.Type    = 'event_ordered';
    sProcess.options.eventsel.Value   = {};
    sProcess.options.eventsel.Spikes  = 'exclude';
    % === SPIKES SELECTION ===
    sProcess.options.spikesel.Comment = 'Neurons';
    sProcess.options.spikesel.Type    = 'event';
    sProcess.options.spikesel.Value   = {};
    sProcess.options.spikesel.Spikes  = 'only';
    % === SELECT: TIME WINDOW
    sProcess.options.timewindow.Comment    = 'Time window:';
    sProcess.options.timewindow.Type       = 'range';
    sProcess.options.timewindow.Value      = {[0, 0.150],'ms',[]};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    OutputFiles = {};
    
    % Check if the user actually selected Neurons and Conditions
    if ~isfield(sProcess.options, 'spikesel') || isempty(sProcess.options.spikesel.Value)
        bst_report('Error', sProcess, sInput, 'You have to select the Neurons that will be displayed');
        return;
    end
    if ~isfield(sProcess.options, 'eventsel') || isempty(sProcess.options.eventsel.Value)
        bst_report('Error', sProcess, sInput, 'You have to select the Conditions that will be displayed');
        return;
    elseif length(sProcess.options.eventsel.Value) < 2
        bst_report('Error', sProcess, sInput, 'You should select at least two Conditions to be displayed');
        return;
    end

    % Read the link to raw file and the Events
    raw_link = in_bst_data(sInput.FileName);
    events = raw_link.F.events;    
    allEventLabels = {events.label}';

    % Initialize the output file. Its size will be nNeurons x nEvents selected
    final_matrix = cell(length(sProcess.options.spikesel.Value),length(sProcess.options.eventsel.Value));
            
    % Compute the spikes in the bin around the Events selected
    for iNeuron = 1:length(sProcess.options.spikesel.Value)
        index_NeuronEvents = find(ismember(allEventLabels, sProcess.options.spikesel.Value{iNeuron})); % Find the index of the spike-events that correspond to that electrode (Exact string match)
        times_NeuronEvents = events(index_NeuronEvents).times;
        % Get closest index for spike event in the time vector
        times_NeuronEventsIx = times_NeuronEvents;        
        for ifor = 1 : length(times_NeuronEvents)
            [~, times_NeuronEventsIx(ifor)] = min(abs(raw_link.Time - times_NeuronEvents(ifor)));
        end
        
        for iEvent = 1:length(sProcess.options.eventsel.Value)
            index_StimulusEvents = find(ismember(allEventLabels, sProcess.options.eventsel.Value{iEvent})); % Find the index of the spike-events that correspond to that electrode (Exact string match)
            times_StimulusEvents = events(index_StimulusEvents).times;
            final_matrix{iNeuron, iEvent} = zeros([1,length(times_StimulusEvents)]);
            for iSampleEvent = 1:length(times_StimulusEvents)
                % Get closet index for requested window around the Events selected
                iTime = panel_time('GetTimeIndices', raw_link.Time, times_StimulusEvents(iSampleEvent) + sProcess.options.timewindow.Value{1});
                % Count spikes
                number_spikes = sum((times_NeuronEventsIx >= iTime(1)) & (times_NeuronEventsIx <= iTime(end)));                                               
                final_matrix{iNeuron, iEvent}(iSampleEvent) = number_spikes;
            end
        end
        
       
        % Initialize the 3 vectors that will be plotted (mean, and 95% confidence intervals)   
        meanData = zeros(1,length(sProcess.options.eventsel.Value));
        CI = zeros(2,length(sProcess.options.eventsel.Value));
        
        
        % Assign the confidence intervals values
        for iCondition = 1:length(sProcess.options.eventsel.Value)
            y = final_matrix{iNeuron,iCondition}./(sProcess.options.timewindow.Value{1}(2) - sProcess.options.timewindow.Value{1}(1)); % Convert to firing rate
            meanData(iCondition) = mean(y);
            
            % Compute the 95% confidence intervals
            RESAMPLING = 1000; % Number of permutations
            
            if length(y)>1
                CI(:,iCondition) = bootci(RESAMPLING, {@mean, y}, 'type','cper','alpha',0.05);
            else
                CI(:,iCondition) = [0;0];
            end
        end

        
            
        %% Create the plot
        %TODO: brainstorm figure?
        figure(iNeuron); % Each Link to Raw file figure set will be separated by an index of 100.
        set(gcf, 'Name', sProcess.options.spikesel.Value{iNeuron});
        
        x = 1:length(sProcess.options.eventsel.Value);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%% MARTIN - THIS NEEDS TO BE SUBSTITUTED WITH
        %%%%%%%%%%%%%%%%%% THE BRAINSTORM FUNCTIONS THAT DISPLAY THE
        %%%%%%%%%%%%%%%%%% HALO.
        %%%%%%%%%%%%%%%%%% Vectors to be plotted:
        %%%%%%%%%%%%%%%%%% 1. meanData (that will be the center vector)
        %%%%%%%%%%%%%%%%%% 2. CI(1,:) (Bottom confidence interval)
        %%%%%%%%%%%%%%%%%% 3. CI(2,:) (Top confidence interval)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        
        % Create the plot with the confidence intervals
        plot(x, CI(1,:), 'k--', 'LineWidth', 1.5);
        hold on;
        plot(x, CI(2,:), 'k--', 'LineWidth', 1.5);
        
        x2 = [x, fliplr(x)];
        inBetween = [CI(1,:), fliplr(CI(2,:))];
        fill(x2, inBetween, 'g','FaceAlpha',.4);
        plot(x, meanData,'LineWidth', 2)

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              
        set(gca, 'Xtick', 1:length(sProcess.options.eventsel.Value), 'Xticklabel', sProcess.options.eventsel.Value);
        xlabel('Condition');
        ylabel('Firing rate (spikes/s)');
        grid on
            
        if max(CI(2,:)) == 0
            axis([0 length(sProcess.options.eventsel.Value)+1 0 Inf]);
        else
            axis([0 length(sProcess.options.eventsel.Value)+1 0 max(CI(2,:)) + std(CI(2,:))]);
        end
    end
end

