function sSubject = db_surface_default( iSubject, SurfaceType, iSurface, isUpdate )
% DB_SURFACE_DEFAULT: Set a surface as default of its category for a given subject.
%
% USAGE:  db_surface_default( iSubject, SurfaceType, iSurface, isUpdate=1 );

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
% Authors: Francois Tadel, 2008-2011

% Get protocol description
ProtocolInfo = bst_get('ProtocolInfo');
sSubject = bst_get('Subject', iSubject);

% ===== GET DEFAULT SURFACE =====
% By default: update tree
if (nargin < 4) || isempty(isUpdate)
    isUpdate = 1;
end
% If default surface is not defined yet: find one
if (nargin < 3) || isempty(iSurface)
    iSurface = [];
    % Try to find the default surface in the brainstormsubject.mat file
    subjMat = load(bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.FileName));
    % Default surface name
    if isfield(subjMat, SurfaceType)
        defSurfFile = subjMat.(SurfaceType);
    else
        defSurfFile = [];
    end
        
    % == ANATOMY ==
    if strcmpi(SurfaceType, 'Anatomy')
        % Try to find the default surface file
        if ~isempty(defSurfFile)
            iSurface = find(file_compare({sSubject.Anatomy.FileName}, defSurfFile), 1);
        end
        % If default not found: Use the first one
        if isempty(iSurface) && ~isempty(sSubject.Anatomy)
            iSurface = 1;
        end
    % == SURFACE ==
    else
        % Try to find the default surface file
        if ~isempty(defSurfFile)
            iSurface = find(file_compare({sSubject.Surface.FileName}, defSurfFile), 1);
        end
        % If default not found: Use the first one
        if isempty(iSurface) && ~isempty(sSubject.Surface)
            iSurface = find(strcmpi({sSubject.Surface.SurfaceType}, SurfaceType), 1);
        end
    end
end

% Get new default surface
if ~isempty(iSurface)
    if strcmpi(SurfaceType, 'Anatomy')
        sSurface = sSubject.Anatomy(iSurface);
    else
        if (iSurface > length(sSubject.Surface))
            error(sprintf('Invalid surface index #%d. Subject has only %d registered surfaces.', iSurface, length(sSubject.Surface)));
        end
        sSurface = sSubject.Surface(iSurface);
    end
    DefaultFile = sSurface.FileName;
else
    DefaultFile = '';
end
% Make filename linux-style
DefaultFile = file_win2unix(DefaultFile);

% ===== UPDATE DATABASE =====
% Save in database selected file
sSubject.(['i' SurfaceType]) = iSurface;
bst_set('Subject', iSubject, sSubject);
% Update SubjectFile
matUpdate.(SurfaceType) = DefaultFile;
bst_save(bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.FileName), matUpdate, 'v7', 1);

% ===== UPDATE TREE =====
if isUpdate
    % Try to find the tree node associated to this surface
    if ~isempty(iSurface)
        surfNode = panel_protocols('SelectNode', [], lower(SurfaceType), iSubject, iSurface );
        % If node was found in this display
        if ~isempty(surfNode)
            % Select node (and unselect all the others)
            panel_protocols('MarkUniqueNode', surfNode);
        end
    else
        panel_protocols('UpdateNode', 'Subject', iSubject);
    end
end



