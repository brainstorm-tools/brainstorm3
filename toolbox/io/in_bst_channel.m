function sMat = in_bst_channel(MatFile, varargin)
% IN_BST_CHANNEL: Read a "channel" file in Brainstorm format.
% 
% USAGE:  sMat = in_bst_channel(MatFile, FieldsList) : Read the specified fields        
%         sMat = in_bst_channel(MatFile)             : Read all the fields
% 
% INPUT:
%    - MatFile    : Absolute or relative path to the file to read
%    - FieldsList : List of fields to read from the file
% OUTPUT:
%    - sMat : Brainstorm matrix file structure

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
% Authors: Francois Tadel, 2012-2022

%% ===== PARSE INPUTS =====
% Full file name
if ~file_exist(MatFile)
    MatFile = file_fullpath(MatFile);
end
if ~file_exist(MatFile)
    error(['Channel file was not found: ' 10 file_short(MatFile) 10 'Please reload this protocol (right-click > reload).']);
end
% Specific fields
if (nargin < 2)
    % Read all fields
    sMat = load(MatFile);
    % Default structure
    defMat = db_template('channelmat');
    % Add file fields
    sMat = struct_copy_fields(defMat, sMat, 1);
    % Get all the fields
    FieldsToRead = fieldnames(sMat);
else
    % Get fields to read
    FieldsToRead = varargin;
    % Read each field only once
    FieldsToRead = unique(FieldsToRead);
    % Read specified files only
    warning off MATLAB:load:variableNotFound
    sMat = load(MatFile, FieldsToRead{:});
    warning on MATLAB:load:variableNotFound
end


%% ===== HEAD POINTS =====
if ismember('HeadPoints', FieldsToRead) && (~isfield(sMat, 'HeadPoints') || isempty(sMat.HeadPoints))
    sMat.HeadPoints = struct('Loc',   [], ...
                             'Label', [], ...
                             'Type',  []);
end

%% ===== PROJECTORS =====
if ismember('Projector', FieldsToRead)
    % Field exists
    if isfield(sMat, 'Projector') && ~isempty(sMat.Projector)
        % Old format (I-UUt) => Convert to new format
        if ~isstruct(sMat.Projector)
            sMat.Projector = process_ssp2('ConvertOldFormat', sMat.Projector);
        elseif ~isfield(sMat.Projector, 'Method')
            tmpProjector = repmat(db_template('projector'), 1, length(sMat.Projector));
            for ix = 1 : length(sMat.Projector)
                tmpProjector(ix) = process_ssp2('ConvertOldFormat', sMat.Projector(ix));
            end
            sMat.Projector = tmpProjector;
        end
    % Field does not exist
    else
        sMat.Projector = repmat(db_template('projector'), 0);
    end
end

%% ===== FILL OTHER MISSING FIELDS =====
% Default structure
for i = 1:length(FieldsToRead)
    if ~isfield(sMat, FieldsToRead{i})
        sMat.(FieldsToRead{i}) = [];
    end
end

%% ===== ADD GROUP =====
% Define default electrodes group for ECOG/SEEG based on the sensor names (only when groups are not defined yet)
if ismember('Channel', FieldsToRead) && isstruct(sMat.Channel) && ~isempty(sMat.Channel)
    % Fix intra electrode structures
    if isfield(sMat, 'IntraElectrodes') && ~isempty(sMat.IntraElectrodes) && ~isequal(fieldnames(db_template('intraelectrode')), fieldnames(sMat.IntraElectrodes))
        fileValues = sMat.IntraElectrodes;
        sMat.IntraElectrodes = repmat(db_template('intraelectrode'), 1, length(fileValues));
        namesSrc = fieldnames(sMat.IntraElectrodes);
        for iElec = 1:length(sMat.IntraElectrodes)
            for iField = 1:length(namesSrc)
                if isfield(fileValues, namesSrc{iField})
                    sMat.IntraElectrodes(iElec).(namesSrc{iField}) = fileValues(iElec).(namesSrc{iField});
                end
            end
        end
    end
    % If "Group" field is missing, add it
    if ~isfield(sMat.Channel, 'Group')
        sMat.Channel(1).Group = [];
    end
    % For SEEG/ECOG
    for Modality = {'SEEG', 'ECOG'}
        % Get channels for modality
        iMod = good_channel(sMat.Channel, [], Modality{1});
        if isempty(iMod)
            continue;
        end
        % If the groups are all defined: skip
        if all(~cellfun(@isempty, {sMat.Channel(iMod).Group})) && isfield(sMat, 'IntraElectrodes') && ~isempty(sMat.IntraElectrodes) && all(ismember(unique({sMat.Channel(iMod).Group}), {sMat.IntraElectrodes.Name}))
            continue;
        end
        % Parse sensor names
        [AllGroups, AllTags, AllInd, isNoInd] = panel_montage('ParseSensorNames', sMat.Channel(iMod));
        % Get the unique non-empty group names
        uniqueTags = unique(AllTags(~cellfun(@isempty, AllTags)));
        % If the sensors can be grouped using the tags/indices logic
%         if (length(uniqueTags) > 1) && ~any(isNoInd)
        if ~isempty(uniqueTags) && ~any(isNoInd)
            for iGroup = 1:length(uniqueTags)
                iTmp = find(strcmp(AllTags, uniqueTags{iGroup}));
                for i = 1:length(iTmp)
                    if isempty(sMat.Channel(iMod(iTmp(i))).Group)
                        [sMat.Channel(iMod(iTmp(i))).Group] = deal(uniqueTags{iGroup});
                    end
                end
            end
        end
        % Detect electrodes
        if ~isfield(sMat, 'IntraElectrodes') || isempty(sMat.IntraElectrodes) || ~all(ismember(uniqueTags, {sMat.IntraElectrodes.Name}))
            sMat = panel_ieeg('DetectElectrodes', sMat, Modality{1}, AllInd, 0);
        end
    end
end





