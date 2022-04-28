function [ftHeadmodel, ftLeadfield, iChannels] = out_fieldtrip_headmodel(HeadModelFile, ChannelFile, iChannels, isIncludeRef)
% OUT_FIELDTRIP_HEADMODEL: Converts a head model file into a FieldTrip structure (see ft_datatype_headmodel).
% 
% USAGE:  [ftHeadmodel, ftLeadfield, iChannels] = out_fieldtrip_headmodel(HeadModelFile, ChannelFile, isIncludeRef=1);
%         [ftHeadmodel, ftLeadfield, iChannels] = out_fieldtrip_headmodel(HeadModelMat,  ChannelMat,  isIncludeRef=1);
%
% INPUTS:
%    - HeadModelFile  : Relative path to a head model file available in the database
%    - HeadModelMat   : Brainstorm head model file structure
%    - ChannelFile    : Relative path to a channel file available in the database
%    - ChannelMat     : Brainstorm channel file structure
% OUTPUTS:
%    - ftHeadmodel    : Volume conductor model, typically returned by ft_prepare_headmodel
%    - ftLeadfield    : Leadfield matrix, typically returned by ft_prepare_leadfield
%    - iChannels      : Modified list of channels (after adding channels)

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
% Authors: Jeremy T. Moreau, Elizabeth Bock, Francois Tadel, 2015

% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(isIncludeRef)
    isIncludeRef = 1;
end
ftHeadmodel = [];
ftLeadfield = [];

% ===== LOAD INPUTS =====
% Load head model file
if ischar(HeadModelFile)
    HeadModelMat = in_bst_headmodel(HeadModelFile);
elseif isstruct(HeadModelFile)
    HeadModelMat = HeadModelFile;
else
    error('Failed to load head model.');
end
% If this file was computed with FieldTrip, it should include the original FieldTrip headmodel
if isfield(HeadModelMat, 'ftHeadmodelMeg') && ~isempty(HeadModelMat.ftHeadmodelMeg)
    ftHeadmodel = HeadModelMat.ftHeadmodelMeg;
elseif isfield(HeadModelMat, 'ftHeadmodelEeg') && ~isempty(HeadModelMat.ftHeadmodelEeg)
    ftHeadmodel = HeadModelMat.ftHeadmodelEeg;
end
% Load channel file
if ischar(ChannelFile)
    ChannelMat = in_bst_channel(ChannelFile);
elseif isstruct(ChannelFile)
    ChannelMat = ChannelFile;
else
    error('Failed to load channel file.')
end
% Get sensor type
Modality = ChannelMat.Channel(iChannels(1)).Type;
% Get headmodel type
switch (Modality)
    case 'EEG',   HeadModelMethod = HeadModelMat.EEGMethod;
    case 'ECOG',  HeadModelMethod = HeadModelMat.ECOGMethod;
    case 'SEEG',  HeadModelMethod = HeadModelMat.SEEGMethod;
    case {'MEG','MEG MAG','MEG GRAD','MEG REF'}, HeadModelMethod = HeadModelMat.MEGMethod;
end

% ===== ADD MEG REF =====
if isIncludeRef && ismember(Modality, {'MEG','MEG MAG','MEG GRAD'})
    iRef = channel_find(ChannelMat.Channel, 'MEG REF');
    if ~isempty(iRef)
        iChannels = [iRef, iChannels];
    end
end


% ===== CREATE FIELDTRIP HEADMODEL =====
if isempty(ftHeadmodel)
    % Get subject
    sSubject = bst_get('SurfaceFile', HeadModelMat.SurfaceFile);
    % Headmodel type
    switch (HeadModelMethod)
        case {'meg_sphere', 'singlesphere'}
            ftHeadmodel.type = 'singlesphere';
            ftHeadmodel.r = HeadModelMat.Param(iChannels(1)).Radii(1);
            ftHeadmodel.o = HeadModelMat.Param(iChannels(1)).Center(:)';
            
        case {'eeg_3sphereberg', 'concentricspheres'}
            ftHeadmodel.type = 'concentricspheres';
            ftHeadmodel.r = HeadModelMat.Param(iChannels(1)).Radii(:)';
            ftHeadmodel.o = HeadModelMat.Param(iChannels(1)).Center(:)';
            % Get default conductivities
            BFSProperties = bst_get('BFSProperties');
            ftHeadmodel.c = BFSProperties(1:3);
            
        case {'os_meg', 'localspheres'}
            ftHeadmodel.type = 'localspheres';
            ftHeadmodel.r = [HeadModelMat.Param(iChannels).Radii]';
            ftHeadmodel.o = [HeadModelMat.Param(iChannels).Center]';
            
        case {'singleshell'}
            ftHeadmodel.type = HeadModelMethod;
            % Check if the surfaces are available
            if isempty(sSubject.iInnerSkull)
                error('No inner skull surface available for this subject.');
            else
                disp(['BST> ' HeadModelMethod ': Using the default inner skull surface available in the database.']);
            end
            % Load surfaces
            SurfaceFiles = {sSubject.Surface(sSubject.iInnerSkull).FileName};
            ftHeadmodel.bnd = out_fieldtrip_tess(SurfaceFiles);
            
        case {'openmeeg', 'dipoli', 'bemcp'}
            ftHeadmodel.type = HeadModelMethod;
            % Check if the surfaces are available
            if isempty(sSubject.iInnerSkull) || isempty(sSubject.iOuterSkull) || isempty(sSubject.iScalp)
                error('No BEM surfaces available for this subject.');
            else
                disp(['BST> ' HeadModelMethod ': Using the default surfaces available in the database (inner skull, outer skull, scalp).']);
            end
            % Load surfaces
            SurfaceFiles = {sSubject.Surface(sSubject.iScalp).FileName, ...
                            sSubject.Surface(sSubject.iOuterSkull).FileName, ...
                            sSubject.Surface(sSubject.iInnerSkull).FileName};
            ftHeadmodel.bnd = out_fieldtrip_tess(SurfaceFiles);
            % Default OpenMEEG options
            ftHeadmodel.cond         = [0.33, 0.004125, 0.33];
            ftHeadmodel.skin_surface = 1;
            ftHeadmodel.source       = 3;
            % ERROR: MISSING .mat field??
            
        otherwise
            error('out_fieldtrip_headmodel does not support converting this type of head model.');
    end
    % Unit and labels
    ftHeadmodel.unit  = 'm';
    ftHeadmodel.label = {ChannelMat.Channel(iChannels).Name}';
end


% ===== CREATE FIELDTRIP LEADFIELD =====
if (nargout >= 2)
    % Create FieldTrip structure
    nSources = length(HeadModelMat.GridLoc);
    ftLeadfield.pos             = HeadModelMat.GridLoc;
    ftLeadfield.unit            = 'm';
    ftLeadfield.inside          = true(nSources, 1);
    ftLeadfield.leadfielddimord = '{pos}_chan_ori';
    ftLeadfield.label           = {ChannelMat.Channel(iChannels).Name};
    ftLeadfield.leadfield       = cell(1, nSources);
    for i = 1:nSources
        ftLeadfield.leadfield{i} = HeadModelMat.Gain(iChannels, 3*(i-1)+[1 2 3]);
    end
end



