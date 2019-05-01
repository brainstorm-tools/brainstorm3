function [sEvents, isModified] = struct_fix_events(sEvents)
% STRUCT_FIX_EVENTS: Fix events structures with latest prototype

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
% Authors: Francois Tadel, 2019

isModified = 0;

% Compare with template structure
sTemplate = db_template('event');
% If empty, return the template
if isempty(sEvents)
    sEvents = repmat(sTemplate, 1, 0);
    return;
end
% If the list of fields is different: fix the structure
missingFields = setdiff(fieldnames(sTemplate), fieldnames(sEvents));
if ~isequal(fieldnames(sTemplate), fieldnames(sEvents))
    if ~isempty(missingFields)
        disp(['BST> Warning: Adding missing events fields: ' sprintf('%s ', missingFields{:})]);
    else
        disp('BST> Warning: Reordering fields in events structure...');
    end
    sEvents = struct_fix(sTemplate, sEvents);
    isModified = 1;
end
% Fix the dimensions of all the fields
for iEvt = 1:length(sEvents)
    nOcc = size(sEvents(iEvt).times, 2);
    if ~isempty(sEvents(iEvt).reactTimes) && (length(sEvents(iEvt).reactTimes) ~= nOcc)
        sEvents(iEvt).reactTimes = [];
    end
    if (length(sEvents(iEvt).channels) ~= nOcc) || ((nOcc >= 1) && ~iscell(sEvents(iEvt).channels))
        sEvents(iEvt).channels = cell(1, nOcc);
        if ~isModified
            disp('BST> Fixed events structure: Wrong number or type of elements in field "channels".');
            isModified = 1;
        end
    end
    if (length(sEvents(iEvt).notes) ~= nOcc) || ((nOcc >= 1) && ~iscell(sEvents(iEvt).notes))
        sEvents(iEvt).notes = cell(1, nOcc);
        if ~isModified
            disp('BST> Fixed events structure: Wrong number or type of elements in field "notes".');
            isModified = 1;
        end
    end
end

