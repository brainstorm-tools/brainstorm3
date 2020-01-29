function ChannelMat = read_fieldtrip_chaninfo(ChannelMat, ftMat)
% READ_FIELDTRIP_CHANINFO: Read sensor information from .grad and .elec fields (FieldTrip or SPM)

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
% Authors: Francois Tadel, 2017

%% ===== FIND INFO FIELDS =====
% Get EEG info structure (FieldTrip or SPM)
if isfield(ftMat, 'elec') && isfield(ftMat.elec, 'label') && ~isempty(ftMat.elec.label) && isfield(ftMat.elec, 'elecpos') && ~isempty(ftMat.elec.elecpos)
    elec = ftMat.elec;
elseif isfield(ftMat, 'eeg') && isfield(ftMat.eeg, 'label') && ~isempty(ftMat.eeg.label) && isfield(ftMat.eeg, 'elecpos') && ~isempty(ftMat.eeg.elecpos)
    elec = ftMat.eeg;
else
    elec = [];
end
% Get MEG info structure (FieldTrip or SPM)
if isfield(ftMat, 'grad') && isfield(ftMat.grad, 'tra') && isfield(ftMat.grad, 'label') && ~isempty(ftMat.grad.label) && isfield(ftMat.grad, 'coilpos') && ~isempty(ftMat.grad.coilpos)
    grad = ftMat.grad;
elseif isfield(ftMat, 'meg') && isfield(ftMat.meg, 'tra') && isfield(ftMat.meg, 'label') && ~isempty(ftMat.meg.label) && isfield(ftMat.meg, 'coilpos') && ~isempty(ftMat.meg.coilpos)
    grad = ftMat.meg;
else
    grad = [];
end


%% ===== REBUILD COIL-CHANNEL CORRESPONDANCE =====
projList = {};
if ~isempty(grad)
    % Initialize fieldtrip
    bst_ft_init();
    % Fix glitches in the structure
    grad = ft_datatype_sens(grad);
    
    % Get the list of montages to undo
    montageList = {grad.balance.current};
    if isfield(grad.balance, 'previous') && ~isempty(grad.balance.previous)
        montageList = cat(2, montageList, grad.balance.previous{:});
    end
    % Undo montages one by one
    for iMontage = 1:length(montageList)
        % Make sure the montage is defined in the structure
        mont = montageList{iMontage};
        if ~isfield(grad.balance, mont)
            continue;
        end
        % Remove all the fields that may cause incompatibility issues
        % Fix proposed by JMS for importing the HCP pre-processed files
        for f = {'chanunitnew' 'chanunitold' 'chanunitorg' 'chantypenew' 'chantypeold' 'chantypeorg'}
            if isfield(grad.balance.(mont), f{1})
                grad.balance.(mont) = rmfield(grad.balance.(mont), f{1});
            end
        end
        % Reverse transformation
        grad = ft_apply_montage(grad, grad.balance.(mont), 'keepunused', 'yes', 'inverse', 'yes');
        % Add to the list of projectors to process
        projList{end+1} = mont;
    end
    % Remove small values to keep only the ones (diagonals can have different values when mixing GRAD and MAG)
    diagVal = max(abs(grad.tra),[],2);
    grad.tra = bst_bsxfun(@rdivide, grad.tra, diagVal);
    grad.tra(abs(grad.tra) < 0.5) = 0;
    grad.tra = round(grad.tra);
    grad.tra = bst_bsxfun(@times, grad.tra, diagVal);
end

%% ===== BUILD PROJECTOR LIST =====
nChannels = length(ChannelMat.Channel);
for iProj = length(projList):-1:1
    % Initialize projector
    P = zeros(nChannels,nChannels);
    % Get list of channels: OLD
    if isfield(grad.balance.(projList{iProj}), 'labelorg')
        labelOld = grad.balance.(projList{iProj}).labelorg;
    elseif isfield(grad.balance.(projList{iProj}), 'labelold')
        labelOld = grad.balance.(projList{iProj}).labelold;
    end
    iChanOld = [];
    iChanOldBst = [];
    for i = 1:length(labelOld)
        tmp = find(strcmpi(labelOld{i}, {ChannelMat.Channel.Name}));
        if (length(tmp) == 1)
            iChanOldBst(end+1) = tmp;
            iChanOld(end+1) = i;
        end
    end
    % Get list of channels: NEW
    labelNew = grad.balance.(projList{iProj}).labelnew;
    iChanNew = [];
    iChanNewBst = [];
    for i = 1:length(labelNew)
        tmp = find(strcmpi(labelNew{i}, {ChannelMat.Channel.Name}));
        if (length(tmp) == 1)
            iChanNewBst(end+1) = tmp;
            iChanNew(end+1) = i;
        end
    end
    % Get values
    P(iChanNewBst, iChanOldBst) = grad.balance.(projList{iProj}).tra(iChanNew, iChanOld);
    % Build projector list
    if isempty(ChannelMat.Projector)
        ChannelMat.Projector = repmat(db_template('projector'), [1,0]);
        iNewProj = 1;
    else
        iNewProj = length(ChannelMat.Projector)+1;
    end
    ChannelMat.Projector(iNewProj).Components = P;
    ChannelMat.Projector(iNewProj).Comment    = projList{iProj};
    ChannelMat.Projector(iNewProj).Status     = 2;
end

%% ===== GET SENSOR INFO =====
% Process channel by channel
for i = 1:nChannels
    % Channel name
    chName = ChannelMat.Channel(i).Name;
    
    % EEG sensors
    if ~isempty(elec) && ismember(chName, elec.label)
        % Find channel index
        ichan = find(strcmpi(chName, elec.label), 1);
        % 3D position
        if ~any(isnan(elec.elecpos(ichan,:))) && ~any(isinf(elec.elecpos(ichan,:))) && ~all(elec.elecpos(ichan,:) == 0)
            ChannelMat.Channel(i).Loc(:,1) = elec.elecpos(ichan,:);
            % Apply units
            if isequal(elec.unit, 'mm')
                ChannelMat.Channel(i).Loc(:,1) = ChannelMat.Channel(i).Loc(:,1) ./ 1000;
            elseif isequal(elec.unit, 'cm')
                ChannelMat.Channel(i).Loc(:,1) = ChannelMat.Channel(i).Loc(:,1) ./ 100;
            end
        end
        % Get type
        if isempty(ChannelMat.Channel(i).Type)
            if isfield(elec, 'chantype') && ~isempty(elec.chantype)
                ChannelMat.Channel(i).Type = upper(elec.chantype{ichan});
            else
                ChannelMat.Channel(i).Type = 'EEG';
            end
        end
        
    % MEG sensors
    elseif ~isempty(grad) && ismember(chName, grad.label)
        % Find channel index
        ichan = find(strcmpi(chName, grad.label), 1);
        % Find corresponding coils
        icoils = find(grad.tra(ichan,:));
        % Error: Two many coils
        if (length(icoils) > 2)
            % TODO: This is wrong: not importing the correct coil positions, not importing the SSP/ICA projectors...
            disp(['Error: Wrong number of coils for channel ', chName, ': Cannot import this file correctly...']);
            ChannelMat.Channel(i).Loc    = grad.chanpos(ichan,:)';
            ChannelMat.Channel(i).Orient = grad.chanori(ichan,:)';
            ChannelMat.Channel(i).Weight = 1;
        else
            % Locations
            ChannelMat.Channel(i).Loc    = grad.coilpos(icoils,:)';
            ChannelMat.Channel(i).Orient = grad.coilori(icoils,:)';
            ChannelMat.Channel(i).Weight = grad.tra(ichan,icoils);
        end
        
        % Apply units
        if isfield(grad, 'unit') && isequal(grad.unit, 'cm')
            ChannelMat.Channel(i).Loc = ChannelMat.Channel(i).Loc ./ 100;
        elseif isfield(grad, 'unit') && isequal(grad.unit, 'mm')
            ChannelMat.Channel(i).Loc = ChannelMat.Channel(i).Loc ./ 1000;
        end
        
        % Get type
        if isempty(ChannelMat.Channel(i).Type)
            if isfield(grad, 'chantype') && ~isempty(grad.chantype)
                ChannelMat.Channel(i).Type = upper(grad.chantype{ichan});
            else
                ChannelMat.Channel(i).Type = 'MEG';
            end
        end
    end
end
    
%% ===== CONVERT CHANNEL TYPES =====
for i = 1:length(ChannelMat.Channel)
    switch upper(ChannelMat.Channel(i).Type)
        case 'MEGPLANAR',   ChannelMat.Channel(i).Type = 'MEG GRAD';
        case 'MEGMAG',      ChannelMat.Channel(i).Type = 'MEG MAG';
        case 'REFGRAD',     ChannelMat.Channel(i).Type = 'MEG REF';
        case 'REFMAG',      ChannelMat.Channel(i).Type = 'MEG REF';
    end
end

