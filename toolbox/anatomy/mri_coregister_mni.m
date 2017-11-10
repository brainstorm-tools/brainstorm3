function [sMriReg, errMsg, fileTag] = mri_coregister_mni(MriFileSrc, MriFileRef, isReslice)
% MRI_COREGISTER_MNI: Compute the MNI transformation on both input volumes, then register the first on the second.
%
% USAGE:  [MriFileReg, errMsg, fileTag] = mri_coregister_mni(MriFileSrc, MriFileRef, isReslice)
%            [sMriReg, errMsg, fileTag] = mri_coregister_mni(sMriSrc,    sMriRef, ...)
%
% INPUTS:
%    - MriFileSrc : Relative path to the Brainstorm MRI file to register
%    - MriFileRef : Relative path to the Brainstorm MRI file used as a reference
%    - sMriSrc    : Brainstorm MRI structure to register (fields Cube, Voxsize, SCS, NCS...)
%    - sMriRef    : Brainstorm MRI structure used as a reference
%    - isReslice  : If 1, reslice the output volume to match dimensions of the reference volume
%
% OUTPUTS:
%    - MriFileReg : Relative path to the new Brainstorm MRI file (containing the structure sMriReg)
%    - sMriReg    : Brainstorm MRI structure with the registered volume
%    - errMsg     : Error messages if any
%    - fileTag    : Tag added to the comment/filename

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016-2017

% ===== PARSE INPUTS =====
sMriReg = [];
errMsg = [];
% Reslice
if (nargin < 3) || isempty(isReslice)
    isReslice = 1;
end


% ===== LOAD INPUTS =====
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MRI register', 'Loading input volumes...');
end
% USAGE: mri_coregister_mni(sMriSrc, sMriRef)
if isstruct(MriFileSrc)
    sMriSrc = MriFileSrc;
    sMriRef = MriFileRef;
    MriFileSrc = [];
    MriFileRef = [];
% USAGE: mri_coregister_mni(MriFileSrc, MriFileRef)
elseif ischar(MriFileSrc)
    % Get the default MRI for this subject
    if isempty(MriFileRef)
        sSubject = bst_get('MriFile', MriFileSrc);
        MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    sMriSrc = in_mri_bst(MriFileSrc);
    sMriRef = in_mri_bst(MriFileRef);
else
    error('Invalid call.');
end


% ===== COMPUTE MNI TRANSFORMATIONS =====
% Source MRI
if ~isfield(sMriSrc, 'NCS') || ~isfield(sMriSrc.NCS, 'R') || ~isfield(sMriSrc.NCS, 'T') || isempty(sMriSrc.NCS.R) || isempty(sMriSrc.NCS.T)
    [sMriSrc,errMsg] = bst_normalize_mni(sMriSrc);
end
% Reference MRI
if ~isfield(sMriRef, 'NCS') || ~isfield(sMriRef.NCS, 'R') || ~isfield(sMriRef.NCS, 'T') || isempty(sMriRef.NCS.R) || isempty(sMriRef.NCS.T)
    [sMriRef,errMsg] = bst_normalize_mni(sMriRef);
end
% Handle errors
if ~isempty(errMsg)
    if ~isempty(MriFileSrc)
        bst_error(errMsg, 'MRI reslice', 0);
    end
    return;
end
% Get MNI transformations
TransfSrc = [sMriSrc.NCS.R, sMriSrc.NCS.T; 0 0 0 1];
TransfRef = [sMriRef.NCS.R, sMriRef.NCS.T; 0 0 0 1];


% ===== RESLICE VOLUME =====
if isReslice
    [sMriReg, errMsg] = mri_reslice(sMriSrc, sMriRef, TransfSrc, TransfRef);
    
% ===== NO RESLICE: USE ORIGINAL VOLUME =====
else
    % Save the original input volume
    sMriReg = sMriSrc;
    % Use the reference SCS coordinates if possible
    if isfield(sMriRef, 'SCS') && all(isfield(sMriRef.SCS, {'NAS','LPA','RPA','T','R'})) && ~isempty(sMriRef.SCS.NAS) && ~isempty(sMriRef.SCS.LPA) && ~isempty(sMriRef.SCS.RPA) && ~isempty(sMriRef.SCS.R) && ~isempty(sMriRef.SCS.T)
        % Apply transformation: reference MRI => SPM/MNI => original MRI
        Transf = inv(TransfSrc) * TransfRef;
        % Update SCS fiducials
        sMriReg.SCS.NAS = (Transf(1:3,1:3) * sMriRef.SCS.NAS' + Transf(1:3,4))';
        sMriReg.SCS.LPA = (Transf(1:3,1:3) * sMriRef.SCS.LPA' + Transf(1:3,4))';
        sMriReg.SCS.RPA = (Transf(1:3,1:3) * sMriRef.SCS.RPA' + Transf(1:3,4))';
        % Compute new transformation matrices to SCS
        Tscs = [sMriRef.SCS.R, sMriRef.SCS.T; 0 0 0 1] * inv(Transf);
        % Report in the new MRI structure
        sMriReg.SCS.R = Tscs(1:3,1:3);
        sMriReg.SCS.T = Tscs(1:3,4);
%         NewTransf = cs_compute(sMriReg, 'scs');
%         % Report in the new MRI structure
%         sMriReg.SCS.R = NewTransf.R;
%         sMriReg.SCS.T = NewTransf.T;
%         sMriReg.SCS.Origin = NewTransf.Origin;
    end
end
% Handle errors
if ~isempty(errMsg)
    if ~isempty(MriFileSrc)
        bst_error(errMsg, 'MRI reslice', 0);
    end
    return;
end


% ===== SAVE NEW FILE =====
% Add file tag
fileTag = '_mni';
if isReslice
    fileTag = [fileTag, '_reslice'];
end
sMriReg.Comment = [sMriSrc.Comment, fileTag];
% Save output
if ~isempty(MriFileSrc)
    bst_progress('text', 'Saving new file...');
    % Get subject
    [sSubject, iSubject, iMri] = bst_get('MriFile', MriFileSrc);
    % Update comment
    sMriReg.Comment = file_unique(sMriReg.Comment, {sSubject.Anatomy.Comment});
    % Add history entry
    sMriReg = bst_history('add', sMriReg, 'resample', ['MRI co-registered on default file: ' MriFileRef]);
    % Save new file
    newMriFile = file_unique(strrep(file_fullpath(MriFileSrc), '.mat', [fileTag '.mat']));
    shorMriFile = file_short(newMriFile);
    % Save new MRI in Brainstorm format
    sMriReg = out_mri_bst(sMriReg, newMriFile);

    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = shorMriFile;
    sSubject.Anatomy(iAnatomy).Comment  = sMriReg.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
    % Return output filename
    sMriReg = shorMriFile;
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

