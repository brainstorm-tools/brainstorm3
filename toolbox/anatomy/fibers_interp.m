function [NewFibFile, iSurface] = fibers_interp(FibFile, newNbPoints)
% FIBERS_INTERP: Interpolates the points of all fibers in a fiber file.
%
% USAGE:  [NewFibFile, iSurface] = fibers_interp(FibFile, newNbPoints=[ask]);
% 
% INPUT: 
%    - FibFile       : Full path to fiber file to interpolate
%    - newNbPoints   : Desired number of points
% OUTPUT:
%    - NewFibFile  : Filename of the newly created file
%    - iSurface    : Index of the new surface file

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
% Authors: Martin Cousineau, 2019


%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(newNbPoints)
    newNbPoints = [];
end
% File name: string or cell array of strings
MultipleFiles = [];
if iscell(FibFile)
    if (length(FibFile) > 1)
        MultipleFiles = FibFile;
    end
    FibFile = FibFile{1};
end
% Initialize returned values
NewFibFile = '';
iSurface = [];

%% ===== ASK FOR MISSING OPTIONS =====
% Get the number of vertices
VarInfo = whos('-file',file_fullpath(FibFile),'Points');
oldNbPoints = VarInfo.size(2);
% If new number of vertices was not provided: ask user
if isempty(newNbPoints)
    % Ask user the new number of vertices
    newNbPoints = java_dialog('input', 'New number of points:', ...
                                         'Interpolate fibers', [], num2str(oldNbPoints));
    if isempty(newNbPoints)
        return
    end
    % Read user input
    newNbPoints = str2double(newNbPoints);
end
% Check if new number of vertices is valid
if isempty(newNbPoints) || isnan(newNbPoints) || newNbPoints < 2
    error('Invalid points number');
end


%% ===== PROCESS MULTIPLE FILES =====
if ~isempty(MultipleFiles)
    for i = 1:length(MultipleFiles)
        [NewFibFile, iSurface] = fibers_interp(MultipleFiles{i}, newNbPoints);
    end
    return;
end
    
%% ===== LOAD FILE =====
% Progress bar
bst_progress('start', 'Interpolate fibers', 'Loading file...');
% Load file
FibMat = in_fibers(FibFile);
NewFibMat = db_template('fibersmat');


%% ===== INTERPOLATE =====
bst_progress('text', 'Creating data structure...');
% Build structure for trk_interp()
tracks = struct('nPoints', 0, 'matrix', []);
nFib = size(FibMat.Points, 1);
for iFib = 1:nFib
    tracks(iFib).matrix = squeeze(FibMat.Points(iFib,:,:));
    tracks(iFib).nPoints = oldNbPoints;
end
% Interpolate fibers
bst_progress('text', 'Interpolating fibers...');
tracks_interp = trk_interp(tracks, newNbPoints);
NewFibMat.Points = permute(tracks_interp, [3,1,2]);
% Update color
NewFibMat = fibers_helper('ComputeColor', NewFibMat);


%% ===== CREATE NEW FIBER STRUCTURE =====
% Build new filename and Comment
[filepath, filebase, fileext] = bst_fileparts(file_fullpath(FibFile));
% Remove previous '_nbptPt' tags from Comment field
NewComment = regexprep(FibMat.Comment, '_\d+Pt_', sprintf('_%dPt_', newNbPoints));

% Remove previous '_nbptPt' tags from filename
if length(filebase) > 2 && all(filebase(end-1:end) == 'Pt')
    iUnderscore = strfind(filebase, '_');
    filebase = filebase(1:iUnderscore(end)-1);
end
% Add a '_nbptPt' tag
NewFibFile = file_unique(bst_fullfile(filepath, sprintf('%s_%dPt%s', filebase, newNbPoints, fileext)));
NewFibMat.Comment  = NewComment;
% Copy Header field
if isfield(FibMat, 'Header')
    NewFibMat.Header = FibMat.Header;
end
% Copy history field
if isfield(FibMat, 'History')
    NewFibMat.History = FibMat.History;
end
% History: Interpolate fibers
NewFibMat = bst_history('add', NewFibMat, 'interpolate', sprintf('Interpolate fibers: %d -> %d points', oldNbPoints, newNbPoints));


%% ===== UPDATE DATABASE =====
% Save interpolated fiber file
bst_save(NewFibFile, NewFibMat, 'v7');
% Make output filename relative
NewFibFile = file_short(NewFibFile);
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', FibFile);
% Register this file in Brainstorm database
iSurface = db_add_surface(iSubject, NewFibFile, NewComment);

% Close progress bar
bst_progress('stop');

end

