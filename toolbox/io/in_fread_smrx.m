function F = in_fread_smrx(sFile, SamplesBounds, iChannels)
% IN_FREAD_SMRX:  Read a block of recordings from a Cambridge Electronic Design Spike2 64bit file (.smr/.son)
%
% USAGE:  F = in_fread_smrx(sFile, SamplesBounds=[], iChannels=[])

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
% Authors:  Francois Tadel, 2020


%% ===== SETUP MATCED LIBRARY =====
% Check operating system
if ~strcmpi(bst_get('OsType'), 'win64')
    error('The MATCED library for reading .smrx files is available only on Windows 64bit.');
end
% Add path to CED code
if isempty(getenv('CEDS64ML'))
    cedpath = fileparts(which('CEDS64Open'));
    setenv('CEDS64ML', fileparts(which('CEDS64Open')));
    CEDS64LoadLib(cedpath);
end


%% ===== READ DATA =====
% Parse inputs
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.nchan;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Initialize returned matrix
nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;
F = zeros(length(iChannels), nSamples);

% Open file
fhand = CEDS64Open(sFile.filename, 1);
if (fhand < 0)
    error('Could not open file.');
end
% Loop to read all the channels
for i = 1:length(iChannels)
    % Ticks to read
    tol = floor(1./sFile.header.timebase./sFile.prop.sfreq);
    tickBounds = (SamplesBounds ./ sFile.prop.sfreq ./ sFile.header.timebase) + [0, tol];
    % Read data
    [nRead, Fchan] = CEDS64ReadWaveF(fhand, sFile.header.chaninfo(iChannels(i)).number, nSamples, tickBounds(1), tickBounds(2));
    % Apply gain
    if (sFile.header.chaninfo(iChannels(i)).gain ~= 1)
        Fchan = Fchan .* sFile.header.chaninfo(iChannels(i)).gain;
    end
    % Resample to expected sampling rate if needed
    if (sFile.prop.sfreq ~= sFile.header.chaninfo(iChannels(i)).idealRate)
        isResample = 1;
    elseif (nRead ~= nSamples)
        disp(sprintf('BST> Warning: Channel "%s": %d values expected, %d values read. Padding with zeros...', sFile.header.chaninfo(iChannels(i)).title, nSamples, nRead));
        isResample = 0;
    else
        isResample = 0;
    end
    if isResample
        disp(sprintf('BST> Warning: Channel "%s" reinterpolated from %dHz to %dHz', sFile.header.chaninfo(iChannels(i)).title, round(sFile.header.chaninfo(iChannels(i)).idealRate), round(sFile.prop.sfreq)));
        F(i,:) = interp1(linspace(0,1,length(Fchan)), Fchan, linspace(0,1,nSamples));
    else
        F(i,1:nRead) = Fchan;
    end
end
% Close file
CEDS64Close(fhand);


