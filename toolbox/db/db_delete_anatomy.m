function sSubject = db_delete_anatomy(iSubject, isKeepMri)
% DB_DELETE_ANATOMY: Remove all the MRI and surfaces from a subject.
%
% USAGE:  sSubject = db_delete_anatomy(iSubject, isKeepMri=0)

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
% Authors: Francois Tadel, 2017-2019

% Parse inputs
if (nargin < 2) || isempty(isKeepMri)
    isKeepMri = 0;
end

% Get subject
sSubject = bst_get('Subject', iSubject);

% Delete MRI
if ~isKeepMri && ~isempty(sSubject.Anatomy)
    file_delete(file_fullpath({sSubject.Anatomy.FileName}), 1);
    sSubject.Anatomy(1:end) = [];
    sSubject.iAnatomy = [];
elseif isKeepMri && (length(sSubject.Anatomy) >= 2)
    file_delete(file_fullpath({sSubject.Anatomy(2:end).FileName}), 1);
    sSubject.Anatomy(2:end) = [];
    sSubject.iAnatomy = 1;
end

% Delete surfaces
if ~isempty(sSubject.Surface)
    file_delete(file_fullpath({sSubject.Surface.FileName}), 1);
    sSubject.Surface(1:end) = [];
end
% Empty defaults lists
sSubject.iCortex = [];
sSubject.iScalp = [];
sSubject.iInnerSkull = [];
sSubject.iOuterSkull = [];
sSubject.iFibers = [];
sSubject.iFEM = [];

% Update subject structure
bst_set('Subject', iSubject, sSubject);
panel_protocols('UpdateNode', 'Subject', iSubject);
% Save database
db_save();

