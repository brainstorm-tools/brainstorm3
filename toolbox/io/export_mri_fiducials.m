function OutputMriFile = export_mri_fiducials(BstMriFile, OutputMriFile)
% export_mri_fiducials: Export a MRI fiducials to a json file.
% Coordinate are exported in voxel, using a 0-based indexing
%
% USAGE:  export_mri( BstMriFile, OutputMriFile=[ask])
%         export_mri( sMri,       OutputMriFile=[ask])
% INPUT: 
%     - BstMriFile    : Full path to input Brainstorm MRI file to be exported
%     - sMri          : Brainstorm MRI structure
%     - OutputFile : Full path to target file  

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
% Authors: Edouard Delaire, 2025

    % ===== PARSE INPUTS =====
    if (nargin < 1) || isempty(BstMriFile)
        error('Brainstorm:InvalidCall', 'Invalid use of export_mri_fiducials()');
    end

    if (nargin < 2)
        OutputMriFile = [];
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
    end

    if ~isProgress
        bst_progress('stop'); 
    end

    output = struct();
    output.CoordinateUnits = 'voxel';

    SCS_fieldsname = {'NAS', 'RPA', 'LPA'};
    for iFields = 1:length(SCS_fieldsname)
        if isfield(sMri.SCS, SCS_fieldsname{iFields}) && ~isempty(sMri.SCS.(SCS_fieldsname{iFields}))
            output.FiducialsCoordinates.(SCS_fieldsname{iFields}) = sMri.SCS.(SCS_fieldsname{iFields});
        else
            warning('%s not found',SCS_fieldsname{iFields} )
        end
    end

    NCS_fieldsname = {'AC', 'PC', 'IH'};
    for iFields = 1:length(NCS_fieldsname)
        if isfield(sMri.NCS, NCS_fieldsname{iFields}) && ~isempty(sMri.NCS.(NCS_fieldsname{iFields}))
            output.FiducialsCoordinates.(NCS_fieldsname{iFields}) = sMri.NCS.(NCS_fieldsname{iFields});
        else
            warning('%s not found',NCS_fieldsname{iFields} )
        end
    end
    
    % Convert from 1- based to 0-based for BIDS
    fieldsName = fieldnames(output.FiducialsCoordinates);
    for iField = 1:length(fieldsName)
        coord = output.FiducialsCoordinates.(fieldsName{iField});
        output.FiducialsCoordinates.(fieldsName{iField}) = coord - 1;
    end

    fid = fopen(OutputMriFile, 'w');
    fprintf(fid, jsonencode(output,"PrettyPrint", true));
    fclose(fid);

end