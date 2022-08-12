function F = in_fread_bci2000(sFile, SamplesBounds)
% IN_FREAD_BCI2000: Read a block of recordings from a BCI2000 .dat file
%
% Uses library: https://www.bci2000.org/mediawiki/index.php/User_Reference:Matlab_MEX_Files

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
% Author: Francois Tadel 2022

% Parse inputs
if (nargin < 2) || isempty(SamplesBounds)
    if ~isempty(sFile.epochs)
        SamplesBounds = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
    else
        SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
    end
end

% Install plugin BCI2000
if ~exist('load_bcidat', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'bci2000');
    if ~isInstalled
        error(errMsg); 
    end
end

% Read signals
F = load_bcidat(sFile.filename, SamplesBounds + 1, '-calibrated')';


