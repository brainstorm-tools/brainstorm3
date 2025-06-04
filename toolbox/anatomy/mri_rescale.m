function [atlasLabels, MriFileRescale, errMsg, fileTag] = mri_rescale(MriFile, AtlasFile, roiName)
% MRI_RESCALE: Rescale an MRI volume by the mean value of a specified ROI in an atlas.
%
% USAGE:
%   [atlasLabels, MriFileRescale, errMsg, fileTag] = mri_rescale(MriFile, 'ASEG', 'Cerebellum')
%   [atlasLabels, sMriRescale, errMsg, fileTag] = mri_rescale(sMri, 'ASEG', 'Cerebellum', sSubject)
%
% INPUTS:
%   - MriFile   : MRI file to be rescaled (string or struct)
%   - AtlasFile : Atlas file or Atlas structure
%   - roiName   : Name of the ROI to use for rescaling (string)
%
% OUTPUTS:
%   - atlasLabels    : Cell array of region names in the atlas
%   - MriFileRescale : Path to the rescaled MRI file (string) or structure if input is struct
%   - errMsg         : Error message, if any
%   - fileTag        : File tag used for output file

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
% Authors: Diellor Basha, 2025

atlasLabels = {};
MriFileRescale = [];
fileTag = '';

try
    % Progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Rescaling', 'Loading input volumes...');
    end

    if isstruct(MriFile)
        sMri = MriFile;
        mriFilePath = '';
    elseif ischar(MriFile)
        sMri = in_mri_bst(MriFile);
        mriFilePath = MriFile;
    else
        bst_progress('stop');
        error('Invalid call.');
    end
    % Load Atlas
    if isstruct(AtlasFile)
        sAtlas = AtlasFile;
    elseif ischar(AtlasFile)
        sAtlas = in_mri_bst(AtlasFile);
    else
        bst_progress('stop');
        error('Invalid call.');
    end

    bst_progress('stop');
    % Mask region
    [atlasLabels, ~, errMsg, maskFileTag, binMask] = mri_mask(sMri, sAtlas, roiName, 1);
  
    if ~isempty(errMsg)
        return;
    end

    if isempty(sMri) || ~isfield(sMri, 'Cube')
        errMsg = 'Could not load MRI volume.';
        return;
    end

    % Compute mean value in the ROI
    roiVals = double(sMri.Cube(binMask));
    if isempty(roiVals) || all(roiVals == 0)
        errMsg = sprintf('No nonzero voxels found in ROI "%s".', roiName);
        return;
    end
    roiMean = mean(roiVals);

    % Rescale MRI volume
    sMriRescale = sMri;
    sMriRescale.Cube = double(sMri.Cube) ./ roiMean;

    % Carry over fileTag and append rescale tag before last underscore
    rescaleTag = sprintf('_rescaled_%s_%s', lower(sAtlas.Comment), lower(roiName));
    fileTag = [maskFileTag, rescaleTag];

    % Carry over history from mri_mask if present
    if isfield(sMri, 'History')
        sMriRescale.History = sMri.History;
    end

    % Update comment
    sMriRescale.Comment = [sMri.Comment, rescaleTag];

    % ===== SAVE NEW FILE =====
    if ~isempty(mriFilePath) && ischar(mriFilePath)
        bst_progress('text', 'Saving new file...');
        [sSubject, iSubject] = bst_get('MriFile', mriFilePath);
        if isempty(sSubject) || ~isfield(sSubject, 'Anatomy')
            errMsg = 'Could not find subject for the provided MRI file.';
            return;
        end
        % Insert rescaleTag before the last underscore-tag
        [folder, base, ext] = fileparts(file_fullpath(mriFilePath));
        lastUnderscore = find(base == '_', 1, 'last');
        if ~isempty(lastUnderscore)
            newBase = [base(1:lastUnderscore-1), rescaleTag, base(lastUnderscore:end)];
        else
            newBase = [base, rescaleTag];
        end
        MriFileRescaleFull = file_unique(fullfile(folder, [newBase, ext]));
        MriFileRescale = file_short(MriFileRescaleFull);
        % Update comment to be unique
        sMriRescale.Comment = file_unique(sMriRescale.Comment, {sSubject.Anatomy.Comment});
        % Add history entry
        sMriRescale = bst_history('add', sMriRescale, 'rescale', ...
            sprintf('Rescaled with "%s" (%s)', sAtlas.Comment, roiName));
        % Save new MRI in Brainstorm format
        sMriRescale = out_mri_bst(sMriRescale, MriFileRescaleFull);
        % Register new MRI in subject
        iAnatomy = length(sSubject.Anatomy) + 1;
        sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
        sSubject.Anatomy(iAnatomy).FileName = MriFileRescale;
        sSubject.Anatomy(iAnatomy).Comment  = sMriRescale.Comment;
        % Update subject structure
        bst_set('Subject', iSubject, sSubject);
        % Refresh tree
        panel_protocols('UpdateNode', 'Subject', iSubject);
        panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
        % Save database
        db_save();
        bst_progress('stop');
        return;
    else
        % Return output structure if not saving to disk, and output fileTag
        MriFileRescale = sMriRescale;
        bst_progress('stop');
        return;
    end
catch ME
    errMsg = ME.message;
end