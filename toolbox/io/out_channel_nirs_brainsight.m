function out_channel_nirs_brainsight(BstFile, OutputFile, MriFile)
% OUT_CHANNEL_NIRS_BRAINSIGHT: Export a Brainstorm channel file in 
% brainsight coordinate files.
%
% USAGE:  out_channel_pos( BstFile,    OutputFile, MriFile );
%         out_channel_pos( ChannelMat, OutputFile, MriFile );
%
% INPUT: 
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.txt' extension)
%    - MriFile    : optional, full path to the MRI data. Used to set origin
%                   of exported coordinates.
%
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
% Authors: Thomas Vincent 2017

% Load brainstorm channel file
if ischar(BstFile)
    ChannelMat = in_bst_channel(BstFile);
else
    ChannelMat = BstFile;
end

if ~isfield(ChannelMat, 'Nirs')
    bst_error('Channel file does not correspond to NIRS data.');
    return;
end

if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Loc)
    % Find fiducials in the head points
    iCardinal = find(strcmpi(ChannelMat.HeadPoints.Type, 'CARDINAL'));
    fidu_coords = ChannelMat.HeadPoints.Loc(:,iCardinal);
else
    fidu_coords = [];
end

[pair_names, pair_loc, pair_ichans, pair_sd_indexes, ...
    src_coords, src_ids, src_ichans, ...
    det_coords, det_ids, det_ichans] = explode_channels(ChannelMat);

% Convert to MRI coordinates if available
if nargin >= 3
    sMri = in_mri_bst(MriFile);
    volDim = size(sMri.Cube(:,:,:,1));
    pixDim = sMri.Voxsize;
    
    % Same code as in out_mri_nii.m to make sure exported coordinates have the
    % same origin as exported MRI
    % Use existing matrices (from the header)
    if isfield(sMri, 'Header') && isfield(sMri.Header, 'nifti') && ...
            all(isfield(sMri.Header.nifti, {'qform_code', 'sform_code', 'quatern_b', 'quatern_c', 'quatern_d', 'qoffset_x', 'qoffset_y', 'qoffset_z', 'srow_x', 'srow_y', 'srow_z'})) && ...
            (any([sMri.Header.nifti.srow_x sMri.Header.nifti.srow_y sMri.Header.nifti.srow_z]~=0) || ...
             any(sMri.Header.nifti.qform(:)~=0))
         if any([sMri.Header.nifti.srow_x sMri.Header.nifti.srow_y sMri.Header.nifti.srow_z]~=0)
             sform = [sMri.Header.nifti.srow_x ;  sMri.Header.nifti.srow_y ; sMri.Header.nifti.srow_z];
         elseif any(sMri.Header.nifti.qform(:) ~= 0)
             if ~all(sMri.Header.nifti.qform(4, :) == [0 0 0 1])
                 bst_error('Scaling in qform is not handled.');
                 return;
             end
             sform = sMri.Header.nifti.qform(1:3, :);
         end 
    else % Otherwise: Try to define from existing information in the database
        if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'Origin') && ~isempty(sMri.NCS.Origin)
            Origin = sMri.NCS.Origin - [1 2 2];
        elseif isfield(sMri, 'NCS') && isfield(sMri.NCS, 'R') && ~isempty(sMri.NCS.R) && isfield(sMri.NCS, 'T') && ~isempty(sMri.NCS.T)
            Origin = cs_convert(sMri, 'mni', 'mri', [0 0 0]) .* 1000;
        elseif isfield(sMri, 'NCS') && isfield(sMri.NCS, 'AC') && ~isempty(sMri.NCS.AC)
            Origin = sMri.NCS.AC + [0, -3, 4];
        else
            Origin = volDim / 2;
        end
        sform = [diag(pixDim) (-Origin.*pixDim)'];
    end
    
    src_coords = (sform * [cs_convert(sMri, 'scs', 'mri', src_coords)*1000 ones(size(src_coords,1), 1)]')';
    det_coords = (sform * [cs_convert(sMri, 'scs', 'mri', det_coords)*1000 ones(size(det_coords,1), 1)]')';
    if ~isempty(fidu_coords)
        fidu_coords = (sform * [cs_convert(sMri, 'scs', 'mri', fidu_coords)*1000 ones(size(fidu_coords,1), 1)]')';
    end
end



% Format header
header = sprintf(['# Version: 5\n# Coordinate system: NIftI-Aligned\n# Created by: Brainstorm (nirstorm plugin)\n' ...
         '# units: millimetres, degrees, milliseconds, and microvolts\n# Encoding: UTF-8\n' ...
         '# Notes: Each column is delimited by a tab. Each value within a column is delimited by a semicolon.\n' ...
         '# Sample Name	Index	Loc. X	Loc. Y	Loc. Z	Offset\n']);

% Format list of coordinates
ioptode = 1;
coords = {};
for isrc=1:size(src_coords)
    coords{ioptode} = sprintf('S%d\t%d\t%f\t%f\t%f\t0.0\n',isrc, ioptode, src_coords(isrc, 1), ...
                              src_coords(isrc, 2), src_coords(isrc, 3));
    ioptode = ioptode + 1;                         
end

for idet=1:size(det_coords)
    coords{ioptode} = sprintf('D%d\t%d\t%f\t%f\t%f\t0.0\n',idet, ioptode, det_coords(idet, 1), ...
                              det_coords(idet, 2), det_coords(idet, 3));
    ioptode = ioptode + 1;
end

if ~isempty(fidu_coords) && ~isempty(iCardinal)
    for i = 1:length(iCardinal)
        coords{ioptode} = sprintf('%s\t%d\t%f\t%f\t%f\t0.0\n', ChannelMat.HeadPoints.Label{iCardinal(i)}, ...
                                   ioptode, fidu_coords(i, 1), fidu_coords(i, 2), fidu_coords(i, 3));
        ioptode = ioptode + 1;
    end
end
% Open .txt file
fout = fopen(OutputFile, 'w');
if (fout < 0)
   error(['Cannot open file' OutputFile]); 
end
export_content = [header strjoin(coords, '')];
fprintf(fout, export_content);
fclose(fout);
end

function [pair_names, pair_loc, pair_ichans, pair_sd_indexes, ...
    src_coords, src_ids, src_ichans, ...
    det_coords, det_ids, det_ichans] = explode_channels(channel_def)
%% Explode channel data according to pairs, sources and detectors
% Args
%    - channel_def: struct
%        Definition of channels as given by brainstorm
%        Used fields: Channel
%
% TOCHECK WARNING: uses containers.Map which is available with matlab > v2008
%
%  Outputs:
%     - pair_names: cell array of str, size: nb_pairs
%         Pair names, format: SXDX
%     - pair_loc: array of double, size: nb_pairs x 3 x 2
%         Pair localization (coordinates of source and detector)
%     - pair_ichans: matrix of double, size: nb_pairs x nb_wavelengths
%         Input channel indexes grouped by pairs
%     - pair_sd_indexes: matrix of double, size: nb_pairs x 2
%         1-based continuours indexes of sources and detectors for each
%         sources.
%     - src_coords:   nb_sources x 3
%         Source coordinates, indexed by 1-based continuous index
%         To access via source ID, as read from pair name:
%             src_coords(src_id2idx(src_ID),:)
%     - src_ids: 1d array of double, size: nb_sources
%         vector of source ids (as used in pair name)
%     - src_chans: cellarray of 1d array of double, size: nb_sources
%         Channel indexes to which the source belongs (indexed by 1-based
%         continuous index).
%     - det_coords:   nb_detectors x 3
%         Detector coordinates, indexed by 1-based continuous index
%         To access via detector ID, as used in pair name:
%             det_coords(det_id2idx(det_ID),:)
%     - det_ids: 1d array of double, size: max_detector_id (hashing vector)
%         vector of detector ids (as used in pair name)
%     - det_chans: cellarray of 1d array of double, size: nb_sources
%         Channel indexes to which the detector belongs (indexed by 1-based
%         continuous index).

MT_OD = 1;
MT_HB = 2;

if isfield(channel_def.Nirs, 'Wavelengths')
    nb_measures = length(channel_def.Nirs.Wavelengths);
    measure_type = MT_OD;
else
    nb_measures = length(channel_def.Nirs.Hb);
    measure_type = MT_HB;
end

pair_to_chans = containers.Map();
pair_to_sd = containers.Map();
src_to_chans = containers.Map('KeyType', 'double', 'ValueType', 'any');
src_coords_map = containers.Map('KeyType', 'double', 'ValueType', 'any');
det_to_chans = containers.Map('KeyType', 'double', 'ValueType', 'any');
det_coords_map = containers.Map('KeyType', 'double', 'ValueType', 'any');
for ichan=1:length(channel_def.Channel)
    if strcmp(channel_def.Channel(ichan).Type, 'NIRS')
        chan_name = channel_def.Channel(ichan).Name;
        if measure_type == MT_OD
            iwl = strfind(chan_name, 'WL');
            pair_name = chan_name(1:iwl-1);
            wl = str2double(chan_name(iwl+2:end));
            imeasure = channel_def.Nirs.Wavelengths==wl;
        else
            ihb = strfind(chan_name, 'Hb');
            pair_name = chan_name(1:ihb-1);
            imeasure = strcmp(chan_name(ihb:end), channel_def.Nirs.Hb);
        end
        
        if pair_to_chans.isKey(pair_name)
            measures = pair_to_chans(pair_name);
        else
            measures = zeros(1, nb_measures);
        end
        measures(imeasure) = ichan;
        pair_to_chans(pair_name) = measures;
        
        
        [src_id, det_id] = split_pair_name(pair_name);
        pair_to_sd(pair_name) = [src_id, det_id];
        if src_to_chans.isKey(src_id)
            src_to_chans(src_id) = [src_to_chans(src_id) ichan];
        else
            src_to_chans(src_id) = ichan;
            src_coords_map(src_id) = channel_def.Channel(ichan).Loc(:, 1);
        end
        if det_to_chans.isKey(det_id)
            det_to_chans(det_id) = [det_to_chans(det_id) ichan];
        else
            det_to_chans(det_id) = ichan;
            det_coords_map(det_id) = channel_def.Channel(ichan).Loc(:, 2);
        end
        
    end
end

src_coords = cell2mat(src_coords_map.values)';
src_ichans = src_to_chans.values;
src_ids = cell2mat(src_coords_map.keys);

det_coords = cell2mat(det_coords_map.values)';
det_ichans = det_to_chans.values;
det_ids = cell2mat(det_coords_map.keys);

nb_pairs = pair_to_chans.size(1);
pair_names = pair_to_chans.keys;
pair_ichans = zeros(nb_pairs, nb_measures);
pair_loc = zeros(nb_pairs, 3, 2);
pair_sd_indexes = zeros(nb_pairs, 2);
for ipair=1:nb_pairs
    p_indexes = pair_to_chans(pair_names{ipair});
    pair_ichans(ipair, :) = p_indexes;
    pair_loc(ipair, : , :) = channel_def.Channel(pair_ichans(ipair, 1)).Loc;
    sdi = pair_to_sd(pair_names{ipair});
    pair_sd_indexes(ipair, 1) = find(src_ids==sdi(1));
    pair_sd_indexes(ipair, 2) = find(det_ids==sdi(2));
end

end

function [isrc, idet] = split_pair_name(pair_name)
pair_re = 'S([0-9]{1,2})D([0-9]{1,2})';
toks = regexp(pair_name, pair_re , 'tokens');
isrc = str2double(toks{1}{1});
idet = str2double(toks{1}{2});
end





