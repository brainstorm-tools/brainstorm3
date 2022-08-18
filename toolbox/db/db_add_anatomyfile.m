function iAnatomyFile = db_add_anatomyfile(iSubject, FileName, Comment, SurfaceType)
% DB_ADD_ANATOMYFILE: Add an AnatomyFile in database
%
% USAGE: iAnatomyFile = db_add_anatomyfile(iSubject, FileName, Comment, SurfaceType)
%
% INPUT:
%    - iSubject     : ID of the Subject where to add the surface
%    - FileName     : Relative path to the file in which the AnatomyFile is defined
%    - Comment      : Optional AnatomyFile description
%    - SurfaceType  : Optional string {'Cortex', 'Scalp', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM', 'Other'}
% OUTPUT:
%    - iAnatomyFile : ID of the AnatomyFile that was created

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
% Authors: Raymundo Cassani, 2022

% Get protocol information
ProtocolInfo = bst_get('ProtocolInfo');

% Anatomy or Surface
fileType = file_gettype(FileName);
switch fileType
    % Anatomy
    case 'subjectimage'
        anatFileType = 'anatomy';
    % Surfaces : cortex, scalp, outerskull, innerskull, fibers, fem
    otherwise
        anatFileType = 'surface';
end

% If comment is not defined : extract it from file
if (nargin < 3) || isempty(Comment)
    sMat = load(bst_fullfile(ProtocolInfo.SUBJECTS, FileName), 'Comment');
    Comment = sMat.Comment;
end

% If surface type is not defined : detect it
if (nargin < 4) || isempty(SurfaceType)
    % Get surface type from file
    switch fileType
        % Anatomy
        case 'subjectimage', SurfaceType = '';
        % Surface
        case 'cortex',       SurfaceType = 'Cortex';
        case 'scalp',        SurfaceType = 'Scalp';
        case 'outerskull',   SurfaceType = 'OuterSkull';
        case 'innerskull',   SurfaceType = 'InnerSkull';
        case 'fibers',       SurfaceType = 'Fibers';
        case 'fem',          SurfaceType = 'FEM';
        otherwise,           SurfaceType = 'Other';
    end
end

% Prepare AnatomyFile
sAnatFile = db_template('AnatomyFile');
sAnatFile.Subject = iSubject;
sAnatFile.Type = anatFileType;
sAnatFile.FileName = FileName;
sAnatFile.Name = Comment;
sAnatFile.SurfaceType = SurfaceType;

% Add AnatomyFile to database
iAnatomyFile = db_set('AnatomyFile', sAnatFile);


