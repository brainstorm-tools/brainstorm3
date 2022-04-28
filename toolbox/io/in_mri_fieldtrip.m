function sMri = in_mri_fieldtrip(MriFile, FieldName)
% IN_MRI_FIELDTRIP: Load a FieldTrip MRI file.
%
% USAGE:  sMri = in_mri_fieldtrip(MriFile, FieldName='anatomy')
%         sMri = in_mri_fieldtrip(ftMri,   FieldName='anatomy')
%
% INPUT: 
%     - MriFile   : Full path to a fieldtrip MRI file
%     - ftMri     : FieldTrip MRI structure
%     - FieldName : Name of the field that contains the volume of interest
% OUTPUT:
%     - sMri    :  Brainstorm MRI structure
%
% SEE ALSO: in_mri

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
% Authors: Francois Tadel, 2016-2020

% Parse inputs
if (nargin < 2) || isempty(FieldName)
    FieldName = 'anatomy';
end
% Load file
if ischar(MriFile)
    try
        FtMat = load(MriFile);
    catch
        error(['Cannot load MRI file: "' MriFile '".' 10 10 lasterr]);
    end
else
    FtMat = MriFile;
end
% Check that the field exists
if ~isfield(FtMat, FieldName) || isempty(FtMat.(FieldName))
    error(['Field "' FieldName '" doesn''t exist or is empty.']);
end

% Convert to a Brainstorm structure
sMri.Cube    = double(FtMat.(FieldName));
sMri.Voxsize = sqrt(sum(FtMat.transform(1:3,1:3) .^2, 1));
if isfield(FtMat, 'unit') && isequal(FtMat.unit, 'm')
    sMri.Voxsize = sMri.Voxsize .* 1000;
end

% Transfer header
if isfield(FtMat, 'hdr')
    sMri.Header = FtMat.hdr;

    % Try to read the CTF fiducials
    if isfield(FtMat.hdr, 'HeadModel') ...
       && isfield(FtMat.hdr.HeadModel, 'Nasion_Sag') && isfield(FtMat.hdr.HeadModel, 'Nasion_Cor') && isfield(FtMat.hdr.HeadModel, 'Nasion_Axi') ...
       && isfield(FtMat.hdr.HeadModel, 'LeftEar_Sag') && isfield(FtMat.hdr.HeadModel, 'LeftEar_Cor') && isfield(FtMat.hdr.HeadModel, 'LeftEar_Axi') ...
       && isfield(FtMat.hdr.HeadModel, 'RightEar_Sag') && isfield(FtMat.hdr.HeadModel, 'RightEar_Cor') && isfield(FtMat.hdr.HeadModel, 'RightEar_Axi') ...
       && (length([FtMat.hdr.HeadModel.Nasion_Sag, FtMat.hdr.HeadModel.Nasion_Cor, FtMat.hdr.HeadModel.Nasion_Axi]) == 3) ...
       && (length([FtMat.hdr.HeadModel.LeftEar_Sag, FtMat.hdr.HeadModel.LeftEar_Cor, FtMat.hdr.HeadModel.LeftEar_Axi]) == 3) ...
       && (length([FtMat.hdr.HeadModel.RightEar_Sag, FtMat.hdr.HeadModel.RightEar_Cor, FtMat.hdr.HeadModel.RightEar_Axi]) == 3)
        sMri.SCS.NAS = ...
            [FtMat.hdr.HeadModel.Nasion_Sag,...
            FtMat.hdr.HeadModel.Nasion_Cor,...
            FtMat.hdr.HeadModel.Nasion_Axi]...
            .* sMri.Voxsize;
        sMri.SCS.LPA =...
            [FtMat.hdr.HeadModel.LeftEar_Sag,...
            FtMat.hdr.HeadModel.LeftEar_Cor,...
            FtMat.hdr.HeadModel.LeftEar_Axi]...
            .* sMri.Voxsize;
        sMri.SCS.RPA =...
            [FtMat.hdr.HeadModel.RightEar_Sag,...
            FtMat.hdr.HeadModel.RightEar_Cor,...
            FtMat.hdr.HeadModel.RightEar_Axi]...
            .* sMri.Voxsize;
    end
end

% Todo: Process units and coordinates systems properly


         
         


