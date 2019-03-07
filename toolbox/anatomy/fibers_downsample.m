function [NewFibFile, iSurface, I, J] = fibers_downsample(FibFile, newNbFibers, Method)
% FIBERS_DOWNSAMPLE: Reduces the number of fibers in a fiber file.
%
% USAGE:  [NewFibFile, iSurface, I, J] = fibers_downsample(FibFile, newNbFibers=[ask], Method=[ask]);
% 
% INPUT: 
%    - FibFile       : Full path to fiber file to downsample
%    - newNbFibers   : Desired number of fibers
%    - Method        : {'random'}
% OUTPUT:
%    - NewFibFile  : Filename of the newly created file
%    - iSurface    : Index of the new surface file
%    - I,J         : Indices of the vertices that were kept (see intersect function)

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


%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(Method)
    Method = [];
end
if (nargin < 2) || isempty(newNbFibers)
    newNbFibers = [];
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
I = [];
J = [];


%% ===== ASK FOR MISSING OPTIONS =====
% Get the number of vertices
VarInfo = whos('-file',file_fullpath(FibFile),'Points');
oldNbFibers = VarInfo.size(1);
% If new number of vertices was not provided: ask user
if isempty(newNbFibers)
    % Ask user the new number of vertices
    newNbFibers = java_dialog('input', 'New number of fibers:', ...
                                         'Resample fibers', [], num2str(oldNbFibers));
    if isempty(newNbFibers)
        return
    end
    % Read user input
    newNbFibers = str2double(newNbFibers);
end
% Check if new number of vertices is valid
if isempty(newNbFibers) || isnan(newNbFibers)
    error('Invalid fibers number');
end
if (newNbFibers >= oldNbFibers)
    NewFibFile = FibFile;
    disp(sprintf('TESS> Fibers file has %d fibers, cannot downsample to %d fibers.', oldNbFibers, newNbFibers));
    return;
end

% Ask for resampling method
if isempty(Method)
    % Ask method
    %ind = java_dialog('radio', 'Select the resampling method:', 'Resample fibers', [], ...
    %                  {['<HTML><B><U>Random:</U></B><BR>' ...
    %                    '&nbsp;&nbsp;&nbsp;| - Selects fibers to keep randomly']);
    ind = 1; % Force random as it's the only method for now.
    if isempty(ind)
        return
    end
    % Select corresponding method name
    switch (ind)
        case 1,  Method = 'random';
    end
end


%% ===== PROCESS MULTIPLE FILES =====
if ~isempty(MultipleFiles)
    for i = 1:length(MultipleFiles)
        [NewFibFile, iSurface, I, J] = tess_downsize(MultipleFiles{i}, newNbFibers, Method);
    end
    return;
end
    
%% ===== LOAD FILE =====
% Progress bar
bst_progress('start', 'Resample fibers', 'Loading file...');
% Load file
FibMat = in_fibers_bst(FibFile);
NewFibMat = db_template('fibers');


%% ===== RESAMPLE =====
bst_progress('start', 'Resample fibers', ['Resampling fibers: ' FibMat.Comment '...']);
% Resampling methods
switch (Method)
    % ===== RANDOM =====
    % Select random fibers
    case 'random'
        I = randsample(oldNbFibers, newNbFibers);
        % Re-order the fibers so that they are in the same order in the output file
        I = sort(I);
        NewFibMat.Points = FibMat.Points(I,:,:);
        MethodTag = '';
        J = 1:newNbFibers;
end


%% ===== CREATE NEW FIBER STRUCTURE =====
% Build new filename and Comment
[filepath, filebase, fileext] = bst_fileparts(file_fullpath(FibFile));
NewComment = FibMat.Comment;
% Remove previous '_nbfibFib' tags from Comment field
if length(NewComment) > 3 && all(NewComment(end-2:end) == 'Fib')
    iUnderscore = strfind(NewComment, '_');
    if isempty(iUnderscore)
        iUnderscore = strfind(NewComment, ' ');
    end
    if ~isempty(~iUnderscore)
        NewComment = NewComment(1:iUnderscore(end)-1);
    end
end
% Remove previous '_nbfibFib' tags from filename
if length(filebase) > 3 && all(filebase(end-2:end) == 'Fib')
    iUnderscore = strfind(filebase, '_');
    filebase = filebase(1:iUnderscore(end)-1);
end
% Add a '_nbvertV' tag
NewFibFile = file_unique(bst_fullfile(filepath, sprintf('%s_%dFib%s', filebase, newNbFibers, fileext)));
NewComment  = sprintf('%s%s_%dFib', NewComment, MethodTag, newNbFibers);
NewFibMat.Comment  = NewComment;
% Copy Header field
if isfield(FibMat, 'Header')
    NewFibMat.Header = FibMat.Header;
end
% Copy history field
if isfield(FibMat, 'History')
    NewFibMat.History = FibMat.History;
end
% History: Downsample surface
NewFibMat = bst_history('add', NewFibMat, 'downsample', sprintf('Downsample fibers: %d -> %d fibers', oldNbFibers, newNbFibers));


%% ===== UPDATE DATABASE =====
% Save downsized fiber file
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

