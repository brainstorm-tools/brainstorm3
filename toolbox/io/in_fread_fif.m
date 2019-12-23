function [F,TimeVector] = in_fread_fif(sFile, iEpoch, SamplesBounds, iChannels)
% IN_READ_FIF:  Read a block of recordings from a FIF file
%
% USAGE:  [F,TimeVector] = in_fread_fif(sFile, iEpoch, SamplesBounds, iChannels)
%         [F,TimeVector] = in_fread_fif(sFile, iEpoch, SamplesBounds)            : Read all the channels

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2019

if (nargin < 4)
    iChannels = [];
end

% Epoched data
% if isempty(SamplesBounds) || ~isfield(sFile.header, 'raw') || isempty(sFile.header.raw)
if ~isfield(sFile.header, 'raw') || isempty(sFile.header.raw)
    % Use data already read
    if isfield(sFile.header, 'epochData') && ~isempty(sFile.header.epochData)
        F = permute(sFile.header.epochData(iEpoch,:,:), [2,3,1]);
        TimeVector = linspace(sFile.epochs(iEpoch).times(1), sFile.epochs(iEpoch).times(2), size(F,2));
    % Read data from file
    else
        sfid = fopen(sFile.filename, 'r', sFile.byteorder);
        [F, TimeVector] = fif_read_evoked(sFile, sfid, iEpoch);
        fclose(sfid);
    end
    % Specific selection of channels
    if ~isempty(iChannels)
        F = F(iChannels, :);
    end
    % Specific time selection
    if ~isempty(SamplesBounds)
        iTime = SamplesBounds - round(sFile.epochs(iEpoch).times(1) .* sFile.prop.sfreq) + 1;
        F = F(:, iTime(1):iTime(2));
        TimeVector = TimeVector(iTime(1):iTime(2));
    end
    % Calibration matrix
    Calibration = diag([sFile.header.info.chs.cal]);
% Raw data
else
    % If time not specified, read the entire file
    if isempty(SamplesBounds)
        SamplesBounds = [sFile.header.raw.first_samp, sFile.header.raw.last_samp];
    end
    % If there are multiple FIF files: check in which one the data should be read
    if isfield(sFile.header, 'fif_list') && isfield(sFile.header, 'fif_times') && (length(sFile.header.fif_list) > 2)
        % Check if all the samples are gathered from the same file
        fif_samples = round(sFile.header.fif_times .* sFile.prop.sfreq);
        iFile = find((SamplesBounds(1) >= fif_samples(:,1)) & (SamplesBounds(2) <= fif_samples(:,2)));
        % If this requires reading multiple files, call this function recursively
        if isempty(iFile)
            F = [];
            TimeVector = [];
            % Select the files to read from
            iFileStart = find((SamplesBounds(1) >= fif_samples(:,1)) & (SamplesBounds(1) <= fif_samples(:,2)));
            iFileStop  = find((SamplesBounds(2) >= fif_samples(:,1)) & (SamplesBounds(2) <= fif_samples(:,2)));
            for iFile = iFileStart:iFileStop
                % Create local structures for this file
                sFile_i = sFile;
                sFile_i.header = sFile.header.fif_headers{iFile};
                % Read the samples available in this file
                SamplesBounds_i = bst_saturate(SamplesBounds, fif_samples(iFile,:), 1);
                [F_i,TimeVector_i] = in_fread_fif(sFile, iEpoch, SamplesBounds_i, iChannels);
                % Concatenate with previous files
                F = [F, F_i];
                TimeVector = [TimeVector, TimeVector_i];
            end
            return;
        else
            FifFile = sFile.header.fif_list{iFile(1)};
            sFile.header = sFile.header.fif_headers{iFile};
        end
    else
        FifFile = sFile.filename;
    end
    % Read block of data
    sfid = fopen(FifFile, 'r', sFile.byteorder);
    [F, TimeVector] = fif_read_raw_segment(sFile, sfid, SamplesBounds, iChannels);
    fclose(sfid);
    % Calibration matrix
    Calibration = diag([sFile.header.info.chs.range] .* [sFile.header.info.chs.cal]);
end

% Apply calibration
if ~isempty(iChannels)
    F = Calibration(iChannels,iChannels) * F;
else
    F = Calibration * F;
end




