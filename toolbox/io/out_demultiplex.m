function outFiles = out_demultiplex(DataFile, ChannelFile, OutputDir, UseSsp, ram, parallel)
% OUT_DEMULTIPLEX: Load a raw data file and creates separate electrode files.

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
% Authors: Konstantinos Nasiotis, 2018-2022
%          Martin Cousineau, 2018
%          Francois Tadel, 2022

% If the output directory doesn't exist: create it
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

% Load channel file
ChannelMat = in_bst_channel(ChannelFile);
numChannels = length(ChannelMat.Channel);
% Channel names: Remove any special characters
cleanNames = str_remove_spec_chars({ChannelMat.Channel.Name});

% Assemble output filenames
outFiles = cellfun(@(c)bst_fullfile(OutputDir, ['raw_elec_', c]), cleanNames, 'UniformOutput', 0);
% If all .mat files already exist: nothing else to do in this function
isFileOk = cellfun(@(c)exist([c, '.mat'], 'file') > 0, outFiles);
if all(isFileOk)
    % Add the .mat extension to the file names
    disp(['BST> Channels already demultiplexed in: ' OutputDir]);
    outFiles = cellfun(@(x) [x '.mat'], outFiles, 'UniformOutput', 0);
    return;
% If some .mat files already exist: delete all intermediate existing file, before generating them again
elseif any(isFileOk)
    cellfun(@(c)delete([c, '.mat']), outFiles(isFileOk));
end

% Load input data file
DataMat = in_bst_data(DataFile, 'F');
sFile = DataMat.F;
sr = sFile.prop.sfreq;

% Apply SSP/ICA when reading from data files
ImportOptions = db_template('ImportOptions');
ImportOptions.UseCtfComp = 0;
ImportOptions.UseSsp     = UseSsp;
% Special case for supported acquisition systems: Save temporary files
% using single precision instead of double to save disk space
if ismember(sFile.format, {'EEG-AXION', 'EEG-BLACKROCK', 'EEG-INTAN', 'EEG-PLEXON'})
    precision = 'single';
    nBytes = 4;
else
    precision = 'double';
    nBytes = 8;
end
ImportOptions.Precision = precision;

% Separate the file to max length based on RAM
max_samples = ram / nBytes / numChannels;
total_samples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq); % (Blackrock/Ripple complained). Removed +1
num_segments = ceil(total_samples / max_samples);
num_samples_per_segment = ceil(total_samples / num_segments);

% Loop on segments
for iSegment = 1:num_segments
    sampleBounds(1) = (iSegment - 1) * num_samples_per_segment + round(sFile.prop.times(1)* sFile.prop.sfreq);
    if iSegment < num_segments
        sampleBounds(2) = sampleBounds(1) + num_samples_per_segment - 1;
    else
        sampleBounds(2) = total_samples + round(sFile.prop.times(1)* sFile.prop.sfreq);
    end
    % Read recordings
    F = in_fread(sFile, ChannelMat, [], sampleBounds, [], ImportOptions);
    % Append segment to individual channel file
    if parallel
        bst_progress('start', 'Spike-sorting', 'Demultiplexing raw file...');
        parfor iChannel = 1:numChannels
            electrode_data = F(iChannel,:);
            fid = fopen([outFiles{iChannel} '.bin'], 'a');
            fwrite(fid, electrode_data, precision);
            fclose(fid);
        end
    else
        bst_progress('start', 'Spike-sorting', 'Demultiplexing raw file...', 0, num_segments * numChannels);
        for iChannel = 1:numChannels
            electrode_data = F(iChannel,:);
            fid = fopen([outFiles{iChannel} '.bin'], 'a');
            fwrite(fid, electrode_data, precision);
            fclose(fid);
            bst_progress('inc', 1);
        end
    end
end

% Convert binary files per channel to Matlab files
if parallel
    bst_progress('start', 'Spike-sorting', 'Converting demultiplexed files...');
    parfor iChannel = 1:numChannels
        convert2mat(outFiles{iChannel}, sr, precision);
    end
else
    bst_progress('start', 'Spike-sorting', 'Converting demultiplexed files...', 0, numChannels);
    for iChannel = 1:numChannels
        convert2mat(outFiles{iChannel}, sr, precision);
        bst_progress('inc', 1);
    end
end

% Add the .mat extension to the file names
outFiles = cellfun(@(x) [x '.mat'], outFiles, 'UniformOutput', 0);

end


%% ===== CONVERT BIN TO MAT =====
function convert2mat(chanFile, sr, precision)
    % Read .bin file
    fid = fopen([chanFile '.bin'], 'rb');
    data = fread(fid, precision);
    fclose(fid);
    % Save .mat file
    save([chanFile '.mat'], 'data', 'sr');
    % Delete .bin file
    delete([chanFile '.bin']);
end
