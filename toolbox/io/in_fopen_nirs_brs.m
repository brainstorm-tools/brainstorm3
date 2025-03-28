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
%     - CondNames (n_events cell): list of events name
%     - s (nb_samples x n_events): events times. Contains 1 during events
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
% Truncate significant digits to avoid numerical errors in the conversion time<->samples
sFile.prop.sfreq = 1 ./ ( round(mean(diff(nirs.t)) .* 1e6) ./ 1e6); %sec
sFile.prop.times = (round(nirs.t(1) .* sFile.prop.sfreq) + [0, length(nirs.t)-1]) ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;

% Warning: Unstable sampling frequency
if (abs(sFile.prop.times(2) - nirs.t(end)) > 1e-3)
    disp([10, 'BST> WARNING: Unstable sampling frequency in NIRS file.']);
    disp(sprintf('BST>   | MEAN: mean(1./diff(t))=%1.12f Hz   |   STD: std(1./diff(t))=%1.12f Hz', mean(1./diff(nirs.t)), std(1./diff(nirs.t))));
    disp(sprintf('BST>   | Time of last sample reported in the NIRS file: %1.12f s', nirs.t(end)));
    disp(sprintf('BST>   | Time of last sample as imported in Brainstorm: %1.12f s\n', sFile.prop.times(2)));
end

% Reading events 
if isfield(nirs,'s') && size(nirs.s,2) > 0
    n_event = size(nirs.s,2);
    events = repmat(db_template('event'), 1, length(n_event));
    for iEvt = 1:n_event
        % Assume simple event (non-extended)
        eventSample = find(nirs.s(:,iEvt)) - 1;
        evtTime     =  eventSample ./ sFile.prop.sfreq;

        % Events structure
        if isfield(nirs, 'CondNames')
            events(iEvt).label      = nirs.CondNames{iEvt};
        else
            events(iEvt).label      = sprintf('%d',iEvt);
        end
        events(iEvt).times      = evtTime(:)';
        events(iEvt).epochs     = ones(1, length(evtTime));
        events(iEvt).notes      = [];
        events(iEvt).channels   = [];
        events(iEvt).reactTimes = [];
    end
    sFile.events = events;
end


% Detect saturation
if isfield(nirs,'brainsight') && ~isempty(find(nirs.brainsight.acquisition.saturation))
    event = db_template('event');
    
    saturation = nirs.brainsight.acquisition.saturation > 0 & nirs.brainsight.acquisition.digitalSaturation > 0;
    saturated_channels = unique(nirs.brainsight.acquisition.saturation(saturation));
    
    for i_chan = 1:length(saturated_channels)
        
        saturation_chan = nirs.brainsight.acquisition.saturation == saturated_channels(i_chan) & nirs.brainsight.acquisition.digitalSaturation == saturated_channels(i_chan);
        evtTime     =  find(saturation_chan) ./ sFile.prop.sfreq;
        channels_saturated = cell(1, length(evtTime));
        channels_saturated{saturated_channels(i_chan)} = 'saturated channel';

        % Events structure
        event.label      = sprintf('Saturation %d',saturated_channels(i_chan));
        event.times      = evtTime(:)';
        event.epochs     = ones(1, length(evtTime));
        event.notes      = [];
        event.channels   = channels_saturated;
        event.reactTimes = [];
        sFile.events = [sFile.events event];
    end    
end


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
    
    % If src and det are 2D pos, then set z to 1 to avoid issue at (x=0,y=0,z=0)
    if all(src_coords(:,3)==0) && all(det_coords(:,3)==0)
        src_coords(:,3) = 1;
        det_coords(:,3) = 1;
    end
    if ~isfield(nirs.SD,'SpatialUnit')
        scale = 0.01; % assume coordinate are in cm
    else
        scale = bst_units_ui(nirs.SD.SpatialUnit);
    end
    % Apply units
    src_coords = scale .* src_coords;
    det_coords = scale .* det_coords;
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
    ChannelMat.Nirs.Wavelengths = round(ChannelMat.Nirs.Wavelengths);
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
        measure_tag = sprintf('WL%d', ChannelMat.Nirs.Wavelengths(idx_measure));
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
