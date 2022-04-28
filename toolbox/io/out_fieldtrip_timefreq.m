function [ftData, TimefreqMat, neighbours] = out_fieldtrip_timefreq(TimefreqFile, ChannelFile)
% OUT_FIELDTRIP_TIMEFREQ: Converts a time-frequency file into a FieldTrip structure (ft_datatype_freq.m).
% 
% USAGE:  [ftData, TimefreqMat] = out_fieldtrip_timefreq(TimefreqFile, ChannelFile=[]);
%
% INPUTS:
%    - TimefreqFile : Relative path to a time-frequency file available in the database

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
% Authors: Arnaud Gloaguen, Francois Tadel, 2015-2016

% Get ChannelFile if not provided
if (nargin < 2) || isempty(ChannelFile)
    ChannelFile = bst_get('ChannelFileForStudy', TimefreqFile);
end

% Load data file
TimefreqMat = in_bst_timefreq(TimefreqFile, 1);
% Cannot process full source files: use ft_sourcestatistics
if strcmpi(TimefreqMat.DataType, 'results')
    error('To process time-frequency results on full cortex maps, use function "ft_sourcestatistics".');
end
% Apply default measure to TF values
if ~isreal(TimefreqMat.TF)
    % Get default function
    defMeasure = process_tf_measure('GetDefaultFunction', TimefreqMat);
    % Apply default function
    [TimefreqMat.TF, isError] = process_tf_measure('Compute', TimefreqMat.TF, TimefreqMat.Measure, defMeasure);
    if isError
        error(['Error: Invalid measure conversion: ' sMat.Measure ' => ' defMeasure]);
    end
end
% Remove the @filename at the end of the row names
for iRow = 1:numel(TimefreqMat.RowNames)
    iAt = find(TimefreqMat.RowNames{iRow} == '@', 1);
    if ~isempty(iAt) && any(TimefreqMat.RowNames{iRow}(iAt+1:end) == '/')
        TimefreqMat.RowNames{iRow} = strtrim(TimefreqMat.RowNames{iRow}(1:iAt-1));
    end
end


% Convert to FieldTrip freq data structure: see ft_datatype_freq.m
ftData = struct();
ftData.dimord    = 'chan_time_freq';
ftData.powspctrm = TimefreqMat.TF;
% Time: only one value in the case of power spectrum
if (size(ftData.powspctrm,2) == 1)
    ftData.time = TimefreqMat.Time(1);
else
    ftData.time = TimefreqMat.Time;
end
% Frequency bands: Take the middle of the band
if iscell(TimefreqMat.Freqs)
    BandBounds = process_tf_bands('GetBounds', TimefreqMat.Freqs);
    ftData.freq = mean(BandBounds,2);
% Frequency bins
else
    ftData.freq = TimefreqMat.Freqs;
end
% Signals labels
ftData.label = TimefreqMat.RowNames;

% Get neighbours
if (nargout >= 3)
    neighbours = [];
    % Depends on the file type
    switch (TimefreqMat.DataType)
        case 'data'
            % Load channel file
            ChannelMat = in_bst_channel(ChannelFile);
            % Find row names in channel file
            [tmp,iChannels,iRows] = intersect({ChannelMat.Channel.Name}, TimefreqMat.RowNames);
            % Get channel file
            if ~isempty(iChannels)
                % Count total number of channels in this modality
                Modality = ChannelMat.Channel(iChannels(1)).Type;
                nChanMod = nnz(strcmpi({ChannelMat.Channel.Type}, Modality));
                % Find neighbors (only if there are more than 40% of the channels selected)
                if (length(iChannels) > ceil(0.4 * nChanMod)) 
                    neighbours = channel_neighbours(ChannelMat, iChannels);
                end
            end  
        case 'results'
            error('Already handled at the beginning of the function.');
        case {'matrix', 'scout'}
            % Nothing to do
    end
end



