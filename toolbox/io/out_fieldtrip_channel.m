function [elec, grad] = out_fieldtrip_channel(ChannelFile, isIncludeRef)
% OUT_FIELDTRIP_CHANNEL: Converts a channel file into elec/grad structures
% 
% USAGE:  [elec, grad] = out_fieldtrip_channel(ChannelFile, isIncludeRef=1)
%         [elec, grad] = out_fieldtrip_channel(ChannelMat)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2016


% ===== PARSE INPUT =====
if (nargin < 2) || isempty(isIncludeRef)
    isIncludeRef = 1;
end
if isstruct(ChannelFile)
    ChannelMat  = ChannelFile;
    ChannelFile = [];
else
    ChannelMat = [];
end

% ===== LOAD CHANNEL FILE =====
% Load channel file
if ~isempty(ChannelFile) && isempty(ChannelMat)
    ChannelMat = in_bst_channel(ChannelFile);
end
% Make sure that the channel file is defined
if isempty(ChannelMat)
    error('No channel file available.');
end
% Find MEG and EEG sensors
iEeg = channel_find(ChannelMat.Channel, 'EEG,SEEG,ECOG');
iMeg = channel_find(ChannelMat.Channel, 'MEG');
iRef = channel_find(ChannelMat.Channel, 'MEG REF');
if isIncludeRef
    iMegAll = [iMeg, iRef];
else
    iMegAll = iMeg;
end

% ===== COMPUTE PROJECTOR =====
% Compute selected SSP projectors
if ~isempty(ChannelMat.Projector)
    % Rebuild projector in the expanded form (I-UUt)
    Proj = process_ssp2('BuildProjector', ChannelMat.Projector, [1 2]);
else
    Proj = [];
end
    
% ===== EEG =====
if ~isempty(iEeg)
    % Create electrode structure
    elec = struct();
    elec.label = {ChannelMat.Channel(iEeg).Name};
    elec.unit  = 'm';
    % Electrode position
    elec.chanpos = zeros(length(iEeg),3);
    for i = 1:length(iEeg)
        elec.chanpos(i,:) = ChannelMat.Channel(iEeg(i)).Loc(:,1);
    end
    elec.elecpos = elec.chanpos;
    % Default montage
    elec.tra = eye(length(iEeg));
    % Apply projectors (SSP or ICA)
    if ~isempty(Proj)
        elec.tra = Proj(iEeg,iEeg) * elec.tra;
    end
else
    elec = [];
end

% ===== MEG =====
if ~isempty(iMeg)
    % Average all the intergration points of the various coils
    chantype = cell(1,length(iMegAll));
    for i = 1:length(iMegAll)
        switch (ChannelMat.Channel(iMegAll(i)).Type)
            case 'MEG'
                chantype{i} = 'megaxial';
            case 'MEG MAG'
                chantype{i} = 'megmag';
            case 'MEG GRAD'
                chantype{i} = 'megplanar';
            case 'MEG REF'
                chantype{i} = 'megref';
        end
    end
    
    % Create sensor structure
    grad = struct();
    grad.label    = {ChannelMat.Channel(iMegAll).Name};
    grad.unit     = 'm';
    grad.chantype = chantype;
    % Channels positions
    grad.chanpos = figure_3d('GetChannelPositions', ChannelMat, iMegAll);
    % Coils positions
    grad.coilpos = [ChannelMat.Channel(iMegAll).Loc]';
    grad.coilori = [ChannelMat.Channel(iMegAll).Orient]';
    % Correspondance channel-coil
    grad.tra = sparse(length(iMegAll), length(grad.coilpos));
    k = 1;
    for i = 1:length(iMegAll)
        % Dealing with the multiple coils and integration points
        grad.chanori(i,:) = ChannelMat.Channel(iMegAll(i)).Orient(:,1)';
        nCoils = size(ChannelMat.Channel(iMegAll(i)).Weight,2);
        grad.tra(i,k+(0:nCoils-1)) = ChannelMat.Channel(iMegAll(i)).Weight;
        k = k + nCoils;
    end
    % Add MegRefCoef (CTF/4D 3rd order gradient compensation)
    if isIncludeRef && ~isempty(iRef)
        % Error: Not all the sensors are selected
        if (size(ChannelMat.MegRefCoef,1) ~= length(iMeg)) || (size(ChannelMat.MegRefCoef,2) ~= length(iRef))
            error('CTF compensation can be used only when using all the MEG sensors.');
        end
        % Apply compensation matrix to ".tra" matrix
        GradComp = eye(length(ChannelMat.Channel)); 
        GradComp(iMeg,iRef) = -ChannelMat.MegRefCoef;
        grad.tra = GradComp(iMegAll,iMegAll) * grad.tra;
        % grad.tra is later applied to the leadfield in ft_compute_leadfield:
        % lf = sens.tra * lf;
    end
    % Apply projectors (SSP or ICA)
    if ~isempty(Proj)
        grad.tra = Proj(iMegAll,iMegAll) * grad.tra;
    end
else
    grad = [];
end




