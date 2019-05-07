function newFileName = db_surface_type(SurfaceFile, targetType)
% TREE_SURFACE_TYPE: Set surface type for a surface file (cortex, scalp, innerskull, outerskull, or other)
%
% USAGE:  newFileName = db_surface_type(SurfaceFile, targetType) 

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
% Authors: Francois Tadel, 2009-2012

newFileName = '';
% Get full filename
SurfaceFileFull = file_fullpath(SurfaceFile);
% Find surface in database
[sSubject, iSubject, iSurf] = bst_get('SurfaceFile', SurfaceFile);
initType = sSubject.Surface(iSurf).SurfaceType;
% Check if surface type changed
if strcmpi(initType, targetType)
    newFileName = SurfaceFile;
    return;
end

% Define the tag to tag to add at the end of the file
switch targetType
    case {'Scalp', 'Head'}
        targetTag = 'tess_scalp';
    case 'Cortex'
        targetTag = 'tess_cortex';
    case 'OuterSkull'
        targetTag = 'tess_outerskull';
    case 'InnerSkull'
        targetTag = 'tess_innerskull';
    case 'Fibers'
        targetTag = 'tess_fibers';
    case 'Other'
        targetTag = 'tess';
end

% Update file name (add the right tag at the end of the filename)
[isOk, newSurfaceFileFull] = file_update(SurfaceFileFull, 'FileType', targetTag);
if ~isOk
    return
end
newFileName = file_short(newSurfaceFileFull);
% History: Change surface type
bst_history('add', newSurfaceFileFull, 'set_type', ['Set surface type: ' targetType]);

% === Update surface type and filename ===
sSubject.Surface(iSurf).SurfaceType = targetType;
sSubject.Surface(iSurf).FileName    = newFileName;
% If the modified surface was selected : unselect it
sSubject.iScalp      = setdiff(sSubject.iScalp,      iSurf);
sSubject.iCortex     = setdiff(sSubject.iCortex,     iSurf);
sSubject.iOuterSkull = setdiff(sSubject.iOuterSkull, iSurf);
sSubject.iInnerSkull = setdiff(sSubject.iInnerSkull, iSurf);
sSubject.iFibers     = setdiff(sSubject.iFibers,     iSurf);
sSubject.iOther      = setdiff(sSubject.iOther,      iSurf);
% Update subject in database
bst_set('Subject', iSubject, sSubject);

% Set the modified surface as default
if ~strcmpi(targetType, 'Other')   
    db_surface_default(iSubject, targetType, iSurf);
end
% Update the default surface for the source type
if ~strcmpi(initType, 'Other')  
    db_surface_default(iSubject, initType);
end
% Save database
db_save(); 






