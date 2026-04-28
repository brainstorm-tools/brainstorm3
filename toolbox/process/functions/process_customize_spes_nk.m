function varargout = process_customize_spes_nk( varargin )
% PROCESS_CUSTOMIZE_SPES_NK: Customize SPES blocks imported from 
% Nihon Kohden recordings. This process can rename stimulation start/stop labels,
% rename the stimulation trigger event label and optionally create separate 
% 'ODD' and 'EVEN' events for alternating monophasic stimulation pulses.
%
% USAGE:
%   OutputFiles = process_customize_spes_nk('Run', sProcess, sInputs)

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
% Authors: Chinmay Chinara, 2026
%          John C. Mosher, 2026

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'Customize SPES blocks (Nihon Kohden)';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Stimulation';
sProcess.Index       = 901;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Update 'Stim Start' label in stimulation block name and events
sProcess.options.label1.Comment = '<HTML><I><FONT color="#777777">Update ''Stim Start'' label in stimulation block name and events</FONT></I>';
sProcess.options.label1.Type    = 'label';
sProcess.options.stimstartlabel.Comment = 'Update ''Stim Start'' label (empty=No change): ';
sProcess.options.stimstartlabel.Type    = 'text';
sProcess.options.stimstartlabel.Value   = 'SB';
% Update 'Stim Stop' label in stimulation block events
sProcess.options.label2.Comment = '<HTML><I><FONT color="#777777">Update ''Stim Stop'' label in stimulation block events</FONT></I>';
sProcess.options.label2.Type    = 'label';
sProcess.options.stimstoplabel.Comment = 'Update ''Stim Stop'' label (empty=No change): ';
sProcess.options.stimstoplabel.Type    = 'text';
sProcess.options.stimstoplabel.Value   = 'SE';
% Stimulation trigger event label
sProcess.options.stimeventlabel.Comment = 'Stimulation trigger event label: ';
sProcess.options.stimeventlabel.Type    = 'text';
sProcess.options.stimeventlabel.Value   = 'DC10';
% Update stimulation trigger event label
sProcess.options.newstimeventlabel.Comment = 'Update stimulation trigger event label (empty=No change): ';
sProcess.options.newstimeventlabel.Type    = 'text';
sProcess.options.newstimeventlabel.Value   = 'STIM';
% Add 'ODD' and 'EVEN' events to stimulation blocks
sProcess.options.label3.Comment = '<HTML><I><FONT color="#777777">Add alternating monophasic stimulation trigger events</FONT></I>';
sProcess.options.label3.Type    = 'label';
sProcess.options.addoddevenevents.Comment = 'Add ''ODD'' and ''EVEN'' events';
sProcess.options.addoddevenevents.Type    = 'checkbox';
sProcess.options.addoddevenevents.Value   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize output
    OutputFiles = {};

    % Get proccess options
    StimStartLabel    = sProcess.options.stimstartlabel.Value;
    StimStopLabel     = sProcess.options.stimstoplabel.Value;
    StimEventLabel    = sProcess.options.stimeventlabel.Value;
    NewStimEventLabel = sProcess.options.newstimeventlabel.Value;
    AddOddEvenEvents  = sProcess.options.addoddevenevents.Value;
     
    % Check whether the user requested a custom label
    % If empty, keep the default Nihon Kohden label
    isUpdateStimStartLabel = ~isempty(StimStartLabel);
    if ~isUpdateStimStartLabel
        StimStartLabel = 'Stim Start';
    end
    isUpdateStimStopLabel  = ~isempty(StimStopLabel);
    if ~isUpdateStimStopLabel
        StimStopLabel = 'Stim Stop';
    end   
    
    % Process each SPES block
    for iFile = 1:length(sInputs)
        EventMat =  in_bst_data(sInputs(iFile).FileName, 'Events');
        
        % ===== Update 'Stim Start' label (comment and event) =====
        if isUpdateStimStartLabel           
            % Update comment
            newTag = strrep(sInputs(iFile).Comment, 'Stim Start', StimStartLabel);
            sInputs(iFile) = bst_process('CallProcess', 'process_set_comment', sInputs(iFile), [], ...
                'tag',           newTag, ...
                'isindex',       0);
            % Update event
            iStimStart = find(strncmp({EventMat.Events.label}, 'Stim Start', 10));
            srcTag = EventMat.Events(iStimStart).label;
            destTag = strrep(srcTag, 'Stim Start', StimStartLabel);
            bst_process('CallProcess', 'process_evt_rename', sInputs(iFile), [], ...
                'src',  srcTag, ...
                'dest', destTag);
        end
        
        % ===== Update 'Stim Stop' label (only event) =====
        if isUpdateStimStopLabel
            % Update event
            iStimStop  = find(strncmp({EventMat.Events.label}, 'Stim Stop', 9));
            srcTag = EventMat.Events(iStimStop).label;
            destTag = strrep(srcTag, 'Stim Stop', StimStopLabel);
            bst_process('CallProcess', 'process_evt_rename', sInputs(iFile), [], ...
                'src',  srcTag, ...
                'dest', destTag);
        end
        
        % ===== Add stimulation site info to the stimulation trigger event label =====
        % Extract stimulation site information (e.g. 'SB O6-O7 4.0 (#1)' > 'O6-O7 4.0 #1')
        tokens = regexp(sInputs(iFile).Comment, sprintf('^%s\\s+(.*?)\\s+\\((#\\d+)\\)$', StimStartLabel), 'tokens', 'once');
        stimSiteInfo = sprintf('%s %s', tokens{1}, tokens{2});
        % Append stimulation site information to the trigger event label        
        if ~isempty(NewStimEventLabel)
            % e.g. 'STIM' > 'STIM O6-O7 4.0 #1'
            destTag = sprintf('%s %s', NewStimEventLabel, stimSiteInfo);
        else
            % e.g. 'DC10' > 'DC10 O6-O7 4.0 #1'
            destTag = sprintf('%s %s', StimEventLabel, stimSiteInfo);
        end
        % Process: Rename event
        bst_process('CallProcess', 'process_evt_rename', sInputs(iFile), [], ...
            'src',  StimEventLabel, ...
            'dest', destTag);
        
        % ===== Add alternating monophasic events to stimulation blocks ('ODD' and 'EVEN') =====
        if AddOddEvenEvents                       
            EventMat = in_bst_data(sInputs(iFile).FileName, 'Events');
            % Update color for the stimulation trigger event
            EventMat.Events(end).color = [0.8, 0.8, 0.8]; % Gray
            % Create 'ODD' event from odd-numbered stimulation trigger pulses
            sEventOdd = db_template('event');
            sEventOdd.label  = sprintf('ODD %s', stimSiteInfo);
            sEventOdd.times = EventMat.Events(end).times(1:2:end);
            sEventOdd.epochs = EventMat.Events(end).epochs(1:2:end);
            sEventOdd.color = [0.9, 0, 0]; % Red
            EventMat.Events(end+1) = sEventOdd;
            % Create 'EVEN' event from even-numbered stimulation trigger pulses
            sEventEven = db_template('event');
            sEventEven.label  = sprintf('EVEN %s', stimSiteInfo);
            sEventEven.times = EventMat.Events(end-1).times(2:2:end);
            sEventEven.epochs = EventMat.Events(end-1).epochs(2:2:end);
            sEventEven.color = [ 0, 0, 0.9]; % Blue
            EventMat.Events(end+1) = sEventEven;            
            % Save changes
            bst_save(file_fullpath(sInputs(iFile).FileName), EventMat, 'v7', 1);
        end

        % Add the modified file to the output list
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end