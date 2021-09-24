function F = in_fread_neuralynx(sFile, SamplesBounds, iChannels)
% IN_FREAD_NEURALYNX  Read a block of recordings from a Neuralynx file (*.ncs)
%
% USAGE:  F = in_fread_neuralynx(sFile, SamplesBounds=[], iChannels=[])

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
% Authors: Francois Tadel, 2015-2021

% Parse inputs
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.NumChannels;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Initialize requested matrix
nReadSamples = SamplesBounds(2)-SamplesBounds(1)+1;
F = zeros(length(iChannels), nReadSamples);

% Loop on the channels to read (one file per channel)
for iChan = 1:length(iChannels)
    % Get header for this channel
    hdr = sFile.header.chan_headers{iChannels(iChan)};
    % Open file
    ChanFile = bst_fullfile(sFile.header.BaseFolder, sFile.header.chan_files{iChannels(iChan)});
    sfid = fopen(ChanFile, 'r', sFile.byteorder);
    if (sfid < 0)
        error(['Cannot open file: ' ChanFile]);
    end
    
    % Reading files of different types
    switch (hdr.FileExtension)
        % NCS: LFP files, read continuous signals
        case 'NCS'
            % Get the list of records that we are supposed to read
            recBounds = floor(SamplesBounds / 512);
            nReadRecords = recBounds(2) - recBounds(1) + 1;
            % Offsets
            offsetStart = hdr.HeaderSize + recBounds(1) * hdr.RecordSize + 20;
            offsetSkip = 20;  % Header of each record: uint64+3*int32
            % Seek at the beginning of the first record to read
            fseek(sfid, offsetStart, 'bof');
            % Read all the records involved
            Ftmp = fread(sfid, [512, nReadRecords], '512*int16', offsetSkip);
            % Rebuild the indices of the samples that were read
            readSamples = [recBounds(1)*512, (recBounds(2)+1)*512 - 1];
            % Get the indices of the samples that were requested within these indices
            iSamples = SamplesBounds - readSamples(1) + 1;
            iSamples = iSamples(1):iSamples(2);
            % Copy values to final matrix
            F(iChan, :) = Ftmp(iSamples);
            
        % NSE: Spike files, just set the values wherever they are defined
        case 'NSE'
            % Compute the spikes samples
            SpikeSamples = round(hdr.SpikeTimes .* sFile.prop.sfreq);
            % Get the spikes happening during the selected segment
            iSpikes = find((SpikeSamples + hdr.NumSamples >= SamplesBounds(1)) & (SpikeSamples <= SamplesBounds(2)));
            % Size of one record in the file
            sizeRecHdr = 48 + hdr.NumSamples * 2;
            % Loop on the spikes that were found
            for i = 1:length(iSpikes)
                % Seek at the beginning of the spike data
                offsetStart = hdr.HeaderSize + (iSpikes(i)-1) * hdr.RecordSize + sizeRecHdr;
                fseek(sfid, offsetStart, 'bof');
                % Read the spike data
                dat = fread(sfid, hdr.NumSamples, 'int16');
                % Find the samples of this spike in the read segment
                iSmpSpike = 1:hdr.NumSamples;
                iSmpFile  = SpikeSamples(iSpikes(i)) - SamplesBounds(1) + iSmpSpike;
                iGoodSmp = find((iSmpFile >= 1) & (iSmpFile <= nReadSamples));
                % Set the data in the file
                F(iChan, iSmpFile(iGoodSmp)) = dat(iSmpSpike(iGoodSmp));
            end
    end
    % Close file
    fclose(sfid);
    % Apply the scaling factor from ADBitVolts (converts to Volts)
    F(iChan,:) = F(iChan,:) .* hdr.ADBitVolts;
end





