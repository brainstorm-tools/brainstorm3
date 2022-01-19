function F = in_fread_gtec(sFile, iEpoch, SamplesBounds)
% IN_FREAD_GTEC:  Read a block of recordings from a g.tec/g.Recorder .mat/.hdf5 file.
%
% USAGE:  F = in_fread_gtec(sFile, iEpoch=1, SamplesBounds=[all]) : Read all channels

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
% Authors: Francois Tadel, 2015-2018

% Check inputs
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = [];
else
    iTime = (SamplesBounds(1):SamplesBounds(2)) - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1;
end
if (nargin < 2) || isempty(iEpoch)
    iEpoch = 1;
end

% Handle different file formats
switch (sFile.header.format)
    case 'mat'
        % Read file
        warning('off', 'MATLAB:unknownObjectNowStruct');
        FileMat = load(sFile.filename, 'P_C_S', '-mat');
        warning('on', 'MATLAB:unknownObjectNowStruct');
        if isempty(FileMat) || ~isfield(FileMat, 'P_C_S') || isempty(FileMat.P_C_S)
            error('Invalid g.tec Matlab export: Missing field "P_C_S".');
        end
        % Select only a given time window
        if ~isempty(SamplesBounds)
            F = FileMat.P_C_S.data(iEpoch,iTime,:);
        else
            F = FileMat.P_C_S.data(iEpoch,:,:);
        end
        % Transform to [Channel x Time] matrix
        F = permute(F, [3,2,1]);

    case 'hdf5'
        % Read data
        F = hdf5read(sFile.filename, 'RawData/Samples');
        % Select only a given time window
        F = F(:, iTime);
end
        
% Convert values to uV
F = F .* 1e-6;


