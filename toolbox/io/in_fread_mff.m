function F = in_fread_mff(sFile, iEpoch, SamplesBounds, ImportOptions)
% IN_FREAD_MFF:  Read a block of recordings from an Philips .MFF file
%
% USAGE:  F = in_fread_mff(sFile, iEpoch, SamplesBounds, ImportOptions)

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
% Author: Martin Cousineau, Francois Tadel, 2018-2021


%% ===== INSTALL MFF LIBRARY =====
if ~exist('mff_importsignal', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'mff');
    if ~isInstalled
        error(errMsg);
    end
end

%% ===== PARSE INPUTS =====
% Samples not specified: read the entire epoch
if isempty(SamplesBounds)
    if ~isempty(sFile.epochs)
        SamplesBounds = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
    else
        SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
    end
end
% Rectify samples to read with the first sample number
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);

%% ===== READ DATA =====
if ~isfield(sFile.header, 'EEGDATA') || isempty(sFile.header.EEGDATA)
    % If data not already loaded, load it now
    floatData = mff_importsignal(sFile.filename);
    floatData = [ floatData{:} ];
    % scale signal with calibration values if necessary
    infon = mff_importinfon(sFile.filename);
    if isfield(infon, 'calibration')
        disp('Calibrating data...');
        for iChan = 1:length(infon.calibration)
            floatData(iChan,:,:) = floatData(iChan,:,:)*infon.calibration(iChan);
        end
    end
    sFile.header.EEGDATA = floatData;
end
iTimes = (SamplesBounds(1):SamplesBounds(2)) + 1;
F = double(sFile.header.EEGDATA(:, iTimes, iEpoch));

% Convert from microVolts to Volts
F = 1e-6 * F;

