function [ftData, MatrixMat] = out_fieldtrip_matrix( MatrixFile )
% OUT_FIELDTRIP_DATA: Converts a matrix file into a timelock FieldTrip structure: ft_datatype_timelock.m
% 
% USAGE:  [ftData, MatrixMat] = out_fieldtrip_matrix(MatrixFile);
%         [ftData, MatrixMat] = out_fieldtrip_matrix(MatrixMat);
%
% INPUTS:
%    - MatrixFile : Relative path to a matrix file available in the database
%    - MatrixMat  : Matrix file structure 

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
% Authors: Francois Tadel, 2015


% Load file
if ischar(MatrixFile)
    MatrixMat = in_bst_matrix(MatrixFile);
else
    MatrixMat = MatrixFile;
end

% Remove the @filename at the end of the row names
for iRow = 1:numel(MatrixMat.Description)
    iAt = find(MatrixMat.Description{iRow} == '@', 1);
    if ~isempty(iAt) && any(MatrixMat.Description{iRow}(iAt+1:end) == '/')
        MatrixMat.Description{iRow} = strtrim(MatrixMat.Description{iRow}(1:iAt-1));
    end
end

% Convert to FieldTrip data structure
ftData = struct();
ftData.dimord = 'chan_time';
ftData.avg    = MatrixMat.Value;
ftData.time   = MatrixMat.Time;
ftData.label  = MatrixMat.Description;





