function NewFemFile = fem_resect(FemFile, MNIplane)
% FEM_RESECT: Cut below a given plane in MNI-coordinates
%
% USAGE: NewFemFile = fem_resect(FemFile, MNIplane=[ask])

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
% Authors: Francois Tadel, 2020

% ===== GET MNI PLANE =====
% If not defined: ask user
if (nargin < 2) || isempty(MNIplane) || (length(MNIplane) ~= 4)
    res = java_dialog('input', ['<HTML>Cut below a plane in MNI coordinates:<BR>(a.x + b.y + c.z + d = 0)<BR><BR>' ...
        '<FONT color="#777777">Examples:<BR>Cut face: a=0, b=-11, c=9.6, d=1<BR>Cut neck: a=0, b=0, c=1, d=0.085 (Z&lt;-85)</FONT><BR><BR>' ...
        '[a,b,c,d]='], 'MNI resection plane', [], sprintf('[%1.3f, %1.3f, %1.3f, %1.3f]', [0 0 1 .085]));
    % If user cancelled or invalid value: return
    if isempty(res) || (length(str2num(res)) ~= 4)
        bst_progress('stop');
        return;
    end
    % Get new values
    MNIplane = str2num(res);
end

% ===== GET MRI =====
% Get subject 
[sSubject, iSubject] = bst_get('SurfaceFile', FemFile);
if isempty(iSubject)
    error('Could not find file.');
end
% Check if a MRI is available for the subject
if isempty(sSubject.Anatomy)
    error(['No MRI available for subject "' sSubject.Name '".']);
end
% Open progress bar
bst_progress('start', 'Resect FEM mesh', ['Loading file "' FemFile '"...']);
% Load MRI
sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
% If the linear MNI normalization is not available: compute it now
if (~isfield(sMri, 'NCS') || isempty(sMri.NCS) || ~isfield(sMri.NCS, 'R') || ~isfield(sMri.NCS, 'T') || isempty(sMri.NCS.R) || isempty(sMri.NCS.T))
    [sMri, errMsg] = bst_normalize_mni(sMri, 'maff8');
    if ~isempty(errMsg)
        error(errMsg);
    end
end
    
% ===== CUT FEM MESH =====
% Load file
FemFile = file_fullpath(FemFile);
FemMat = load(FemFile);

bst_progress('text', 'Removing elements...');
% Get linear MNI transformation
vox2mni = cs_convert(sMri, 'scs', 'mni');
% Get cut plane in MRI coordinates
cutPlane = MNIplane * vox2mni;
% Compute centroids of all elements
nElem = size(FemMat.Elements, 1);
nMesh = size(FemMat.Elements, 2);
ElemCenter = zeros(nElem, 3);
for i = 1:3
    ElemCenter(:,i) = sum(reshape(FemMat.Vertices(FemMat.Elements,i), nElem, nMesh)')' / nMesh;
end
% Get elements under the MNI plane defined in input
iElemCut = find(cutPlane(1)*ElemCenter(:,1) + cutPlane(2)*ElemCenter(:,2) + cutPlane(3)*ElemCenter(:,3) + cutPlane(4) < 0);
% Checking for errors
strPlane = sprintf('%1.3fx + %1.3fy + %1.3fz + %1.3f = 0', MNIplane);
if isempty(iElemCut)
    error(['No elements are located below the plane: ', strPlane]);
elseif (length(iElemCut) == nElem)
    error(['All the elements are located below the plane: ', strPlane]);
end

% Remove elements
FemMat = fem_remove_elem(FemMat, iElemCut);


% ===== SAVE NEW FILE =====
bst_progress('text', 'Saving new file...');
% Update output structure
FemMat.Comment = [FemMat.Comment, ' | resect'];
FemMat = bst_history('add', FemMat, 'resect', ['Cut below MNI plane: ' strPlane]);
% Output filename
[fPath, fBase, fExt] = bst_fileparts(FemFile);
NewFemFile = file_unique(bst_fullfile(fPath, [fBase, '_resect', fExt]));
% Save new surface in Brainstorm format 
bst_save(NewFemFile, FemMat, 'v7');
db_add_surface(iSubject, NewFemFile, FemMat.Comment);

% Close progress bar
bst_progress('stop');


