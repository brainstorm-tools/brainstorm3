function F = in_fread_megscan(sFile, SamplesBounds)
% IN_FREAD_MEGSCAN:  Read a block of recordings from a MEGSCAN .hdf5 file.
%
% USAGE:  F = in_fread_megscan(sFile, SamplesBounds=[all]) : Read all channels

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
% Authors: Elizabeth Bock, Francois Tadel, 2019

% Check inputs
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% % Read data
% F = h5read(sFile.filename, [sFile.header.acquisitionname '/data/']);
% % Select only a given time window
% iTime = (SamplesBounds(1):SamplesBounds(2)) - sFile.prop.samples(1) + 1;
% F = F(:, iTime);

% Dimensions of the matrix to read
readDim = [sFile.header.numberchannels, SamplesBounds(2)-SamplesBounds(1)+1];
readOffset = [0, SamplesBounds(1)];
% Read only the requested time points
fid = H5F.open(sFile.filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
dset_id = H5D.open(fid, [sFile.header.acquisitionname '/data/']);
file_space_id = H5D.get_space(dset_id);
mem_space_id = H5S.create_simple(2, fliplr(readDim), []);
H5S.select_hyperslab(file_space_id, 'H5S_SELECT_SET', fliplr(readOffset), [], [1 1], fliplr(readDim));
F = H5D.read(dset_id, 'H5ML_DEFAULT', mem_space_id ,file_space_id, 'H5P_DEFAULT');
H5D.close(dset_id);
H5F.close(fid);




