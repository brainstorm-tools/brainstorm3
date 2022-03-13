function converted_raw_File = in_spikesorting_convertforkilosort( varargin )
% IN_SPIKESORTING_RAWELECTRODES: Loads and creates if needed separate raw
% electrode files for spike sorting purposes.
%
% USAGE: OutputFiles = in_spikesorting_convertforkilosort(sInputs, ram)

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
% Authors: Konstantinos Nasiotis, 2018-2019, 2022; Martin Cousineau, 2018

sInput = varargin{1};
if nargin < 2 || isempty(varargin{2})
    ram = 1e9; % 1 GB
else
    ram = varargin{2};
end

protocol = bst_get('ProtocolInfo');
parentPath = bst_fullfile(bst_get('BrainstormTmpDir'), ...
                       'Unsupervised_Spike_Sorting', ...
                       protocol.Comment, ...
                       sInput.FileName);

% Make sure the temporary directory exist, otherwise create it
if ~exist(parentPath, 'dir')
    mkdir(parentPath);
end

DataMat = in_bst_data(sInput.FileName, 'F');
ChannelMat = in_bst_channel(sInput.ChannelFile);
sFile = DataMat.F;
fileSamples = round(sFile.prop.times .* sFile.prop.sfreq);

% Separate the file to max length based on RAM
numChannels = length(ChannelMat.Channel);
max_samples = ram / 8 / numChannels;  % Double precision

total_samples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq);
num_segments = ceil(total_samples / max_samples);
num_samples_per_segment = ceil(total_samples / num_segments);

converted_raw_File = bst_fullfile(parentPath, ['raw_data_no_header_' sInput.Condition(5:end) '.dat']);

isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Spike-sorting', 'Converting to KiloSort Input...', 0, ceil((fileSamples(2)-fileSamples(1))/max_samples));
end

if exist(converted_raw_File, 'file') == 2
    disp('File already converted to kilosort input')
    return
end

ImportOptions = db_template('ImportOptions');

%% Check if a projector has been computed and ask if the selected components
% should be removed
if ~isempty(ChannelMat.Projector)
    isOk = java_dialog('confirm', ...
        ['(ICA/PCA) Artifact components have been computed for removal.' 10 10 ...
             'Remove the selected components?'], 'Artifact Removal');
    if isOk
        ImportOptions.UseCtfComp     = 0;
        ImportOptions.UseSsp         = 1;
    end
end 

%% Convert the acquisition system file to an int16 without a header.
fid = fopen(converted_raw_File, 'a');

num_segments = ceil(total_samples / max_samples);
num_samples_per_segment = ceil(total_samples / num_segments);

isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('show');
end
bst_progress('start', 'Kilosort spike sorting', 'Converting to int16 .dat file', 0, num_segments);


sampleBounds_all = cell(num_segments,1);
sampleBounds = [0,0];
for iSegment = 1:num_segments
    sampleBounds(1) = (iSegment - 1) * num_samples_per_segment + round(sFile.prop.times(1)* sFile.prop.sfreq);
    if iSegment < num_segments
        sampleBounds(2) = sampleBounds(1) + num_samples_per_segment - 1;
    else
        sampleBounds(2) = total_samples + round(sFile.prop.times(1)* sFile.prop.sfreq);
    end
        
    F = in_fread(sFile, ChannelMat, [], sampleBounds, [], ImportOptions);
    
    % Adaptive conversion to int16 to avoid saturation
    max_abs_value = max([abs(max(max(F))) abs(min(min(F)))]);
    
    F = int16(F./max_abs_value * 15000); % The choice of 15000 for maximum is in part abstract - for 32567 the clusters look weird
            
    fwrite(fid, F, 'int16');
    
    bst_progress('inc', 1);
    sampleBounds_all{iSegment} = sampleBounds;  % This is here for an easy check that there is no overlap between segments

    clear F
end
fclose(fid);

isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('stop');
end


