function events = in_events_trl(sFile, EventFile)
% IN_EVENTS_TRL: Read events information from a FieldTrip/SPM8 trial definition file (TRL).
%
% USAGE:  events = in_events_trl(sFile, EventFile) 

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015

% ===== READ FILE =====
% Get file extension
[fPath, fBase, fExt] = bst_fileparts(EventFile);
% Mat file
if strcmpi(fExt, '.mat')
    EventMat = load(EventFile);
    TrlMat = double(EventMat.trl);
    evtNames = EventMat.conditionlabels;
% Text file
else
    % Open file 
    fid = fopen(EventFile, 'rt');
    if (fid < 0)
        error('Cannot open file.');
    end
    % Parse file
    readData = textscan(fid, '%d %d %d %s');
    % Close file
    fclose(fid);
    % Check file
    if (length(readData) < 4)
        error('Not a valid trial definition file.');
    end
    % Convert to TRL matrix
    TrlMat = double([readData{1}, readData{2}, readData{3}]);
    evtNames = readData{4};
end



% ===== TIME OFFSET =====
% % Check for offset (typical of FIF files)
% isAddOffset = 0;
% if (sFile.prop.times(1) > 0)
%     res = java_dialog('question', ['The raw data file starts at ' num2str(sFile.prop.times(1)) ' sec.' 10 10 ...
%                                   'Is this offset already added to these events?' 10 10],...
%                                   'Import events', [], {'Yes', 'Add Offset','Cancel'},'Yes');
%     if isempty(res) || strcmpi(res, 'Cancel')
%         bst_progress('stop');
%         return;
%     elseif strcmpi(res, 'Add Offset')
%         isAddOffset = 1;
%     end
% end
% % Add a column for time
% if isAddOffset
%     evtSamples = evtSamples + sFile.prop.samples(1);
% end
TrlMat(:,[1 2]) = TrlMat(:,[1 2]) + sFile.prop.samples(1);


% ===== CONVERT TO BRAINSTORM STRUCTURE =====
% Get the list of unique event names
uniqueEvt = unique(evtNames);
% Initialize list of events
events = repmat(db_template('event'), 1, 2 * length(uniqueEvt));
% Loop on each event category
for iEvt = 1:length(uniqueEvt)
    % Get the indices of this event category
    iTrl = find(strcmpi(uniqueEvt{iEvt}, evtNames));
    % Add event at the trigger
    events(iEvt).label      = uniqueEvt{iEvt};
    events(iEvt).samples    = TrlMat(iTrl,1)' - TrlMat(iTrl,3)';
    events(iEvt).times      = events(iEvt).samples ./ sFile.prop.sfreq;
    events(iEvt).epochs     = ones(1,size(events(iEvt).samples,2));
    events(iEvt).color      = [];
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    % Create extended event to represent the full trial
    iEvtFull = iEvt + length(uniqueEvt);
    events(iEvtFull).label      = [uniqueEvt{iEvt}, '_trial'];
    events(iEvtFull).samples    = TrlMat(iTrl,[1,2])';
    events(iEvtFull).times      = events(iEvtFull).samples ./ sFile.prop.sfreq;
    events(iEvtFull).epochs     = ones(1,size(events(iEvt).samples,2));
    events(iEvtFull).color      = [];
    events(iEvtFull).reactTimes = [];
    events(iEvtFull).select     = 1;
end


