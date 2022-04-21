function sFiles = in_spikesorting_rawelectrodes( varargin )
% IN_SPIKESORTING_RAWELECTRODES: Loads and creates if needed separate raw
% electrode files for spike sorting purposes.
%
% USAGE: OutputFiles = in_spikesorting_rawelectrodes(sInput, ram, parallel)

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
% Authors: Konstantinos Nasiotis, 2018, 2022; Martin Cousineau, 2018

sInput = varargin{1};
if nargin < 2 || isempty(varargin{2})
    ram = 1e9; % 1 GB
else
    ram = varargin{2};
end
if nargin < 3 || isempty(varargin{3})
    parallel = 0;
else
    parallel = varargin{3};
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


% Check whether the electrode files already exist
ChannelMat = in_bst_channel(sInput.ChannelFile);
numChannels = length(ChannelMat.Channel);

% New channelNames - Without any special characters.
cleanNames = str_remove_spec_chars({ChannelMat.Channel.Name});

missingFile = 0;
sFiles = {};
for iChannel = 1:numChannels
    chanFile = bst_fullfile(parentPath, ['raw_elec_' cleanNames{iChannel} '.mat']);
    if ~exist(chanFile, 'file')
        missingFile = 1;
    else
        sFiles{end+1} = chanFile;
    end
end
if ~missingFile
    return;
else
    % Clear any remaining intermediate file
    for iFile = 1:length(sFiles)
        delete(sFiles{iFile});
    end
end


% Otherwise, generate all of them again.
DataMat = in_bst_data(sInput.FileName, 'F');
sFile = DataMat.F;
sr = sFile.prop.sfreq;


% Special case for supported acquisition systems: Save temporary files
% using single precision instead of double to save disk space
ImportOptions = db_template('ImportOptions');
if ismember(sFile.format, {'EEG-AXION', 'EEG-BLACKROCK', 'EEG-INTAN', 'EEG-PLEXON'})
    precision = 'single';
    nBytes = 4;
else
    precision = 'double';
    nBytes = 8;
end
ImportOptions.Precision = precision;

max_samples = ram / nBytes / numChannels;
total_samples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq); % (Blackrock/Ripple complained). Removed +1
num_segments = ceil(total_samples / max_samples);
num_samples_per_segment = ceil(total_samples / num_segments);

bst_progress('start', 'Spike-sorting', 'Demultiplexing raw file...', 0, (parallel == 0) * num_segments * numChannels);

sFiles = {};
for iChannel = 1:numChannels
    sFiles{end + 1} = bst_fullfile(parentPath, ['raw_elec_' cleanNames{iChannel}]);
end


%% Check if a projector has been computed and ask if the selected components
% should be removed
if ~isempty(ChannelMat.Projector)
    isOk = java_dialog('confirm', ...
        ['(ICA/PCA) Artifact components have been computed for removal.' 10 10 ...
             'Remove the selected components?'], 'Artifact Removal');
    if isOk
        ImportOptions.UseSsp = 1;
    end
end 


%% Read data in segments
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

    % Append segment to individual channel file
    if parallel
        parfor iChannel = 1:numChannels
            electrode_data = F(iChannel,:);
            fid = fopen([sFiles{iChannel} '.bin'], 'a');
            fwrite(fid, electrode_data, precision);
            fclose(fid);
        end
    else
        for iChannel = 1:numChannels
            electrode_data = F(iChannel,:);
            fid = fopen([sFiles{iChannel} '.bin'], 'a');
            fwrite(fid, electrode_data, precision);
            fclose(fid);
            bst_progress('inc', 1);
        end
    end
    clear F
    sampleBounds_all{iSegment} = sampleBounds;  % This is here for an easy check that there is no overlap between segments
end


%% Convert binary files per channel to Matlab files
if parallel
    bst_progress('start', 'Spike-sorting', 'Converting demultiplexed files...');
    parfor iChannel = 1:numChannels
        convert2mat(sFiles{iChannel}, sr, precision);
    end
else
    bst_progress('start', 'Spike-sorting', 'Converting demultiplexed files...', 0, (parallel == 0) * numChannels);
    for iChannel = 1:numChannels
        convert2mat(sFiles{iChannel}, sr, precision);
        bst_progress('inc', 1);
    end
end

sFiles = cellfun(@(x) [x '.mat'], sFiles, 'UniformOutput', 0);

end


function convert2mat(chanFile, sr, precision)
    fid = fopen([chanFile '.bin'], 'rb');
    data = fread(fid, precision);
    fclose(fid);
    save([chanFile '.mat'], 'data', 'sr');
    file_delete([chanFile '.bin'], 1 ,3);
end
