function [sFile, ChannelMat] = in_fopen_nirs_brs(DataFile)
% IN_FOPEN_NIRS_BRS: Open a nirs file (continuous recordings).
% USAGE:  [sFile, ChannelMat] = in_fopen_nirs_brs(DataFile)
% 
% Description
%   Create Brainstorm data structures from a .nirs (HOMer format) data 
%   file as produced by the Brainsight acquisition software. Also 
%   tries to load coordinate files "fudicials.txt" and "optodes.txt" in
%   the same directory as the NIRS data file.
%
%   The .nirs file is a matlab file with the following expected variables:
%     - SD (structure):
%         - Lambda (1 x nb_wavelengths):
%             The wavelengths used to measure NIRS. The index asscociated
%             to each wavelength value is used in variable 'ml'
%         - SrcPos (nb_sources x 3 double):
%             3D coordinates of sources, in the acquisition referential.
%             If the file "optodes.txt" is found in the same directory,
%             this field will be ignored.
%         - DetPos (nb_detectors x 3 double): 
%             3D coordinates of detectors, in the acquisition referential.
%             If the file "optodes.txt" is found in the same directory,
%             this field will be ignored.
%     - ml (nb_channels x 4):
%         Measurement list describing each channel.
%         Columns are:
%           - col 1: source index in SD.SrcPos
%           - col 2: detector index in SD.DetPos
%           - col 3: one values (unused)
%           - col 4: wavelength in index in SD.Lambda
%     - t (nb_samples x 1 double):
%         Time vector, sampled at the acquisition sampling rate
%     - d (nb_samples x nb_channels double):
%         measured NIRS data. The index of a given column channel must
%         match the index of the corresponding line in 'ml'
%     - aux (nb_samples x nb_auxiliary_signals):
%       Will be stored as channels AUX1, ... AUX<nb_auxiliary_signals>
%                
%   The "optodes.txt" and "fudicials.txt" are coordinates files with the 
%   following format:
%     - line starting with character '#' are comments
%     - Coordinates are stored as a table: one line by digitized point.
%       Values are seperated by tabulations and columns are:
%         - col 1: Sample Name (eg: S1, D1, Nasion, LeftEar, RightEar)
%         - col 2: Session Name
%         - col 3: Index (specific to Brainsight)
%         - col 4: Loc. X
%         - col 5: Loc. Y
%         - col 6: Loc. Z
%         - col 7: Offset (unused?)
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
% Authors: Thomas Vincent (2015-2017), Alexis Machado (2012)

nirs = load(DataFile, '-mat');

if ~isfield(nirs, 'ml')
    if isfield(nirs.SD, 'MeasList')
        nirs.ml = nirs.SD.MeasList;
    else
        bst_error('Cannot read .nirs file: missing measurement list field');
    end
end

nb_channels = size(nirs.d,2);
nb_det = size(nirs.SD.DetPos, 1);
nb_src = size(nirs.SD.SrcPos, 1);

%% ===== FILL STRUCTURE =====
% Initialize returned file structure                    
sFile = db_template('sfile');                     
                      
% Add information read from header
sFile.filename   = DataFile;
sFile.fid        = [];  
sFile.format     = 'NIRS-BRS';
sFile.device     = 'NIRS Brainsight system';
sFile.byteorder  = 'l';

% Properties of the recordings
% Round to microsec to avoid floating imprecision
sFile.prop.sfreq = 1 ./ ( round((nirs.t(2) - nirs.t(1)) .* 1e6) ./ 1e6 ); %sec
sFile.prop.times = round([nirs.t(1), nirs.t(end)] .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;

ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NIRS-BRS channels';

% Get fiducials
fiducial_file = fullfile(fileparts(DataFile), 'fiducials.txt');
if exist(fiducial_file, 'file') == 2
    fiducial_coords = load_brainsight_coords(fiducial_file);
    ChannelMat.HeadPoints.Loc = [];
     
    for ifid = 1:length(fiducial_coords)
        fidu_name = fiducial_coords(ifid).name;
        fidu_coords = fiducial_coords(ifid).coords';
        if strcmp(fidu_name, 'Nasion')
            ChannelMat.SCS.NAS = fidu_coords;
            ChannelMat.HeadPoints.Loc(:, end+1) = fidu_coords;
            ChannelMat.HeadPoints.Label{end+1} = fidu_name;
            ChannelMat.HeadPoints.Type{end+1}  = 'CARDINAL';
        elseif strcmp(fidu_name, 'LeftEar')
            ChannelMat.SCS.LPA = fidu_coords;
            ChannelMat.HeadPoints.Loc(:, end+1) = fidu_coords;
            ChannelMat.HeadPoints.Label{end+1} = fidu_name;
            ChannelMat.HeadPoints.Type{end+1}  = 'CARDINAL';
        elseif strcmp(fidu_name, 'RightEar')
            ChannelMat.SCS.RPA = fidu_coords;
            ChannelMat.HeadPoints.Loc(:, end+1) = fidu_coords;
            ChannelMat.HeadPoints.Label{end+1} = fidu_name;
            ChannelMat.HeadPoints.Type{end+1}  = 'CARDINAL';
        %store additional fiducials as Head Points
        else %TOCHECK is Tip OK to be included in head points?
            ChannelMat.HeadPoints.Loc(:, end+1) = fidu_coords;
            ChannelMat.HeadPoints.Label{end+1} = fidu_name;
            ChannelMat.HeadPoints.Type{end+1}  = 'EXTRA';
        end
    end
end

% Read optode coords from file if available
optodes_file = fullfile(fileparts(DataFile), 'optodes.txt');
if exist(optodes_file, 'file') == 2
    src_coords = zeros(nb_src, 3);
    det_coords = zeros(nb_det, 3);
    optodes_coords = load_brainsight_coords(optodes_file);   
    for iop = 1:length(optodes_coords)
        coords = optodes_coords(iop).coords';
        opt_toks = textscan(optodes_coords(iop).name, '%c%d');
        % Could add source and detector positions as extra head points
        % TODO: maybe in some cases, it's not preferable because it's only
        %       valid if the optodes are actually *ON* the scalp which may
        %       not be accurate when using a cap.
        % So it should not be done silently here during importation, 
        % but rather let the user do it afterwards if needed for mri 
        % registration. 
        if strcmp(opt_toks{1}, 'S')
            src_coords(opt_toks{2}, :) = coords;
%             ChannelMat.HeadPoints.Loc(:, end+1) = coords;
%             ChannelMat.HeadPoints.Label{end+1} = opt_toks{1};
%             ChannelMat.HeadPoints.Type{end+1}  = 'EXTRA';
        elseif strcmp(opt_toks{1}, 'D')
            det_coords(opt_toks{2}, :) = coords;
%             ChannelMat.HeadPoints.Loc(:, end+1) = coords;   
%             ChannelMat.HeadPoints.Label{end+1} = opt_toks{1};
%             ChannelMat.HeadPoints.Type{end+1}  = 'EXTRA';
        else
            % TODO: raise invalid format exception
            display(['error unformating ' optodes_coords(iop).name]);
        end
    end
else % take optode coordinates from nirs data structure
    src_coords = nirs.SD.SrcPos;
    det_coords = nirs.SD.DetPos;
end


if iscell(nirs.SD.Lambda) % Hb measures
    measure_type = 'Hb';
    ChannelMat.Nirs.Hb = nirs.SD.Lambda;
else
    
    measure_type = 'WL';
    if( size(nirs.SD.Lambda,1) > 1) % Wavelengths have to be stored as a line vector
        ChannelMat.Nirs.Wavelengths = nirs.SD.Lambda';
    else
        ChannelMat.Nirs.Wavelengths = nirs.SD.Lambda;
    end
end

%% Channel information
if ~isfield(nirs, 'aux')
    nirs.aux = [];
end
sFile.channelflag = ones(nb_channels + size(nirs.aux,2), 1); % GOOD=1; BAD=-1;

% NIRS data time-series
for iChan = 1:nb_channels
    idx_src = nirs.ml(iChan, 1);
    idx_det = nirs.ml(iChan, 2);
    idx_measure = nirs.ml(iChan, 4);
    
    if strcmp(measure_type, 'Hb')
        measure_tag =  ChannelMat.Nirs.Hb{idx_measure};
    else
        measure_tag = sprintf('WL%d', round(ChannelMat.Nirs.Wavelengths(idx_measure)));
    end
    Channel(iChan).Name    = sprintf('S%dD%d%s', idx_src, idx_det, ...
                                     measure_tag);
    Channel(iChan).Type    = 'NIRS';
    
    Channel(iChan).Loc(:,1)  = src_coords(idx_src, :);
    Channel(iChan).Loc(:,2)  = det_coords(idx_det, :);
    Channel(iChan).Orient  = [];
    Channel(iChan).Weight  = 1;
    Channel(iChan).Comment = [];
    Channel(iChan).Group = measure_tag;
end

% Check uniqueness
chan_names = {Channel.Name};
[~, i_unique] = unique(chan_names);
duplicates = chan_names;
duplicates(i_unique) = [];
duplicates(strcmp(duplicates, '')) = []; %remove unrecognized channels
i_duplicates = ismember(chan_names, unique(duplicates));
if ~isempty(duplicates)
    msg = sprintf('Non-unique channels: "%s".', strjoin(sort(chan_names(i_duplicates)), ', '));
    throw(MException('NIRSTORM:NonUniqueChannels', msg));
end

% AUX signals
iChan = nb_channels+1;
for iaux=1:size(nirs.aux,2)
    Channel(iChan).Name = ['AUX' num2str(iaux)];
    Channel(iChan).Type = 'NIRS_AUX';
    Channel(iChan).Orient  = [];
    Channel(iChan).Weight  = 1;
    Channel(iChan).Comment = [];
    iChan = iChan + 1;
end

ChannelMat.Channel = Channel;
end

function [coords] = load_brainsight_coords(coords_file)
%   Detailed explanation goes here
    fid = fopen(coords_file);
    coords = struct('name', 'coords');
    ic = 1; % counter of entries
    while(~feof(fid))
       line = textscan(fid, '%s', 1, 'delimiter', '\n');
       if ~isempty(line{1}{1}) && ~strcmp(line{1}{1}(1), '#') % ignore empty lines and comments
           toks = textscan(line{1}{1}, '%s\t%s\t%d\t%f\t%f\t%f%f', ...
                           'WhiteSpace', '\b\t');
           coords(ic).name = toks{1}{1};
           coords(ic).coords = [toks{4} toks{5} toks{6}] ./ 1000; %Convert to meters
           ic = ic + 1;
       end
    end
    fclose(fid);

end










