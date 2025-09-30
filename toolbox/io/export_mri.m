function export_mri( BstMriFile, OutputMriFile , ExportFiducials)
% EXPORT_MRI: Export a MRI to one of the supported file formats.
%
% USAGE:  export_mri( BstMriFile, OutputMriFile=[ask], ExportFiducials = [ask] )
%         export_mri( sMri,       OutputMriFile=[ask], ExportFiducials = [ask] )
% INPUT: 
%     - BstMriFile      : Full path to input Brainstorm MRI file to be exported
%     - sMri            : Brainstorm MRI structure
%     - OutputMriFile   : Full path to target file (extension will determine the format)
%     - ExportFiducials : Export fiducials as json. Valid option = {bids}

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
% Authors: Francois Tadel, 2008-2016

% ===== PARSE INPUTS =====
if (nargin < 1) || isempty(BstMriFile)
    error('Brainstorm:InvalidCall', 'Invalid use of export_mri()');
end
if (nargin < 2)
    OutputMriFile = [];
end
if (nargin < 3)
    ExportFiducials = '';
end

% ===== LOAD MRI FILE =====
% Show progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Export MRI', 'Loading input file');
end
% Load MRI
if ischar(BstMriFile)
    sMri = in_mri_bst(BstMriFile);
else
    sMri = BstMriFile;
    BstMriFile = [];
end
if ~isProgress
    bst_progress('stop'); 
end

% ===== SELECT OUTPUT FILE =====
if isempty(OutputMriFile)
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Export extension
    if isempty(DefaultFormats.MriOut)
        DefaultFormats.MriOut = 'Analyze';
    end
    switch DefaultFormats.MriOut
        case 'GIS',     ExportExt = '.ima';
        case 'Analyze', ExportExt = '.img';
        case 'CTF',     ExportExt = '.mri';
        case 'Nifti1',  ExportExt = '.nii';
        case 'JNIfTI',  ExportExt = '.jnii';
        case 'FT-MRI',  ExportExt = '.mat';
        otherwise,      ExportExt = '.nii';
    end
    % Build default output filename
    if ~isempty(BstMriFile)
        [BstPath, BstBase, BstExt] = bst_fileparts(BstMriFile);
    else
        BstBase = 'export';
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportAnat, [BstBase, ExportExt]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_subjectimage', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'subjectimage_', '');
    % Put MRI file
    [OutputMriFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export MRI...', ...             % Window title
        DefaultOutputFile, ...       % Default directory
        'single', 'files', ...           % Selection mode
        bst_get('FileFilters', 'mriout'), ...
        DefaultFormats.MriOut);
    % If no file was selected: exit
    if isempty(OutputMriFile)
        return
    end
    % Save new default export path
    LastUsedDirs.ExportAnat = bst_fileparts(OutputMriFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.MriOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    % Export fiducials
    res = java_dialog('question', 'Do you want to also export the fiducials contained in the MRI?' ,...
                              'Export fiducials', [], {'Yes', 'No'},'Yes');
    if strcmpi(res, 'yes')
        ExportFiducials = 'bids';
    end
end

% ===== SAVE MRI =====
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputMriFile);
% Install/load required plugins
LoadedPlugins = bst_plugin('GetLoaded');
RequiredPlugins = {};
switch lower(OutputExt)
    case {'.jnii', '.bnii'}
        % JNIfTI Toolbox
        RequiredPlugins = {'jnifti'};
end
for iPlugin = 1 : length(RequiredPlugins)
    [isInstalled, errMsg] = bst_plugin('Install', RequiredPlugins{iPlugin});
    if ~isInstalled
        error(errMsg);
    end
end
% Show progress bar
if ~isProgress
    bst_progress('start', 'Export MRI', ['Export MRI to file "' [OutputBase, OutputExt] '"...']);
end
% Switch between file formats
switch lower(OutputExt)
    case '.ima'
        out_mri_gis(sMri, OutputMriFile);
    case {'.img', '.nii'}
        out_mri_nii(sMri, OutputMriFile);
    case {'.jnii', '.bnii'}
        % Create temporal NIfTI file
        TmpDir = bst_get('BrainstormTmpDir', 0, 'out_jnifti');
        % Save  MRI nii format
        TmpNiiFile = bst_fullfile(TmpDir, 'tmp.nii');
        out_mri_nii(sMri, TmpNiiFile);
        nii2jnii(TmpNiiFile, OutputMriFile);
        % Delete the temporary files
        file_delete(TmpDir, 1, 1);
    case '.mri'
        out_mri_ctf(sMri, OutputMriFile);
    case '.mat'
        ftMri = out_fieldtrip_mri(sMri);
        bst_save(OutputMriFile, ftMri, 'v7');
    otherwise
        error(['Unsupported file extension : "' OutputExt '"']);
end
% Export fiducials
if strcmpi(ExportFiducials, 'bids')
    OutputJsonFile = bst_fullfile(OutputPath, [OutputBase, '.json']);
    export_fiducials_bids(sMri, OutputJsonFile);
end

% Unload required plugins that were loaded
if ~isempty(RequiredPlugins)
    tmpLoadedPlugins = bst_plugin('GetLoaded');
    ToUnloadPluginNames = setdiff({tmpLoadedPlugins.Name}, {LoadedPlugins.Name});
    for ix = 1 : length(ToUnloadPluginNames)
        bst_plugin('Unload', ToUnloadPluginNames{ix});
    end
end
% Hide progress bar
if ~isProgress
    bst_progress('stop');
end

end

function export_fiducials_bids(sMri, OutputJsonFile)
% Export_mri_fiducials: Export a MRI fiducials to a json file.
% Coordinates are exported in RAS voxel, using a 0-based indexing
    output = struct();
    output.CoordinateUnits = 'voxel';
    % Fiduciala (mm): Subject coordinate system
    SCS_fieldsname = {'NAS', 'RPA', 'LPA'};
    for iFields = 1:length(SCS_fieldsname)
        if isfield(sMri.SCS, SCS_fieldsname{iFields}) && ~isempty(sMri.SCS.(SCS_fieldsname{iFields}))
            output.AnatomicalLandmarkCoordinates.(SCS_fieldsname{iFields}) = sMri.SCS.(SCS_fieldsname{iFields});
        else
            warning('Fiducial "%s" not found in MRI', SCS_fieldsname{iFields});
        end
    end
    % Fiducials (mm): MNI cooordinate system
    NCS_fieldsname = {'AC', 'PC', 'IH'};
    for iFields = 1:length(NCS_fieldsname)
        if isfield(sMri.NCS, NCS_fieldsname{iFields}) && ~isempty(sMri.NCS.(NCS_fieldsname{iFields}))
            output.AnatomicalLandmarkCoordinates.(NCS_fieldsname{iFields}) = sMri.NCS.(NCS_fieldsname{iFields});
        else
            warning('Fiducial "%s" not found in MRI', NCS_fieldsname{iFields});
        end
    end
    % Convert from Brainstorm 1-based voxels to 0-based voxels for BIDS
    fieldsName = fieldnames(output.AnatomicalLandmarkCoordinates);
    for iField = 1:length(fieldsName)
        coord = output.AnatomicalLandmarkCoordinates.(fieldsName{iField});
        output.AnatomicalLandmarkCoordinates.(fieldsName{iField}) = round(1000 .* ((coord ./ sMri.Voxsize) - 1)) ./ 1000;
    end
    % Save file
    fid = fopen(OutputJsonFile, 'w');
    if fid < 0
        error('Unable to write to %s', OutputJsonFile )
    end
    fprintf(fid, bst_jsonencode(output));
    fclose(fid);
end




