function F = in_fread_brainamp(sFile, sfid, SamplesBounds)
% IN_FREAD_BRAINAMP:  Read a block of recordings from BrainVision BrainAmp .eeg file
%
% USAGE:  F = in_fread_brainamp(sFile, sfid, SamplesBounds=[])

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
% Authors: Francois Tadel, 2012-2013

% Parse inputs
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% BINARY and MULTIPLEXED files
if (strcmpi(sFile.header.DataFormat, 'BINARY') && strcmpi(sFile.header.DataOrientation, 'MULTIPLEXED'))
    nChan = sFile.header.NumberOfChannels;
    % Get start and length of block to read
    offsetData = SamplesBounds(1) * nChan * sFile.header.bytesize;
    nSamplesToRead = SamplesBounds(2) - SamplesBounds(1) + 1;
    % Position file at the beginning of the data block
    fseek(sfid, offsetData, 'bof');
    % Read all values at once
    F = fread(sfid, [nChan, nSamplesToRead], sFile.header.byteformat);
    
% ASCII and VECTORIZED files
elseif (strcmpi(sFile.header.DataFormat, 'ASCII') && strcmpi(sFile.header.DataOrientation, 'VECTORIZED'))
    % Open file
    fid = fopen(sFile.filename, 'r');
    % Initialize data matrix
    F = zeros(sFile.header.NumberOfChannels, sFile.header.DataPoints);
    iChannel = 1;
    % Read the entire file line by line
    while(1)
        % Display message 
        % disp(sprintf('BRAINAMP> Reading channel #%d...', iChannel));
        % Reached the end of the file: exit the loop
        if feof(fid)
            break; 
        end
        % Read one line
        strChan = strtrim(fgetl(fid));
        if isempty(strChan)
            continue;
        end
        % Find the first separator
        iSep = min([find(strChan == ' ',1), find(strChan == sprintf('\t'),1)]);
        % Replace "," with "." for the numbers
        strChan(strChan == ',') = '.';
        % Read the values
        F(iChannel,:) = sscanf(strChan(iSep+1:end), '%f')';
        iChannel = iChannel+1;
    end
    % Close file
    fclose(fid);
    % Select only the requested time points
    iTime = (SamplesBounds(1):SamplesBounds(2)) - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1;
    F = F(:,iTime);
end

% Apply gains, if available
if isfield(sFile.header, 'chgain') && (length(sFile.header.chgain) == size(F,1))
    F = bst_bsxfun(@times, F, sFile.header.chgain(:));
% Else: Convert from microVolts to Volts by default
else
    F = F * 1e-6;
end
