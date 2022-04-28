function F = in_fread_spm(sFile, SamplesBounds, iChannels)
% IN_FREAD_SPM:  Read a block of recordings from a continuous SPM .mat/.dat file
%
% USAGE:  F = in_fread_spm(sFile, SamplesBounds=[], iChannels=[])

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
% Authors: Francois Tadel, 2017

% Check if SPM is in the path
if ~exist('file_array', 'file')
    error('SPM must be in the Matlab path to use this feature.');
end

% Parse inputs
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.nChannels;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Convert samples to indices in the file
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);
iTimes = (SamplesBounds(1):SamplesBounds(2)) + 1;

% Fix file link
[fPath,fBase,fExt] = bst_fileparts(sFile.filename);
sFile.header.file_array.fname = bst_fullfile(fPath, [fBase, '.dat']);
% Check file link
if ~file_exist(sFile.header.file_array.fname)
    error(['File not found: ', sFile.header.file_array.fname]);
end
% Read data
F = sFile.header.file_array(iChannels, iTimes);

% Apply gains
if isfield(sFile.header, 'gain') && (size(sFile.header.gain,1) == sFile.header.nChannels)
    F = bst_bsxfun(@times, F, sFile.header.gain(iChannels));
end

