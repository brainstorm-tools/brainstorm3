function FibMat = in_fibers_trk(FibFile, N)
% IN_FIBERS_TRK: Read TrackVis .trk file into Brainstorm format.
%
% USAGE:  FibMat = in_fibers_trk(FibFile);
%
% INPUT: 
%     - FibFile : full path to a fibers file
%     - N: Number of points per streamline
% OUTPUT:
%     - FibMat:  Brainstorm fibers structure
%
% SEE ALSO: in_fibers

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
% Authors: Martin Cousineau, 2019

% Read using external function
bst_progress('text', 'Reading TRK...');
[header, tracks] = trk_read(FibFile);

%TEMP
%tracks = tracks(1:min(10000, length(tracks)));

% Convert to N points
bst_progress('text', ['Interpolating fibers to ' num2str(N) ' points...']);
tracks_interp = trk_interp(tracks, N);

% Convert to meters
tracks_interp = tracks_interp / 1000;


%% ===== CONVERT IN BRAINSTORM FORMAT =====
FibMat = db_template('fibers');
FibMat.Points = permute(tracks_interp, [3,1,2]);
FibMat.Header = header;


