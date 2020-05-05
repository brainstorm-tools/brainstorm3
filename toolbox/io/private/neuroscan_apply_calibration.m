function F = neuroscan_apply_calibration(F, hdr)
% NEUROSCAN_APPLY_CALIBRATION: Apply the calibration factors each channel of the data matrix.
%
% USAGE:  F = neuroscan_apply_calibration(F, hdr)
%
% INPUT:
%     - F   : Recordings [nChannels x nTime]
%     - hdr : Neuroscan file header

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
% Authors: Francois Tadel, 2009

% Loop on all the channels
for iChan = 1:hdr.data.nchannels
    % Convert to Volts
    baseline = hdr.electloc(iChan).baseline;
    calibration = hdr.electloc(iChan).calib;
    sensitivity = hdr.electloc(iChan).sensitivity;
    n = hdr.electloc(iChan).n;
    
    % Apply thoses factors to channel #i (and convert to Volts)
    switch lower(hdr.fileFormat)
        case 'avg'
            chanCalib = calibration ./ n .* 1e-6;
        case {'eeg', 'cnt'}
            chanCalib = calibration * sensitivity / 204.8 * 1e-6;
        otherwise
            error('Unknown file format.');
    end
    F(iChan,:) = ( F(iChan,:) - baseline ) .* chanCalib;
end





