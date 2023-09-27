function F = in_fread_eeglab(sFile, iEpoch, SamplesBounds)
% IN_FREAD_EEGLAB:  Read a block of recordings from an EEGLAB .set file
%
% USAGE:  F = in_fread_eeglab(sFile, iEpoch, SamplesBounds) : Read all channels
%         F = in_fread_eeglab(sFile, iEpoch)                : Read all channels, all the times
%         F = in_fread_eeglab(sFile)                        : Read all channels, all the times, for first epoch

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
% Author: Francois Tadel 2013-2023

%% ===== PARSE INPUTS =====
nChannels = sFile.header.EEG.nbchan;
nTime     = sFile.header.EEG.pnts;
nEpochs   = sFile.header.EEG.trials;
% Epoch not specified: read only the first one
if (nargin < 2)
    iEpoch = 1;
end
% If only one sample in file
isSingleSample = (nTime == 1);
if isSingleSample
    SamplesBounds = [0, 0];
% Multiple samples
else
    % Samples not specified: read the entire epoch
    if (nargin < 3) || isempty(SamplesBounds)
        if ~isempty(sFile.epochs)
            SamplesBounds = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
        else
            SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
        end
    end
    % Rectify samples to read with the first sample number
    SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);
end
F = [];



%% ===== READ DATA =====
% Data saved in the .set file
if isfield(sFile.header, 'EEGDATA') && ~isempty(sFile.header.EEGDATA)
    iTimes = (SamplesBounds(1):SamplesBounds(2)) + 1;
    F = double(sFile.header.EEGDATA(:, iTimes, iEpoch));   

% Data saved in a separate binary file
elseif isfield(sFile.header.EEG, 'data') && ~isempty(sFile.header.EEG.data) && ischar(sFile.header.EEG.data)
    % Get link path and extension
    [fPathLink, fBaseLink, fExtLink] = bst_fileparts(sFile.header.EEG.data);
    % If file not found: try to locate it in the same folder as the .set file
    if ~file_exist(sFile.header.EEG.data)
        [fPathSet,fNameSet,fExtSet]= fileparts(sFile.filename);
        BinFile = bst_fullfile(fPathSet, [fBaseLink, fExtLink]);
    else
        BinFile = sFile.header.EEG.data;
    end
    % Open .DAT/.FDT file (Always in little endian format)
    sfid = fopen(BinFile, 'rb', 'ieee-le');
    if (sfid == -1)
        error(['Cannot open data file: ', sFile.header.EEG.data]);
    end
    % Some information about the data storage
    bytesize = 4;
    % Format of storage depends on the file extension
    switch (lower(fExtLink))
        case '.dat'
            % FORMAT: linear matrix [(nTime x nEpochs) x nChannels]
            % Get start position
            offsetTime  = SamplesBounds(1) * bytesize;
            offsetEpoch = nTime * (iEpoch - 1) * bytesize;
            % Number of time values to read for each channel
            nTimeToRead = SamplesBounds(2) - SamplesBounds(1) + 1;
            % Number of values to skip after each channel
            nSkipTimeEnd  = (nTime - SamplesBounds(2) - 1) * bytesize;
            nSkipEpoch    = nTime * (nEpochs - 1) * bytesize;
            nSkip         = nSkipTimeEnd + offsetTime + nSkipEpoch;
            % Position file at the beginning of the data block
            fseek(sfid, double(offsetTime + offsetEpoch), 'bof');
            % Read everything at once 
            % => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
            if (nSkip == 0)
                F = fread(sfid, [nTime, nChannels], '*float32');
            else
                precision = sprintf('%d*float32=>float32', nTimeToRead);
                F = fread(sfid, [nTimeToRead, nChannels], precision, nSkip);
            end
            % Transpose to get [nChannels x nTime]
            F = F';
            
            % === OLD READING FUNCTION ====================================================
            % % To read all the trials at once
            % [F, read_count] = fread(sfid, [nTime*nEpochs, nChannels], '*float32' );
            % % Convert read matrix in [nbChan, nTime, nEpochs] matrix
            % F = reshape(F', nChannels, nTime, nEpochs);
            % =============================================================================
            
        case '.fdt'
            % FORMAT: linear matrix [nChannels x (nTime x nEpochs)]
            % Get start position
            offsetTime  = SamplesBounds(1) * nChannels * bytesize;
            offsetEpoch = (nChannels * nTime) * (iEpoch - 1) * bytesize;
            % Number of time values to read for each channel
            nTimeToRead = SamplesBounds(2) - SamplesBounds(1) + 1;
            % Number of values to skip after each channel
            nSkipTimeEnd  = (nTime - SamplesBounds(2) - 1) * nChannels * bytesize;
            nSkipEpoch    = nTime * nChannels * (nEpochs - 1) * bytesize;
            nSkip         = nSkipTimeEnd + offsetTime + nSkipEpoch;
            % Position file at the beginning of the data block
            fseek(sfid, double(offsetTime + offsetEpoch), 'bof');
            % Read everything at once 
            % => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
            if (nSkip == 0)
                F = fread(sfid, [nChannels, nTime], '*float32');
            else
                precision = sprintf('%d*float32=>float32', nTimeToRead * nChannels);
                F = fread(sfid, [nChannels, nTimeToRead], precision, nSkip);
            end
            
            % === OLD READING FUNCTION ====================================================
            % % To read all the trials at once
            % [F, read_count] = fread( sfid, [nChannels, nTime*nEpochs], '*float32' );
            % % Convert read matrix in [nbChan, nTime, nEpochs] matrix
            % F = reshape(F, nChannels, nTime, nEpochs);
            % =============================================================================
        otherwise
            error(['Unsupported binary file extension: ' fExtLink]);
    end
    % Close file
    fclose(sfid);
    % Check that data was fully read
    if isempty(F) || (numel(F) ~= nChannels * nTimeToRead)
        error('Errors in binary file: file might be incomplete.');
    end
else
    error('Don''t know how to get the data from...');
end

% Convert from microVolts to Volts
F = 1e-6 * F;
% If there is one single sample: duplicate it
if isSingleSample
    F = repmat(F, 1, 2);
end

% === APPLY ICA MATRIX ===
if isfield(sFile.header.EEG, 'icaweights') && ~isempty(sFile.header.EEG.icaweights)
    disp('EEGLAB> Warning: ICA matrices are present in the file, but ignored in Brainstorm.');
%     iChan = sFile.header.EEG.icachansind;
%     DataMat(iTrial).F(iChan,:) = sFile.header.EEG.icaweights * DataMat(iTrial).F(iChan,:);
end



