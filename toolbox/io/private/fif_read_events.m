function [Events, ImportOptions] = fif_read_events(sFile, ChannelMat, ImportOptions)
% FIF_READ_EVENTS: Read the events descriptions for a FIF file.
%
% USAGE:  [Events, ImportOptions] = fif_read_events(sFile, ChannelMat, ImportOptions) 
%         [Events, ImportOptions] = fif_read_events(sFile, ChannelMat)
%
% INPUT:  
%     - sFile : Brainstorm structure to pass to the in_fread() function
%     - ImportOptions : Structure that describes how to import the recordings.
%       => Fields used: EventsMode, DisplayMessages
%
% OUTPUT:
%    - Events(i): array of structures with following fields (one structure per event type) 
%        |- label   : Identifier of event #i
%        |- samples : Array of unique time indices for event #i in the corresponding raw file
%        |- times   : Array of unique time latencies (in seconds) for event #i in the corresponding raw file
%                     => Not defined for files read from -eve.fif files

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
% Authors: Francois Tadel, 2009-2019

%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end
   
% Initialize output variable
Events = [];
EventFile = [];
StimChan = [];

% EventsMode: Read from a specific
if iscell(ImportOptions.EventsMode) || ismember(ImportOptions.EventsMode, {ChannelMat.Channel.Name})
    StimChan = ImportOptions.EventsMode;
% EventsMode: Read from a specific file
elseif file_exist(ImportOptions.EventsMode)
    EventFile = ImportOptions.EventsMode;   
% Ignore events
elseif strcmpi(ImportOptions.EventsMode, 'ignore')
    return
% Ask user
elseif strcmpi(ImportOptions.EventsMode, 'ask')
    % Just go through the function and everything that has to be asked
end


%% ===== GET EVENT FILE =====
[fPath, fBase, fExt] = bst_fileparts(sFile.filename);
% If event file is specified
if ~isempty(EventFile)
    % Nothing else to do
    
% If file is already an event file: use this file
elseif (strcmpi(fExt, '.eve') || strcmpi(fExt, '.txt')) || ((length(fBase) > 4) && strcmpi(fBase(end-3:end), '-eve')) || ((length(fBase) > 6) && strcmpi(fBase(end-5:end), '-annot'))
    EventFile = sFile.filename;
    
% Input file is a data file: look for related event file
else
    % mne_browse_raw creates an empty -eve.fif file for each -raw.fif
    % file and events might be stored by user in a separate, ASCII file.
    % Prompt user systematically for event file

    % Look for -eve.fif file
    if file_exist(bst_fullfile(fPath, [fBase, '-eve.fif']))
        evtbase = [fBase, '-eve.fif'];
        EventFile = bst_fullfile(fPath, evtbase);
    % Look for .eve file
    elseif file_exist(bst_fullfile(fPath, [fBase, '.eve']))
        evtbase = [fBase, '.eve'];
        EventFile = bst_fullfile(fPath, evtbase);
    else
        EventFile = '';
    end
    
    % If EventsMode is a channel name: use it
    if ~isempty(StimChan)
        res = 'Event channel';
    % Ask user what to do
    elseif ~isempty(EventFile)
        if isequal(ImportOptions.EventsMode, 'ask')
            res = java_dialog('question', ['An event file was found for this FIF file: ' 10 ...
                                           '"' evtbase '".' 10 10 ...
                                           'Possible options:' 10 ...
                                           '      1) Read this event file' 10 ...
                                           '      2) Specify another event file manually' 10 ...
                                           '      3) Read event channel from .FIF file' 10 ...
                                           '      4) Ignore and import a time range' 10 10], 'FIF event file', ...
                                           [], {'Use file', 'Other file', 'Event channel', 'Ignore'}, 'Use file');
        else
            res = 'Use file';
        end
    else
        if isequal(ImportOptions.EventsMode, 'ask')
            res = java_dialog('question', ['Warning: Event descriptions were not found for this .fif file.' 10 10 ...
                                           'Possible options:' 10 ...
                                           '      1) Specify an event file manually' 10 ...
                                           '      2) Read event channel from .FIF file' 10 ...
                                           '      3) Ignore and import a time range' 10 10], 'FIF event file', ...
                                           [], {'Pick file', 'Event channel', 'Ignore'}, 'Event channel');
        else
            res = 'Ignore';
        end
    end
    % No answer: exit
    if isempty(res)
        ImportOptions.EventsMode = 'ignore';
        return
    end
    % Do what user asked for
    switch (res)
        case 'Use file'
            % Read detected file
            ImportOptions.EventsMode = EventFile;
        case {'Pick file', 'Other file'}
            % Ask for the user event file
            EventFile = java_getfile( 'open', 'FIF event file', fPath, 'single', 'files', ...
                                         {{'.eve', '.fif','.txt'}, 'FIF events files (*.eve,*.fif,*.txt)', 'EVENTS'}, 1);
            if isempty(EventFile)
                return
            end
            ImportOptions.EventsMode = EventFile;
        case 'Event channel'
            % Read events channel
            [Events, EventsTrackMode, StimChan] = process_evt_read('Compute', sFile, ChannelMat, StimChan, 'value');
            EventFile = [];
            ImportOptions.EventsMode = StimChan;
            ImportOptions.EventsTrackMode = EventsTrackMode;
            % Operation cancelled by user
            if isequal(Events, -1)
                return
            end
        case 'Ignore'
            ImportOptions.EventsMode = 'ignore';
            % Return an empty matrix
            return
    end
end

% Read selected file
if ~isempty(EventFile)
    Events = in_events_fif(sFile, EventFile);
end
% No events found
if isempty(Events) && ImportOptions.DisplayMessages
    java_dialog('warning', 'No events were detected.', 'Import events');
end




