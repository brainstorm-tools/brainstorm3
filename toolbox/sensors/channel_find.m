function [iChannels, Comment] = channel_find(Channel, target)
% CHANNEL_FIND: Get a list of channels based on their names, types, or indices
%
% USAGE:  [iChannels, Comment] = channel_find(Channel, ChannelTypes)
%         [iChannels, Comment] = channel_find(Channel, ChannelNames)
%         [iChannels, Comment] = channel_find(Channel, List)

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
% Authors: Francois Tadel, 2010-2018

% Select all the channels
if (nargin < 2) || isempty(target)
    iChannels = 1:length(Channel);
    Comment = 'All';
    return
end
if ~iscell(target)
    if any(target == ',') || any(target == ';')
        % Split string based on the commas
        target = strtrim(str_split(target, ',;'));
    else
        target = {strtrim(target)};
    end
end
% Returned variables
iChannels = [];
Comment   = [];
% Get all the channel types
allTypes = upper(unique({Channel.Type}));
allNames = {Channel.Name};
% Add extra types based on the ones existing
if any(ismember(allTypes, {'MEG MAG','MEG GRAD'}))
    allTypes = union(allTypes, {'MEG', 'MEG GRAD2', 'MEG GRAD3'});
end
if any(ismember(allTypes, {'SEEG','ECOG'}))
    allTypes = union(allTypes, {'ECOG+SEEG'});
end
% Process all the targets
for i = 1:length(target)
    % Search by type: return all the channels from this type
    if ismember(upper(strtrim(target{i})), allTypes)
        iChan = good_channel(Channel, [], target{i});
    % Search by channel name
    else
        iChan = find(strcmpi(allNames, target{i}));
        % Search for NIRS channels using Source, Detector or Wavelength
        if isempty(iChan) && ismember('NIRS', allTypes)
            % Find tokens in provided target
            % Token 1: Source,               e.g. 'S1'
            % Token 2: Detector,             e.g. 'D1'
            % Token 1: Wavelength or Metric, e.g. 'WL830'
            target_tokens = regexp(target{i}, '^(S([0-9]+)?)?(D([0-9]+)?)?(WL\d+|HbO|HbR|HbT)?$', 'tokens');
            if isempty(target_tokens)
                continue;
            end 
            target_tokens = target_tokens{1};
            
            % If token not found, replace with wildcard for that token
            if isempty(target_tokens{1})
                target_tokens{1} = 'S([0-9]+)';
            end
            if isempty(target_tokens{2})
                target_tokens{2} = 'D([0-9]+)';
            end
            if isempty(target_tokens{3})
                target_tokens{3} = '(WL\d+|HbO|HbR|HbT)';
            end
            % Find matching NIRS channels
            iAllChanNirs = good_channel(Channel, [], 'NIRS');
            tmp = regexp(allNames, sprintf('^%s%s%s$',target_tokens{1},target_tokens{2},target_tokens{3}), 'tokens');
            iChanNirs = find(cellfun(@(x)~isempty(x), tmp));
            iChanNirs = intersect(iChanNirs, iAllChanNirs);
            % Add NIRS channels to already selected channels
            iChan = union(iChan, iChanNirs);
        end
    end
    % Search by indices
    if isempty(iChan)
        iChan = round(str2num(target{i}));
        iChan(iChan > length(Channel)) = [];
        iChan(iChan < 1) = [];
    end
    % Comment
    if ~isempty(iChan)
        iChannels = [iChannels, iChan];
        if ~isempty(Comment)
            Comment = [Comment, ', '];
        end
        Comment = [Comment, target{i}];
    end
end
% Sort channels indices, and remove duplicates
iChannels = unique(iChannels);

