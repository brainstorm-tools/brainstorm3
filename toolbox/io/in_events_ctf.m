function events = in_events_ctf(sFile, EventFile)
% IN_EVENTS_CTF: Read marker information from CTF MarkerFile.mrk located in DS_FOLDER 
%
% USAGE:  events = in_events_ctf(sFile, EventFile)
%
% OUTPUT:
%    - events(i): array of structures with following fields (one structure per event type) 
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
% Authors: Sylvain Baillet, Francois Tadel, 2009-2014
    

% Function 'textread' not recommended after Matb 2014b: replaced with textscan
%txtCell =  textread(EventFile,'%s','delimiter','\n'); 
% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error('CTF> Cannot open file.');
end
% Store everything in a cell array of string
txtCell = textscan(fid,'%s','delimiter','\n');
% Close file
fclose(fid);

% Initialize returned structure
events = repmat(db_template('event'), 0);
% Error reading the file
if isempty(txtCell)
    disp('Events file is empty.');
    return;
end
% Convert textread output (cell(cell)) to textscan (cell)
txtCell = txtCell{1};

% Read number of markers
id = find(strcmp(txtCell,'NUMBER OF MARKERS:'));
nMarkers  = str2num(txtCell{id+1});
% Read marker names
id = find(strcmp(txtCell,'NAME:'));
marker_names = txtCell(id+1);
% Read marker color
id = find(strcmp(txtCell,'COLOR:'));
marker_colors = txtCell(id+1);
% Read marker color
id = find(strcmp(txtCell,'CLASSID:'));
classid = txtCell(id+1);
% Read number of samples for each marker
id = find(strcmp(txtCell,'NUMBER OF SAMPLES:'));
nSamples = str2num(char(txtCell(id+1)));
% Get start of description block for each marker
mrkr_info = strmatch('TRIAL NUMBER',txtCell)+1;
% Loop on each marker
for i = 1:nMarkers
    % Get trial indice and time of all occurrences
    iTrials = mrkr_info(i) + (0:nSamples(i)-1);
    if any(iTrials > length(txtCell))
        disp('IN_EVENTS> Error: Marker file is corrupted, not enough trial samples...');
        iTrials(iTrials > length(txtCell)) = [];
    end
    trial_time = str2num(char(txtCell(iTrials))); 
    % If at least one marker occurrence exists
    if ~isempty(trial_time)
        iEvt = length(events) + 1;
        events(iEvt).label      = marker_names{i};
        events(iEvt).epochs     = trial_time(:,1)' + 1;
        events(iEvt).times      = trial_time(:,2)';
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
        events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
        % Color
        if (length(marker_colors{i}) == 13) && (marker_colors{i}(1) == '#')
            events(iEvt).color = [hex2dec(marker_colors{i}(2:5)), hex2dec(marker_colors{i}(6:9)), hex2dec(marker_colors{i}(10:13))] ./ (256 * 256 - 1);
        end
    end
end

% Remove duplicate events: occur at the first sample of the epoch AND in the previous epoch
if (length(sFile.epochs) > 1) 
    for iEvt = 1:length(events)
        % Skip extended events
        if (size(events(iEvt).times,1) ~= 1) || isempty(events(iEvt).times)
            continue;
        end
        % Get the length of the epoch in samples for each event occurrence
        timeEpoch = reshape([sFile.epochs(events(iEvt).epochs).times], 2, []);
        % Detect if the occurrence is at the first sample of the epoch
        isFirst = (events(iEvt).times - timeEpoch(1,:) == 0);
        % Detect if event is also present in the previous epoch
        isPrev = ismember(max((events(iEvt).epochs - 1), 1), events(iEvt).epochs);
        isPrev(1) = 0;
        % Detect the markers that are doubled: epoch #i AND first sample of epoch #i+1 
        iDouble = find(isFirst & isPrev);
        % Remove these doubled markers (remove the first sample of epoch #i+1)
        if ~isempty(iDouble)
            % Get the times to remove
            tRemoved = [events(iEvt).epochs(1,iDouble); events(iEvt).times(1,iDouble)];
            % Remove the events occurrences
            events(iEvt).times(:,iDouble)   = [];
            events(iEvt).epochs(:,iDouble)  = [];
            if ~isempty(events(iEvt).reactTimes)
                events(iEvt).reactTimes(iDouble) = [];
            end
            events(iEvt).channels(iDouble) = [];
            events(iEvt).notes(iDouble) = [];
            % Display message
            disp(['CTF> Removed ' num2str(length(iDouble)) ' x "' events(iEvt).label, '": ', sprintf('%d(%1.3fs) ', tRemoved)]);
        end
    end
end

% Convert to CTF-CONTINUOUS if necessary
if ~isempty(events) && strcmpi(sFile.format, 'CTF-CONTINUOUS')
    sFile = process_ctf_convert('Compute', sFile, 'epoch');
    sFile.events = events;
    sFile = process_ctf_convert('Compute', sFile, 'continuous');
    events = sFile.events;
end



