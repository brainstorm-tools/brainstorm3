function OutputFile = import_timefreq_ft(iStudy)
% IMPORT_MATRIX: Imports a 2D matrix as a "matrix" file.
%
% USAGE:  OutputFile = import_matrix(iStudy, Value=[ask], sfreq=[ask])
%
% INPUT:
%    - iStudy  : Index of the study where to import the SourceFiles
%    
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
%
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Alexandre Chalard, 2019


OutputFile = [];
[FileName,PathName] = uigetfile('*.mat'); % It seems to be improved with java_selector()
DataFile = fullfile(PathName,FileName);
if isempty(DataFile); return; end
DataMat  = in_timefreq_fieldtrip(DataFile);

% Add history entry
DataMat = bst_history('add', DataMat, 'process', 'Imported timefreq from FieldTrip');

% Add structure to database
OutputFile = db_add(iStudy, DataMat);

