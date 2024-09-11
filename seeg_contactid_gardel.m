function errorMsg = seeg_contactid_gardel(iSubject, BsDir, nVertices, isInteractive, sFid, isVolumeAtlas, isKeepMri)
% SEEG_CONTACTID_GARDEL: Handle GARDEL data manipulation.
%
% USAGE:  errorMsg = export_import_gardel(iSubject, BsDir=[ask], nVertices=[ask], isInteractive=1, sFid=[], isVolumeAtlas=1, isKeepMri=0)
%
% INPUT:
%    - iSubject      : Indice of the subject where to import the MRI
%                      If iSubject=0 : import MRI in default subject
%    - BsDir         : Full filename of the BrainSuite folder to import
%    - nVertices     : Number of vertices in the file cortex surface
%    - isInteractive : If 0, no input or user interaction
%    - sFid          : Structure with the fiducials coordinates
%                      Or full MRI structure with fiducials defined in the SCS structure, to be registered with the FS MRI
%    - isVolumeAtlas : If 1, imports the svreg atlas as a set of surfaces
%    - isKeepMri     : 0=Delete all existing anatomy files
%                      1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                      2=Keep existing MRI and surfaces
% OUTPUT:
%    - errorMsg : String: error message if an error occurs

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Author: Chinmay Chinara, 2024

%% ===== PARSE INPUTS =====
% Keep MRI
if (nargin < 7) || isempty(isKeepMri)
    isKeepMri = 0;
end
% Import volume atlas
if (nargin < 6) || isempty(isVolumeAtlas)
    isVolumeAtlas = 1;
end
% Fiducials
if (nargin < 5) || isempty(sFid)
    sFid = [];
end
% Interactive / silent
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 1;
end
% Ask number of vertices for the cortex surface
if (nargin < 3) || isempty(nVertices)
    nVertices = [];
end
% Initialize returned variables
errorMsg = [];

%% CHECK IF GARDEL PLUGIN IS INSTALLED
% If GARDEL not installed install it else continue
[isInstalled, errMsg] = bst_plugin('Install', 'gardel');
if ~isInstalled
    return;
end

%% START EXTERNAL GARDEL TOOL
% Set process logo
bst_progress('start', 'GARDEL', 'Starting GARDEL external tool');
bst_plugin('SetProgressLogo', 'gardel');

% create temporary folder for GARDEL
TmpGardelDir = bst_get('BrainstormTmpDir', 0, 'gardel');

% Get current subject
sSubject = bst_get('Subject', iSubject);

% Save reference MRI in .nii format in tmp folder
MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMriRef = in_mri_bst(MriFileRef);
NiiRefMriFile = bst_fullfile(TmpGardelDir, [sMriRef.Comment '.nii']);
% NiiRefMriFile is the MRI file of the subject
out_mri_nii(sMriRef, NiiRefMriFile);

% Save the unprocessed CT in .nii format in tmp folder 
iRawCt = find(cellfun(@(x) ~isempty(regexp(x, '_volct_raw', 'match')), {sSubject.Anatomy.FileName}));
if ~isempty(iRawCt)
    RawCtFileRef = sSubject.Anatomy(iRawCt(1)).FileName;
    sMriRawCt = in_mri_bst(RawCtFileRef);
    NiiRawCtFile = bst_fullfile(TmpGardelDir, [sMriRawCt.Comment '.nii']);
    % NiiRawCtFile is the unprocessed CT file of the subject
    out_mri_nii(sMriRawCt, NiiRawCtFile);
else
    bst_error('No Raw unprocessed CT found', 'GARDEL', 0);
    return;
end

% Hide Brainstorm window
jBstFrame = bst_get('BstFrame');
jBstFrame.setVisible(0);

% call the external GARDEL tool
bst_call(@GARDEL);

% Set process logo
bst_progress('stop');
